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

      if d = row[0]
        month, day, year = d.split('/')

        t = row[1]
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

      title = row[2].strip.titleize
      brand = Brand.where(title: title).first
      if brand.nil?
        brands = Brand.where("title ilike '%#{title}%'")
        if brands && brands.size == 1
          brand = brands.first
          puts "[#{title}] found brand: #{brand.id}"
        else
          puts "[#{title}] found #{brands.size} matching brands"
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
          byebug
          puts theShow.valid?
        end
      end
      name = title
      puts "#{d} #{t} #{name}"
      return theShow
    end
  end

  def send_to_all_users
    User.all.each do |user|
      send_message(user)
    end
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

    url = "http://www.vogue.co.uk/show/#{uid}"

    duplicate_sent_message = SentMessage.where(show_id: id, user_id: user.id).first
    duplicate_notification = Notification.where(show_id: id, user_id: user.id).first

    if duplicate_sent_message.present?
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
        user.deliver_message_for(title, url, image_url, "View the Show")
      rescue => e
        puts e
      end
    end
  end
end
