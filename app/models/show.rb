class Show < ApplicationRecord
  include Facebook::Messenger

  has_many :notifications
  belongs_to :brand
  belongs_to :location
  belongs_to :season
  validates :title, uniqueness: true
  validates :uid, uniqueness: true

  URL_TRACKING_PARAMS = "?utm_campaign=trial&utm_medium=social&utm_source=facebookbot"

  after_create :notify_followers

  scope :upcoming, -> { where("date_time > ?", Time.now) }
  scope :past, -> { where("date_time IS NOT NULL").where("url IS NOT NULL").order("date_time DESC") }

  def self.default_scope
    where("uid NOT like 'XXX%'")
  end

  def upcoming?
    date_time > Time.now
  end

  def past?
    date_time < Time.now
  end

  def self.parse_grid(location_name, season_name, csvfile)
    location = Location.where(title: location_name).first_or_create
    season = Season.where(title: season_name).first_or_create

    CSV.foreach(Rails.root.join('data', csvfile)) do |row|
      next if row.first == "EXCLUDE" || row.first == "date"

      parsed_date = Show.format_date(row[0], row[1])
      title = row[2].strip.titleize.gsub(/'/, '')

      brand = Brand.where(title: title).first
      if brand.nil?
        brands = Brand.where("title ilike '%#{title}%'") rescue []
        if brands.any?
          brand = brands.first
          puts "[#{title}] found brand: #{brand.id}"
        else
          puts "[#{title}] failed finding a brand to match."
          next
        end
      end

      if theShow = Show.where(title: title, slug: title.parameterize, brand: brand, season: season, location: location).first
        puts "Already had show #{theShow.title}"
      else
        theShow = Show.create(title: title, slug: title.parameterize, uid: ["XXXXX", Time.now.to_i, rand(10000)].join, brand: brand, season: season, location: location, date_time: parsed_date)
        if theShow.valid?
          puts "Created show #{theShow.title}"
        else
          puts theShow.valid?
        end
      end
      puts theShow.id
    end
  end

  def followers
    recipients = []

    puts "#{id} #{title} created, notifying:"
    # 1. Anyone following show.brand
    followers = User.joins(:subscriptions).where(subscriptions: { brand_id: self.brand.id })
    if followers.any?
      puts "\t#{followers.size}: #{followers.map(&:id).sort.join(', ')}"
    end
    recipients += followers

    majors = []
    # 2. Anyone following major shows - if this is a major show
    if major?
      majors = if followers.any?
                 User.where(subscribe_major_shows: true).where("id NOT IN(?)", followers.map(&:id))
               else
                 User.where(subscribe_major_shows: true)
               end
      if majors.any?
        puts "\t#{majors.size} majors: #{majors.map(&:id).sort.join(', ')}"
        recipients += majors
      end
    end


    # 3. Anyone following all shows - and this doesn't satisfy either
    all_subs = User.where(subscribe_all_shows: true).where.not(subscribe_major_shows: true)
    the_rest = if followers.any?
                 all_subs.where("id NOT IN(?)", followers.map(&:id))
               else
                 all_subs
               end

    if the_rest.any?
      recipients += the_rest
    end
    puts "TOTAL: #{recipients.size} (#{recipients.uniq.size}) [#{recipients.flatten.uniq.size}]"
    return recipients
  end

  def notify_followers
    return if date_time.nil? || uid.nil? || url.nil?
    show_followers = followers
    if show_followers.any?
      show_followers.each do |f|
        if f.send_notification_for_show?(self)
          puts "++ SEND show##{id} to #{f.id}"
          # TODO: take this check out once verified
          SentMessage.create!(user_id: f.id, show_id: id, sent_at: Time.now, brand_id: brand.id, push_notification: true, text: "New Show: #{title} at #{date_time}")
          f.deliver_message_for([self])
          sleep(5)
        end
      end
    end
  end

  def image_url
    "https://vg-images.condecdn.net/image/#{image_uid}/crop/500/0.525"
  end

  def send_message(user)
    msgText = self.title
    if date_time && date_time > Time.now
      msgText += " has a runway show at #{date_time} in #{location.title}"
    elsif date_time && date_time < Time.now
      msgText += " had a runway show at #{date_time} in #{location.title}"
    else
      msgText += " show is not scheduled yet in #{location.title}"
    end

    duplicate_sent_message = SentMessage.where(show_id: id, user_id: user.id).first
    duplicate_notification = Notification.where(show_id: id, user_id: user.id).first

    if duplicate_sent_message.present? && (Time.now - duplicate_sent_message.sent_at < 30)
      puts "Already sent this message (show: #{id}) to user #{user.id}!"
      duplicate_notification.update(sent: true, sent_at: duplicate_sent_message.sent_at) if duplicate_notification.present?
      return
    end

    if duplicate_notification.present?
      sent_status_message = duplicate_notification.sent? ? 'sent at ' + duplicate_notification.sent_at.to_formatted_s(:long_ordinal) : 'waiting to be sent'
      puts "Already have a notification for this show: #{id} to user #{user.id} (#{sent_status_message}) "
      return
    end

    last_sent_message = SentMessage.where(user_id: user.id).order("sent_at DESC").first

    ## Ensure we don't spam this user with too many messages in a row
    if last_sent_message && !last_sent_message.sent_at.nil? && (Time.now - last_sent_message.sent_at <= 10)
      notification = Notification.create!(show: self, user: user, brand: brand, sent: false, sent_at: nil)
      puts "Created a notification to be sent in the next batch! ##{notification.id}"
      return

    else
      begin
        sm = SentMessage.create!(show: self, user: user, brand: brand, sent_at: Time.now)
        puts "Ok, sending message! #{sm.id}"
        if !sm.valid?
          puts sm.errors
        end
      rescue => e
        puts e
      end

      begin
        user.deliver_message_for([self])
      rescue => e
        puts e
      end
    end
  end

  def self.format_date(d, t)
    if d && t
      month, day, year = d.split('/')

      if t.match(" - ")
        t = t.split(" - ").first.strip
      elsif t.match(/TBD/i)
        t = "12:00"
      elsif t.match(/morning/i)
        t = "9:00"
      end
      hour, minute = t.split(":")

      day = "0#{day}" if day && day.size == 1
      month = "0#{month}" if month && month.size == 1
      datestr = [year, month, day].join('-') rescue ""
      datestr += " "
      datestr += [hour, minute].join(':')
      parsed_date = DateTime.parse(datestr) rescue "Invalid Date: #{datestr}"
    else
      parsed_date = nil #DateTime.parse(datestr) rescue "Invalid Date: #{datestr}"
    end
    parsed_date
  end

  def shorten_url
    return if url.blank? || url =~ /vogue.uk/
    post_api = "http://po.st/api/shorten?longUrl=" + CGI.escape(url + URL_TRACKING_PARAMS) + "&apiKey=D0755A3C-CCFF-44D9-A6B6-1F11E209A591"
    response = HTTP.get(post_api).parse
    if response && response['status_txt'] == 'OK' && response['short_url']
      puts response['short_url']
      update(url: response['short_url'])
    else
      puts "failed to shorten '#{url}': #{response}"
    end
  end

end
