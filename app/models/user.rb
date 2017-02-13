class User < ApplicationRecord
  has_many :notifications
  has_many :subscriptions
  has_many :brands, -> { distinct }, through: :subscriptions
  has_and_belongs_to_many :broadcasts

  def subscribed_to_shows?
    !shows_subscription.blank?
  end

  def all_shows?
    !shows_subscription.blank? && shows_subscription == "All"
  end

  def brands_for_shows
    if subscribed_to_shows? && !all_shows?
      brand_ids = shows_subscription.split('||')
      Brand.find(brand_ids)
    elsif all_shows?
      Brand.all
    else
      []
    end
  end

  def add_show_subscription(brand)
    @my_brands = brands_for_shows
    @my_brands << brand
    my_brand_string = @my_brands.uniq.map(&:id).join('||')
    update(shows_subscription: my_brand_string)
    save!
  end

  def designers_following_text
    text = ""
    if subscriptions.any?
      text += Content.find_by_label("following_list").body
      subscriptions.each do |subscription|
        text += "\n#{subscription.brand.title}"
        # if subscription.brand.shows.any?
        #   text += " - #{subscription.brand.shows.first.title}"
        # end
      end
    else
      text += Content.find_by_label("following_none").body
    end
    text
  end

  def deliver_message_for(message_title, message_url, image_url, button_text)
    puts "Delivering message for user #{id}: #{message_title}"
    Bot.deliver({
      recipient: {
        id: fbid
      },
      message: {
        attachment: {
          type: 'template',
          payload: {
            template_type: 'generic',
            elements: [
              {
                title: message_title,
                image_url: image_url,
                default_action: {
                  type: "web_url",
                  url: message_url
                },
                buttons:[
                  {
                    type: "web_url",
                    url: message_url,
                    title: button_text
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

end
