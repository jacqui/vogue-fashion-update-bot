namespace :articles do
  desc "find the articles for user subscriptions..."
  task subs: :environment do
    require 'http'
    Subscription.all.each do |sub|
      puts "#{sub.id}: #{sub.brand.title} - #{sub.user.fbid}"
      tag = sub.brand.slug
      url = "http://vg.prod.api.condenet.co.uk/0.0/article/?tag=#{tag}&sort=display_date,DESC&expand=article.images.default"
      data = HTTP.get(url).parse
      break if (data.empty? || data['data'].nil?)
      articleData = data['data']['items'].first
      imageUrl = nil

      imageUid = if articleData['images'] && articleData['images']['default'] && articleData['images']['default']['uid']
                   articleData['images']['default']['uid']
                 end
      if imageUid
        imageUrl = "https://vg-images.condecdn.net/image/#{imageUid}/crop/500/0.4"
      end

      articleUrl = "http://vogue.co.uk/article/uid/#{articleData['uid']}"
      if article = Article.where(title: articleData['title']).first
        puts "found existing article: #{article.id} #{article.title}"
      elsif article = Article.create(title: articleData['title'], url: articleUrl, publish_time: articleData['published_at'], tag: tag, image_url: imageUrl)
        puts "created article: #{article.id} #{article.title}"
      end
    end
  end

  desc "Populate the db with articles tagged for brands"
  task brands: :environment do
    require 'http'
    Brand.all.each do |brand|
      puts "#{brand.id}: #{brand.title} (#{brand.slug})"
      url = "http://vg.prod.api.condenet.co.uk/0.0/article/?tag=#{brand.slug}&sort=display_date,DESC&expand=article.images.default"
      data = HTTP.get(url).parse
      break if (data.empty? || data['data'].nil? || data['data']['items'].nil?)
      
      data['data']['items'].each do |articleData|
        articleUrl = "http://vogue.co.uk/article/uid/#{articleData['uid']}"
        imageUrl = nil

        imageUid = if articleData['images'] && articleData['images']['default'] && articleData['images']['default']['uid']
                     articleData['images']['default']['uid']
                   end
        if imageUid
          imageUrl = "https://vg-images.condecdn.net/image/#{imageUid}/crop/500/0.4"
        end
        article = Article.where(title: articleData['title']).first || Article.create(title: articleData['title'], url: articleUrl, publish_time: articleData['published_at'], tag: brand.slug, image_url: imageUrl)
        puts "created article: #{article.id} #{article.title} - #{article.tag}"
        puts
      end
    end
  end

  desc "Look for any pending notifications and send them out"
  task deliver: :environment do
    Notification.where(sent: false, sent_at: nil).each do |notification|
      sent_message = SentMessage.where(article: notification.article, user: notification.user, brand: notification.brand).first_or_create!
      if sent_message.sent_at.blank?
        sent_message.update sent_at: Time.now
      end
      notification.user.deliver_message_for(notification.article.title, notification.article.url, notification.article.image_url, "View the Article")
      notification.update(sent: true, sent_at: Time.now)
    end
  end
end
