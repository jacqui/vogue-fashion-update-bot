namespace :shows do
  desc "check for shows with missing images and try to fill them in"
  task images: :environment do

    Rails.logger.info "rake shows:images begins"
    missing_images = Show.where("image_uid IS NULL")

    require "http"

    missing_images.each do |show|
      Rails.logger.debug "#{show.id} - #{show.title}"
      url = "http://vg.prod.api.condenet.co.uk/0.0/show?uid=#{show.uid}&expand=show.images.default"
      Rails.logger.debug url
      data = HTTP.get(url).parse
      if data && data['data'] && data['data']['items'] && data['data']['items'].first
        showData = data['data']['items'].first
        if showData && showData['images'] && showData['images']['default']
          imgData = showData['images']['default']
          if imgData && imgData['uid']
            Rails.logger.debug "  -- found image, updating with #{imgData['uid']}"
            show.update(image_uid: imgData['uid'])
          end
        end
      end
    end
    Rails.logger.info "rake shows:images begins"
  end

  desc "show grids: london"
  task london: :environment do
    Rails.logger.info "rake shows:london begins"
    require "csv"
    require 'date'

    Rails.logger.debug "London..."
    Show.parse_grid("London", "Autumn/Winter 2017", "london.csv")
    puts
    Rails.logger.info "rake shows:london done"
  end

  desc "show grids: milan"
  task milan: :environment do
    Rails.logger.info "rake shows:milan begins"
    require "csv"
    require 'date'

    Rails.logger.debug "Milan"
    Show.parse_grid("Milan", "Autumn/Winter 2017", "milan.csv")
    puts
    Rails.logger.info "rake shows:milan done"
  end

  desc "show grids: new york"
  task nyc: :environment do
    Rails.logger.info "rake shows:nyc begins"
    require "csv"
    require 'date'

    Rails.logger.debug "New York..."
    Show.parse_grid("New York", "Autumn/Winter 2017", "new_york.csv")
    puts
    Rails.logger.info "rake shows:nyc begins"
  end

  desc "show grids: paris"
  task paris: :environment do
    Rails.logger.info "rake shows:paris begins"
    require "csv"
    require 'date'

    Rails.logger.debug "Paris..."
    Show.parse_grid("Paris", "Autumn/Winter 2017", "paris.csv")
    puts

    Rails.logger.info "rake shows:paris begins"
  end

  desc "backfill major runway shows already published"
  task major: :environment do
    Rails.logger.info "rake shows:major begins"
    require "http"
    require "addressable/uri"

    Rails.logger.debug "Initial shows (major) count: #{Show.where(major: true).count}"
    shows = paginated_get(major: 1)
    shows.each do |show|
      locationData = show.delete('location')
      location = Location.where(title: locationData['title'], slug: locationData['slug'], uid: locationData['uid']).first_or_create!

      seasonData = show.delete('season')
      season = Season.where(title: seasonData['title'], slug: seasonData['slug'], uid: seasonData['uid']).first_or_create!

      brandData = show.delete('brand')
      brand = Brand.create_with(title: brandData['title'], uid: brandData['uid']).find_or_create_by!(slug: brandData['slug'])

      imageUid = if show['images'] && show['images']['default'] && show['images']['default']['uid']
                   show['images']['default']['uid']
                 end
      if theShow = Show.where(title: show['title'], slug: show['slug'], uid: show['uid'], brand: brand, season: season, location: location, image_uid: imageUid).first
        Rails.logger.debug "Show '#{theShow.title}' already exists. Skipping."
        theShow.update(major: true, date_time: show['date_time'], published_at: show['published_at'])
      elsif theShow = Show.where(uid: show['uid']).first
        theShow.update(major: true, date_time: show['date_time'], image_uid: imageUid, published_at: show['published_at'])
      else
        theShow = Show.create(title: show['title'], slug: show['slug'], uid: show['uid'], brand: brand, season: season, location: location, image_uid: imageUid, major: true, date_time: show['date_time'], published_at: show['published_at'])
        if theShow.valid?
          theShow.shorten_url
          Rails.logger.debug "Created show id##{theShow.id} for '#{theShow.title}'"
        else
          Rails.logger.error "Failed creating show #{theShow.title}: #{theShow.errors.full_messages}"
        end
      end
    end

    Rails.logger.debug "Current shows (major) count: #{Show.where(major: true).count}"
    Rails.logger.info "rake shows:major done"
  end

  desc "backfill non-major runway shows already published"
  task regular: :environment do
    Rails.logger.info "rake shows:regular begins"
    require "http"
    require "addressable/uri"

    Rails.logger.debug "Initial shows (regular) count: #{Show.where(major: false).count}"
    shows = paginated_get(major: 0)
    shows.each do |show|
      locationData = show.delete('location')
      location = Location.where(title: locationData['title'], slug: locationData['slug'], uid: locationData['uid']).first_or_create!

      seasonData = show.delete('season')
      season = Season.where(title: seasonData['title'], slug: seasonData['slug'], uid: seasonData['uid']).first_or_create!

      brandData = show.delete('brand')
      # Rails.logger.debug brandData['slug']
      brand = Brand.create_with(title: brandData['title'], uid: brandData['uid']).find_or_create_by!(slug: brandData['slug'])

      imageUid = if show['images'] && show['images']['default'] && show['images']['default']['uid']
                   show['images']['default']['uid']
                 end
      if theShow = Show.where(title: show['title'], slug: show['slug'], uid: show['uid'], brand: brand, season: season, location: location, image_uid: imageUid).first
        theShow.update(major: show['is_major'], date_time: show['date_time'], published_at: show['published_at'])

      elsif theShow = Show.where(uid: show['uid']).first
        theShow.update(major: false, date_time: show['date_time'], image_uid: imageUid, published_at: show['published_at'])
      else
        theShow = Show.create(title: show['title'], slug: show['slug'], uid: show['uid'], brand: brand, season: season, location: location, image_uid: imageUid, major: false, date_time: show['date_time'], published_at: show['published_at'])
        if theShow.valid?
          theShow.shorten_url
          Rails.logger.debug "Created show id##{theShow.id} for '#{theShow.title}'"
        else
          Rails.logger.error "Failed creating show #{theShow.title}: #{theShow.errors.full_messages}"
        end
      end
    end

    Rails.logger.debug "Current shows (regular) count: #{Show.where(major: false).count}"
    Rails.logger.info "rake shows:regular done"
  end

  desc "Generate shortened urls for shows"
  task short: :environment do
    Rails.logger.info "rake shows:short begins"
    counter = 0
    Show.all.each do |a|
      if counter % 5 == 0
        sleep 1
      end
      a.shorten_url
    end
    Rails.logger.info "rake shows:short done"
  end
end


def shows_url(params = {})
  page = params.delete(:page) { 1 }
  per_page = params.delete(:per_page) { 50 }
  major = params.delete(:major) { 0 }
  "http://vg.prod.api.condenet.co.uk/0.0/show?sort=published_at,DESC&published=1&is_active=1&is_major=#{major}&expand=show.season&expand=show.brand&expand=show.location&expand=show.images.default&page=#{page}&per_page=#{per_page}"
end
    
def get(params = {})
  show_url = shows_url(params)
  Rails.logger.debug show_url
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

