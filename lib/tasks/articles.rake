namespace :articles do
  desc "check for articles with missing images and try to fill them in"
  task images: :environment do

    puts "rake articles:images #{Time.now}"
    missing_images = Article.where("image_uid IS NULL")

    require "http"

    missing_images.each do |article|
      puts "#{article.id} - #{article.title}"
      Rails.cache.fetch("api:articles:#{article.id}") do
        url = "http://vg.prod.api.condenet.co.uk/0.0/article?title=#{article.title}&expand=article.images.default"
        puts url
        data = HTTP.get(url).parse
        if data && data['data'] && data['data']['items'] && data['data']['items'].first
          articleData = data['data']['items'].first
          if articleData && articleData['images'] && articleData['images']['default']
            imgData = articleData['images']['default']
            if imgData && imgData['uid']
              puts "  -- found image, updating with #{imgData['uid']}"
              article.update(image_uid: imgData['uid'])
            end
          end
        end
      end
    end
  end

  desc "find the articles for user top stories subscriptions..."
  task top: :environment do
    puts "rake articles:top #{Time.now}"
    require 'http'
    url = "http://vg.prod.api.condenet.co.uk/0.0/list/slug/facebook-bot-top-stories?expand=list.list_items.object.article.images.default&published=1"
    data = HTTP.get(url).parse

    if (data.empty? || data['data'].nil? || data['data']['list_items'].nil? )
      puts "Failed to get accurate article data for top stories"
      exit
    end

    listData = data['data']['list_items']

    tag = "top-stories"
    counter = 0
    listData.each do |itemData|
      next if counter > 4
      list_item = itemData['object']['data'] rescue nil

      next if list_item.nil?

      imageUid = if list_item['images'] && list_item['images']['default'] && list_item['images']['default']['uid']
                   list_item['images']['default']['uid']
                 end

      articleUrl = "http://vogue.co.uk/article/uid/#{list_item['uid']}"
      display_date = list_item['display_date'] || list_item['published_at']
      puts "display date: #{display_date}"

      if article = Article.where(title: list_item['title']).first
        puts "found existing article: #{article.id} #{article.title}"
        if article.sort_order.nil? && itemData['priority'].present? && article.display_date.nil? && display_date.present?
          puts "updating sort order and display date on article"
          article.update(sort_order: itemData['priority'], display_date: display_date)
        else
          article.update(sort_order: itemData['priority'])
        end

      elsif article = Article.create(title: list_item['title'], url: articleUrl, display_date: display_date, publish_time: list_item['published_at'], tag: tag, image_uid: imageUid, sort_order: itemData['priority'])
        puts "created article: #{article.id} #{article.title}"
      end
      counter += 1
    end
  end

  desc "find the articles for user subscriptions..."
  task subs: :environment do
    puts "rake articles:subs #{Time.now}"
    require 'http'
    Subscription.all.each do |sub|
      puts "#{sub.id}: #{sub.brand.title} - #{sub.user.fbid}"
      tag = sub.brand.slug
      url = "http://vg.prod.api.condenet.co.uk/0.0/article/?tag=#{tag}&sort=published_at,DESC&expand=article.images.default"
      data = HTTP.get(url).parse
      break if (data.empty? || data['data'].nil?)
      articleData = data['data']['items'].first

      imageUid = if articleData['images'] && articleData['images']['default'] && articleData['images']['default']['uid']
                   articleData['images']['default']['uid']
                 end

      articleUrl = "http://vogue.co.uk/article/uid/#{articleData['uid']}"
      if article = Article.where(url: articleUrl).first
        puts "found existing article: #{article.id} #{article.title}"
      elsif article = Article.create(title: articleData['title'], url: articleUrl, publish_time: articleData['published_at'], tag: tag, image_uid: imageUid)
        puts "created article: #{article.id} #{article.title}"
      end
    end
  end

  desc "Populate the db with articles tagged for brands"
  task brands: :environment do
    puts "rake articles:brands #{Time.now}"
    require 'http'
    Brand.all.each do |brand|
      Rails.cache.fetch("api:articles:brand:#{brand.id}") do
        puts "#{brand.id}: #{brand.title} (#{brand.slug})"
        url = "http://vg.prod.api.condenet.co.uk/0.0/article/?tag=#{brand.slug}&sort=published_at,DESC&expand=article.images.default"
        puts url

        begin
          data = HTTP.get(url).parse
          break if (data.empty? || data['data'].nil? || data['data']['items'].nil?)

          data['data']['items'].each do |articleData|
            articleUrl = "http://vogue.co.uk/article/uid/#{articleData['uid']}"

            imageUid = if articleData['images'] && articleData['images']['default'] && articleData['images']['default']['uid']
                         articleData['images']['default']['uid']
                       end
            if article = Article.where(url: articleUrl).first
              article.update(brand: brand) unless article.brand.present?
            else
              article = Article.create(title: articleData['title'], url: articleUrl, publish_time: articleData['published_at'], tag: brand.slug, image_uid: imageUid, brand: brand)
            end
            puts "created article: #{article.id} #{article.title} - #{article.tag}"
            puts
          end
        rescue => e
          puts e
        end
      end
    end
  end

  desc "Look for any pending notifications and send them out"
  task deliver: :environment do
    puts "rake articles:deliver #{Time.now}"
    Notification.where(sent: false, sent_at: nil).each do |notification|
      sent_message = SentMessage.where(article: notification.article, user: notification.user, brand: notification.brand).first_or_create!
      if sent_message.sent_at.blank?
        sent_message.update sent_at: Time.now
      end
      notification.user.deliver_message_for([notification.article])
      notification.update(sent: true, sent_at: Time.now)
    end
  end

  desc "Generate shortened urls for articles"
  task short: :environment do
    counter = 0
    Article.all.each do |a|
      if counter % 5 == 0
        sleep 1
      end
      a.shorten_url
    end
  end
end
