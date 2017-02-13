class Show < ApplicationRecord
  include Facebook::Messenger

  has_many :notifications
  belongs_to :brand
  belongs_to :location
  belongs_to :season
  validates :title, uniqueness: true
  validates :uid, uniqueness: true

  after_create :send_message

  scope :upcoming, -> { where("date_time > ?", Time.now) }
  scope :past, -> { where("date_time < ?", Time.now) }

  def upcoming?
    date_time > Time.now
  end

  def past?
    date_time < Time.now
  end

  def send_message
    msgText = self.title
    if date_time && date_time > Time.now
      msgText += " has a runway show at #{date_time} in #{location.title}"
    elsif date_time && date_time < Time.now
      msgText += " had a runway show at #{date_time} in #{location.title}"
    else
      msgText += " show is not scheduled yet in #{location.title}"
    end

    url = "http://www.vogue.co.uk/show/#{uid}"

    User.all.each do |user|
      duplicate_sent_message = SentMessage.where(show_id: id, user_id: user.id).first
      duplicate_notification = Notification.where(show_id: id, user_id: user.id).first

      if duplicate_sent_message.present?
        puts "Already sent this message (show: #{id}) to user #{user.id}!"
        duplicate_notification.update(sent: true, sent_at: duplicate_sent_message.sent_at) if duplicate_notification.present?
        next
      end

      if duplicate_notification.present?
        sent_status_message = duplicate_notification.sent? ? 'sent at ' + duplicate_notification.sent_at.to_formatted_s(:long_ordinal) : 'waiting to be sent'
        puts "Already have a notification for this show: #{id} to user #{user.id} (#{sent_status_message}) "
        next
      end

      last_sent_message = SentMessage.where(user_id: user.id).order("sent_at DESC").first

      ## Ensure we don't spam this user with too many messages in a row
      if last_sent_message && (Time.now - last_sent_message.sent_at <= 10)
        notification = Notification.create!(show: self, user: user, brand: brand, sent: false, sent_at: nil)
        puts "Created a notification to be sent in the next batch! ##{notification.id}"
        next

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
          user.deliver_message_for(title, url, "View the Show")
        rescue => e
          puts e
        end
      end
    end
  end
end
