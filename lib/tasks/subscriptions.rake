namespace :subscriptions do
  desc "Send brand subscriptions to users"
  task brands: :environment do
    require "http"
    require "addressable/uri"
    
    subs = Subscription.all
    puts "Subscriptions count: #{subs.size}"

    subs.each do |sub|
      puts " * #{sub.id} for user #{sub.user.id} #{sub.user.name} - #{sub.brand.id} #{sub.brand.title}"
      content_to_send = sub.find_content_to_send

      last_push_notification = SentMessage.where(user_id: sub.user.id, push_notification: true).where("sent_at IS NOT NULL").order("sent_at DESC").first
      if last_push_notification.present?
        puts " * last time we pushed a notification: #{last_push_notification.sent_at}"
        if last_push_notification.sent_at > 1.minute.ago
          puts " * holding off on sending, too recent"
          next
        else
          puts " * OK to send!"
        end
      end

      if content_to_send.any?
        content_to_send.each do |c|
          if c.is_a?(Article)
            SentMessage.create(article_id: c.id, user_id: sub.user.id, brand_id: sub.brand.id, sent_at: Time.now, text: c.title, push_notification: true, subscription_id: sub.id)
          elsif c.is_a?(Show)
            SentMessage.create(show_id: c.id, user_id: sub.user.id, brand_id: sub.brand.id, sent_at: Time.now, text: c.title, push_notification: true, subscription_id: sub.id)
          end
        end
        puts " ** Sending #{content_to_send.size} content pieces to user #{sub.user.id}"
        sub.user.deliver_message_for(content_to_send)
      else
        puts " ** No new content to send user #{sub.user.id}"
      end
    end
  end
end
