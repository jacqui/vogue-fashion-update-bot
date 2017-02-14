class User < ApplicationRecord
  has_many :notifications
  has_many :subscriptions
  has_many :brands, -> { distinct }, through: :subscriptions
  has_and_belongs_to_many :broadcasts

  def send_top_stories(quantity = 4)
    top_stories = Article.top_stories.limit(quantity)
    self.deliver_message_for(top_stories, "View the Article")
  end

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

  def deliver_message_for(articles, button_text)
    puts "Delivering message for user #{id}: #{articles.size}"
    elements = articles.map do |article|
      {
        title: article.title,
        image_url: article.image_url,
        default_action: {
          type: "web_url",
          url: article.url
        },
        buttons:[
          {
            type: "web_url",
            url: article.url,
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
