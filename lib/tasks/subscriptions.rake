namespace :subscriptions do
  desc "Send brand subscriptions to users"
  task brands: :environment do
    Rails.logger.info "rake subscriptions:brands begins"
    subs = Subscription.all
    Rails.logger.debug "Subscriptions count: #{subs.size}"

    subs.each do |sub|
      Rails.logger.debug " * #{sub.id} for user #{sub.user.id rescue 'unknown user'} #{sub.user.name rescue ''} - #{sub.brand.id rescue 'unknown brand'} #{sub.brand.title rescue ''}"
      content_to_send = sub.find_content_to_send

      last_push_notification = SentMessage.where(user_id: sub.user.id, push_notification: true).where("sent_at IS NOT NULL").order("sent_at DESC").first
      if last_push_notification.present?
        Rails.logger.debug " * last time we pushed a notification: #{last_push_notification.sent_at}"
        if last_push_notification.sent_at > 1.minute.ago
          Rails.logger.debug " * holding off on sending, too recent"
          next
        else
          Rails.logger.debug " * OK to send!"
        end
      end

      if content_to_send.any?
        content_to_send = content_to_send.first(4)
        content_to_send.each do |c|
          if c.is_a?(Article)
            SentMessage.create(article_id: c.id, user_id: sub.user.id, brand_id: sub.brand.id, sent_at: Time.now, text: c.title, push_notification: true, subscription_id: sub.id)
          elsif c.is_a?(Show)
            SentMessage.create(show_id: c.id, user_id: sub.user.id, brand_id: sub.brand.id, sent_at: Time.now, text: c.title, push_notification: true, subscription_id: sub.id)
          end
        end
        Rails.logger.debug " ** Sending #{content_to_send.size} content pieces to user #{sub.user.id}"
        sub.user.deliver_message_for(content_to_send)
      else
        Rails.logger.debug " ** No new content to send user #{sub.user.id}"
      end
    end
    Rails.logger.info "rake subscriptions:brands done"
  end

  desc "Send top stories subscriptions to users"
  task top: :environment do
    Rails.logger.info "rake subscriptions:top begins"
    users = User.where(subscribe_top_stories: true).order("id ASC")
    Rails.logger.debug "Users subscribed to top stories count: #{users.size}"
    users.each do |user|
      Rails.logger.debug " * user #{user.id} #{user.name}"
      last_push_notification = SentMessage.where(user_id: user.id, push_notification: true).where("sent_at IS NOT NULL").order("sent_at DESC").first
      if last_push_notification.present?
        Rails.logger.debug " * last time we pushed a notification: #{last_push_notification.sent_at}"
        if last_push_notification.sent_at > 1.minute.ago
          Rails.logger.debug " * holding off on sending, too recent"
          next
        else
          Rails.logger.debug " * OK to send!"
        end
      end

      top_stories = Article.top_stories
      content_to_send = []
      top_stories.each do |top_story|
        sent_messages = SentMessage.where(article_id: top_story.id, user_id: user.id).where("sent_at IS NOT NULL").order("sent_at DESC")
        sent_messages ||= SentMessage.where(text: top_story.title, user_id: user.id).where("sent_at IS NOT NULL").order("sent_at DESC")
        if sent_messages.any?
          Rails.logger.debug " * already sent this story #{top_story.id} to user #{user.id}"
          next
        else
          Rails.logger.debug " * new top story #{top_story.id} for user #{user.id}"
          content_to_send << top_story
        end
      end

      if content_to_send.any?
        content_to_send = content_to_send.first(4)
        content_to_send.each do |c|
          SentMessage.create(article_id: c.id, user_id: user.id, sent_at: Time.now, text: c.title, push_notification: true)
          sm.update(brand: c.brand) if c.brand.present?
        end
        Rails.logger.debug " ** Sending #{content_to_send.size} content pieces to user #{user.id}"
        user.deliver_message_for(content_to_send)
      else
        Rails.logger.debug " ** No new content to send user ##{user.id}"
      end
    end
    Rails.logger.info "rake subscriptions:top done"
  end
end
