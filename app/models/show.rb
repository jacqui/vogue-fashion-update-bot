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
      sm = SentMessage.where(show_id: id, user_id: user.id).first

      if sm
        puts "Already sent this message (show: #{id}) to user #{user.id}!"
        next
      end

      begin
        sm = SentMessage.create(show: self, user: user, brand: show.brand, sent_at: Time.now)
        if !sm.valid?
          puts sm.errors
        end
      rescue => e
        puts e
      end

      begin
        Bot.deliver({
          recipient: {
            id: user.fbid
          },
          message: {
            attachment: {
              type: 'template',
              payload: {
                template_type: 'generic',
                elements: [
                  {
                    title: title,
                    default_action: {
                      type: "web_url",
                      url: url
                    },
                    buttons:[
                      {
                        type: "web_url",
                        url: url,
                        title: "View the Show"
                      }
                    ]      
                  }
                ]
              }
            }
          }
        }, access_token: ENV['ACCESS_TOKEN'])
        user.last_message_sent_at = Time.now
        user.save!
      rescue => e
        puts e
      end
    end
  end
end
