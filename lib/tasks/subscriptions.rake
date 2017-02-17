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

      if content_to_send.any?
        puts " ** Sending #{content_to_send.size} content pieces to user #{sub.user.id}"
        sub.user.deliver_message_for(content_to_send)
      else
        puts " ** No new content to send user #{sub.user.id}"
      end
    end
  end
end
