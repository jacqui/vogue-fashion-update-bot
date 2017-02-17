class User < ApplicationRecord
  has_many :notifications
  has_many :subscriptions
  has_many :brands, -> { distinct }, through: :subscriptions
  has_and_belongs_to_many :broadcasts
  has_many :messages, foreign_key: :senderid

  def name
    [first_name, last_name].join(' ')
  end

  def send_top_stories(quantity = 4)
    top_stories = Article.top_stories.limit(quantity)
    if top_stories.any?
      self.deliver_message_for(top_stories)
    end
  end

  def follow_designer(brand)
    subscriptions.create!(user: self, brand: brand, signed_up_at: Time.now, sent_at: Time.now)
  end

  def deliver_message_for(items)
    puts "Delivering message for user #{id}: #{items.size}"
    elements = items.map do |item|
      button_text = item.is_a?(Article) ? "View the Article" : "View the Show"
      {
        title: item.title,
        image_url: item.image_url,
        default_action: {
          type: "web_url",
          url: item.url
        },
        buttons:[
          {
            type: "web_url",
            url: item.url,
            title: button_text
          }
        ]      
      }
    end
    Bot.deliver({
      recipient: {
        id: fbid
      },
      message: {
        attachment: {
          type: 'template',
          payload: {
            template_type: 'generic',
            elements: elements
          }
        }
      }
    }, access_token: ENV['ACCESS_TOKEN'])
    self.last_message_sent_at = Time.now
    self.save!
  end

  def self.create_with_sent_message(message)
    u = User.where(fbid: message.sender['id']).first_or_create
    puts "User: #{u.id} - #{u.fbid}"
    sent_message = SentMessage.create(user_id: u.id)

    return sent_message
  end

  def conversation
    Conversation.create_with(started_at: Time.now).find_or_create_by(user: self)
  end

  require 'httparty' # (if not already required)
  include HTTParty

  def get_sender_profile
    request = HTTParty.get(
      "https://graph.facebook.com/v2.6/#{fbid}",
      query: {
        access_token: ENV['ACCESS_TOKEN'],
        fields: 'first_name,last_name,gender,profile_pic'
      }
    )

    request.parsed_response
  end
end
