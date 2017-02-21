class User < ApplicationRecord
  has_many :notifications
  has_many :subscriptions
  has_many :brands, -> { distinct }, through: :subscriptions
  has_and_belongs_to_many :broadcasts
  has_many :messages
  has_many :sent_messages

  def self.subscribed_top_stories
    where(subscribe_top_stories: true)
  end

  def self.subscribed_all_shows
    where(subscribe_all_shows: true)
  end

  def self.subscribed_major_shows
    where(subscribe_major_shows: true)
  end

  def self.with_show_subscriptions
    subscribed_all_shows + subscribe_major_shows + User.joins(:subscriptions).group('users.id')
  end

  def self.admin_users
    where(first_name: "Jacqui", last_name: "Maher")
  end

  # return true if this user is signed up for show alerts:
  #   * if 'all shows' then send all
  #   * if 'major shows' and this one is 'major'
  #   * if selected designers and this one is selected
  # AND
  # we have not sent one yet for this particular show
  def send_notification_for_show?(show)
    reason = ""
    if (brands.any? && brands.include?(show.brand))
      reason = "User ##{id} (#{name}) follows this show's brand. SEND."
    elsif (subscribe_major_shows && show.major?)
      reason = "User ##{id} (#{name}) subscribes to major shows. SEND."
    elsif subscribe_all_shows
      reason = "User ##{id} (#{name}) subscribes to all shows. SEND."
    else
      logger.debug "User ##{id} (#{name}) has no subscriptions, do not send."
      return false
    end

    last_push_notification = SentMessage.where(user_id: id, push_notification: true).where("sent_at IS NOT NULL").order("sent_at DESC").first
    if last_push_notification.present?
      if last_push_notification.sent_at > 1.minute.ago
        reason += " * last time we pushed a notification: #{last_push_notification.sent_at}; holding off on sending, too recent"
        return false
      end
    end

    already_sent = SentMessage.where("sent_at IS NOT NULL").where(show_id: show.id, user_id: id, push_notification: true)

    if already_sent.any?
      puts " * already sent a message to #{id} for show #{show.id} at #{already_sent.map(&:sent_at).join(', ')}"
      return false
    end

    reason += " Haven't sent alert for #{show.id} and designer #{show.brand.id} yet. SEND."
    puts reason
    logger.debug reason
    return true
  end

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
    if items.empty? || items.size <= 0
      User.alert_admins(id, "No items found to send user #{id}, alerting admins")
      return
    end

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

    if elements && elements.any?
      begin
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
      rescue => e
        User.alert_admins(id, "Failed sending message to user #{id} because: #{e}")
      end
    else
      User.alert_admins(id, "Failed sending message to user ##{id}, alerting admins")
    end
  end

  def self.alert_admins(recipient_id, text)
    User.admin_users.each do |admin|
      begin
        puts text
        Bot.deliver({
          recipient: { id: admin.fbid },
          message: { 
            text: text
          }
        })
      rescue => e
        puts "#{text}: #{e}"
      end
    end
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
