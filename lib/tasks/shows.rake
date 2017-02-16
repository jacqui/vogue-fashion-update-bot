namespace :shows do
  desc "check for shows with missing images and try to fill them in"
  task images: :environment do
    missing_images = Show.where("image_uid IS NULL")

    require "http"

    missing_images.each do |show|
      puts "#{show.id} - #{show.title}"
      url = "http://vg.prod.api.condenet.co.uk/0.0/show?uid=#{show.uid}&expand=show.images.default"
      puts url
      data = HTTP.get(url).parse
      if data && data['data'] && data['data']['items'] && data['data']['items'].first
        showData = data['data']['items'].first
        if showData && showData['images'] && showData['images']['default']
          imgData = showData['images']['default']
          if imgData && imgData['uid']
            puts "  -- found image, updating with #{imgData['uid']}"
            show.update(image_uid: imgData['uid'])
          end
        end
      end
    end
  end

  desc "show grids: london"
  task london: :environment do
    require "csv"
    require 'date'

    puts "London..."
    Show.parse_grid("London", "Autumn/Winter 2017", "london.csv")
    puts
  end

  desc "show grids: milan"
  task milan: :environment do
    require "csv"
    require 'date'

    puts "Milan"
    Show.parse_grid("Milan", "Autumn/Winter 2017", "milan.csv")
    puts
  end

  desc "show grids: new york"
  task nyc: :environment do
    require "csv"
    require 'date'

    puts "New York..."
    Show.parse_grid("New York", "Autumn/Winter 2017", "new_york.csv")
    puts
  end

  desc "show grids: paris"
  task paris: :environment do
    require "csv"
    require 'date'

    puts "Paris..."
    Show.parse_grid("Paris", "Autumn/Winter 2017", "paris.csv")
    puts

  end

  desc "backfill major runway shows already published"
  task major: :environment do
    require "http"
    require "addressable/uri"

    puts "Initial shows (major) count: #{Show.where(major: true).count}"
    shows = paginated_get(major: 1)
    shows.each do |show|
      locationData = show.delete('location')
      location = Location.where(title: locationData['title'], slug: locationData['slug'], uid: locationData['uid']).first_or_create!

      seasonData = show.delete('season')
      season = Season.where(title: seasonData['title'], slug: seasonData['slug'], uid: seasonData['uid']).first_or_create!

      brandData = show.delete('brand')
      brand = Brand.where(title: brandData['title'], slug: brandData['slug'], uid: brandData['uid']).first_or_create!

      imageUid = if show['images'] && show['images']['default'] && show['images']['default']['uid']
                   show['images']['default']['uid']
                 end
      if theShow = Show.where(title: show['title'], slug: show['slug'], uid: show['uid'], brand: brand, season: season, location: location, image_uid: imageUid).first
        puts "Show '#{theShow.title}' already exists. Skipping."
        theShow.update(major: true)
        theShow.update(date_time: show['date_time'])
      else
        theShow = Show.create(title: show['title'], slug: show['slug'], uid: show['uid'], brand: brand, season: season, location: location, image_uid: imageUid, major: true, date_time: show['date_time'])
        if theShow.valid?
          theShow.shorten_url
          puts "Created show id##{theShow.id} for '#{theShow.title}'"
        else
          puts "Failed creating show #{theShow.title}: #{theShow.errors.full_messages}"
        end
      end
    end

    puts "Current shows (major) count: #{Show.where(major: true).count}"
  end

  desc "backfill non-major runway shows already published"
  task regular: :environment do
    require "http"
    require "addressable/uri"

    puts "Initial shows (regular) count: #{Show.where(major: false).count}"
    shows = paginated_get(major: 0)
    shows.each do |show|
      locationData = show.delete('location')
      location = Location.where(title: locationData['title'], slug: locationData['slug'], uid: locationData['uid']).first_or_create!

      seasonData = show.delete('season')
      season = Season.where(title: seasonData['title'], slug: seasonData['slug'], uid: seasonData['uid']).first_or_create!

      brandData = show.delete('brand')
      brand = Brand.where(title: brandData['title'], slug: brandData['slug'], uid: brandData['uid']).first_or_create!

      imageUid = if show['images'] && show['images']['default'] && show['images']['default']['uid']
                   show['images']['default']['uid']
                 end
      if theShow = Show.where(title: show['title'], slug: show['slug'], uid: show['uid'], brand: brand, season: season, location: location, image_uid: imageUid).first
        theShow.update(major: show['is_major'])
        theShow.update(date_time: show['date_time'])
      else
        theShow = Show.create(title: show['title'], slug: show['slug'], uid: show['uid'], brand: brand, season: season, location: location, image_uid: imageUid, major: show['is_major'], date_time: show['date_time'])
        if theShow.valid?
          theShow.shorten_url
          puts "Created show id##{theShow.id} for '#{theShow.title}'"
        else
          puts "Failed creating show #{theShow.title}: #{theShow.errors.full_messages}"
        end
      end
    end

    puts "Current shows (regular) count: #{Show.where(major: false).count}"
  end

  desc "Generate shortened urls for shows"
  task short: :environment do
    counter = 0
    Show.all.each do |a|
      if counter % 5 == 0
        sleep 1
      end
      a.shorten_url
    end
  end
end


def shows_url(params = {})
  page = params.delete(:page) { 1 }
  per_page = params.delete(:per_page) { 50 }
  major = params.delete(:major) { 0 }
  "https://vg.prod.api.condenet.co.uk/0.0/show?sort=published_at,DESC&published=1&is_major=#{major}&is_active=1&expand=show.season&expand=show.brand&expand=show.location&location=London&location=Milan&location=Paris&expand=show.images.default&per_page=#{per_page}&page=#{page}"
end
    
def get(params = {})
  show_url = shows_url(params)
  puts show_url
  HTTP.get(show_url).parse
end

def paginated_get(options = {})
  params  = options.dup
  page = 1
  results = []

  loop do
    data = get({ page: page }.merge(params))

    break if (data.empty? || data['data'].nil? || results.size > 100)
    items = data['data']['items']
    results += items

    page = page + 1
  end

  results
end

