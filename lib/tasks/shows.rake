namespace :shows do
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

  desc "TODO"
  task populate: :environment do
    require "http"
    require "addressable/uri"
    
    puts "Initial shows count: #{Show.count}"
    shows = paginated_get()
    shows.each do |show|
      locationData = show.delete('location')
      location = Location.where(title: locationData['title'], slug: locationData['slug'], uid: locationData['uid']).first_or_create!

      seasonData = show.delete('season')
      season = Season.where(title: seasonData['title'], slug: seasonData['slug'], uid: seasonData['uid']).first_or_create!

      brandData = show.delete('brand')
      brand = Brand.where(title: brandData['title'], slug: brandData['slug'], uid: brandData['uid']).first_or_create!

      imageUrl = nil

      imageUid = if show['images'] && show['images']['default'] && show['images']['default']['uid']
                   show['images']['default']['uid']
                 end
      if imageUid
        imageUrl = "https://vg-images.condecdn.net/image/#{imageUid}/crop/500/0.4"
      end
      if theShow = Show.where(title: show['title'], slug: show['slug'], uid: show['uid'], brand: brand, season: season, location: location, image_url: imageUrl, major: show['is_major']).first
        puts "Show '#{theShow.title}' already exists. Skipping."
      else
        theShow = Show.create!(title: show['title'], slug: show['slug'], uid: show['uid'], brand: brand, season: season, location: location, image_url: imageUrl, major: show['is_major'])
        puts "Created show id##{theShow.id} for '#{theShow.title}'"
      end
    end

    puts "Current shows count: #{Show.count}"
  end

end

def shows_url(params = {})
  page = params.delete(:page) { 1 }
  per_page = params.delete(:per_page) { 50 }
  "https://vg.prod.api.condenet.co.uk/0.0/show?sort=published_at,DESC&published=1&is_active=1&expand=show.season&expand=show.brand&expand=show.location&location=London&location=Milan&location=Paris&expand=show.images.default&per_page=#{per_page}&page=#{page}"
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

