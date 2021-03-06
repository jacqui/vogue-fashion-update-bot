class Article < ApplicationRecord
  has_many :notifications
  belongs_to :brand, optional: true

  validates :url, uniqueness: true

  URL_TRACKING_PARAMS = "?utm_campaign=trial&utm_medium=social&utm_source=facebookbot"

  # after_create :setup_messages

  def self.top_stories
    where(tag: "top-stories").order("sort_order ASC")
  end

  def image_url
    "https://vg-images.condecdn.net/image/#{image_uid}/crop/500/0.525"
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

  def setup_messages
    puts "Setting up messages for delivery: '#{title}'..."
    brands = Brand.where(slug: tag)
    puts "brands: #{brands.size}"
    brands.each do |brand|
      brand.users.each do |user|
        duplicate_sent_message = SentMessage.where(article_id: id, user_id: user.id).first
        duplicate_notification = Notification.where(article_id: id, user_id: user.id).first

        if duplicate_sent_message.present?
          puts "Already sent this message (article: #{id}) to user #{user.id}!"
          duplicate_notification.update(sent: true, sent_at: duplicate_sent_message.sent_at) if duplicate_notification.present?
          next
        end

        if duplicate_notification.present?
          sent_status_message = duplicate_notification.sent? ? 'sent at ' + duplicate_notification.sent_at.to_formatted_s(:long_ordinal) : 'waiting to be sent'
          puts "Already have a notification for this article: #{id} to user #{user.id} (#{sent_status_message}) "
          next
        end

        last_sent_message = SentMessage.where(user_id: user.id).order("sent_at DESC").first

        ## Ensure we don't spam this user with too many messages in a row
        if last_sent_message && (Time.now - last_sent_message.sent_at <= 10)
          notification = Notification.create!(article: self, user: user, brand: brand, sent: false, sent_at: nil)
          puts "Created a notification to be sent in the next batch! ##{notification.id}"
          next

        else
          begin
            sm = SentMessage.create!(article: self, user: user, brand: brand, sent_at: Time.now)
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
    end
  end
end
