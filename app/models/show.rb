class Show < ApplicationRecord
  include Facebook::Messenger

  has_many :notifications
  belongs_to :brand
  belongs_to :location
  belongs_to :season
  validates :title, uniqueness: true
  validates :uid, uniqueness: true

  after_create :send_to_all_users

  scope :upcoming, -> { where("date_time > ?", Time.now) }
  scope :past, -> { where("date_time < ?", Time.now) }

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

  def send_to_all_users
    return if date_time.nil? || upcoming?
    User.all.each do |user|
      send_message(user)
    end
  end

  def url
    "http://vogue.co.uk/shows/uid/#{uid}"
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
        user.deliver_message_for([self], "View the Show")
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
end
