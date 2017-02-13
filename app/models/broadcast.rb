class Broadcast < ApplicationRecord
  has_and_belongs_to_many :users

  after_create do |broadcast|
    User.all.each do |user|
      sent_at = Time.now
      begin
        Bot.deliver({
          recipient: {
            id: user.fbid
          },
          message: {
            text: broadcast.text
          }
        }, access_token: ENV['ACCESS_TOKEN'])
        user.broadcasts << broadcast
        user.last_message_sent_at = sent_at
        user.save!
      rescue => e
        puts e
      end
    end
  end
end
