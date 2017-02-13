namespace :shows do
  desc "show grids"
  task grid: :environment do
    require "csv"
    require 'date'
#    Show.skip_callback(:create, :after, :send_message)
    
    location = Location.where(title: "London").first
    season = Season.where(title: "Autumn/Winter 2017").first

    CSV.foreach(Rails.root.join('data', 'london.csv')) do |row|
      next if row.first == "EXCLUDE" || row.first == "date"
      d = row[0]
      month, day, year = d.split('/')

      t = row[1]
      if t.match(" - ")
        t = t.split(" - ").first.strip
      elsif t.match(/TBD/i)
        t = "12:00"
      elsif t.match(/morning/i)
        t = "9:00"
      end
      hour, minute = t.split(":")

      day = "0#{day}" if day.size == 1
      month = "0#{month}" if month.size == 1
      datestr = [year, month, day].join('-')
      datestr += " "
      datestr += [hour, minute].join(':')
      parsed_date = DateTime.parse(datestr) rescue "Invalid Date: #{datestr}"

      title = row[2].strip.titleize
      brand = Brand.where(title: title).first
      if brand.nil?
        brands = Brand.where("title like '%#{title}%'")
        if brands && brands.size == 1
          brand = brands.first
          puts "[#{title}] found brand: #{brand.id}"
        else
          puts "[#{title}] found #{brands.size} matching brands"
          next
        end
      end

      if theShow = Show.where(title: title, slug: title.parameterize, brand: brand, season: season, location: location).first
        puts "Already had show #{theShow.title}"
      else
        theShow = Show.create(title: title, slug: title.parameterize, uid: ["XXXXX", Time.now.to_i, rand(10000)].join, brand: brand, season: season, location: location, date_time: parsed_date)
        if theShow.valid?
          puts "Created show #{theShow.title}"
        else
          byebug
          puts theShow.valid?
        end
      end
      name = title
      puts "#{d} #{t} #{name}"
    end
    
    #Show.set_callback(:create, :after, :send_message)

  end

  desc "TODO"
  task populate: :environment do
    require "http"
    require "addressable/uri"
    
    puts "Shows count: #{Show.count}"
    shows = paginated_get()
    shows.each do |show|
      locationData = show.delete('location')
      location = Location.where(title: locationData['title'], slug: locationData['slug'], uid: locationData['uid']).first_or_create!

      seasonData = show.delete('season')
      season = Season.where(title: seasonData['title'], slug: seasonData['slug'], uid: seasonData['uid']).first_or_create!

      brandData = show.delete('brand')
      brand = Brand.where(title: brandData['title'], slug: brandData['slug'], uid: brandData['uid']).first_or_create!

      if theShow = Show.where(title: show['title'], slug: show['slug'], uid: show['uid'], brand: brand, season: season, location: location).first
        puts "Show '#{theShow.title}' already exists. Skipping."
      else
        theShow = Show.create!(title: show['title'], slug: show['slug'], uid: show['uid'], brand: brand, season: season, location: location)
        puts "Created show id##{theShow.id} for '#{theShow.title}'"
      end
    end

    puts "Shows count: #{Show.count}"
  end

end

def shows_url(params = {})
  page = params.delete(:page) { 1 }
  "https://vg.prod.api.condenet.co.uk/0.0/show?sort=published_at,DESC&published=1&is_active=1&expand=show.season&expand=show.brand&expand=show.location&location=London&location=Milan&location=Paris&expand=article.images.default&per_page=20&page=#{page}"
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

    break if (data.empty? || data['data'].nil? || results.size > 50)
    items = data['data']['items']
    results += items

    page = page + 1
  end

  results
end

