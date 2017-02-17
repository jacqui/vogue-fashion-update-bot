namespace :brands do
  desc "populate the database with brands"
  task populate: :environment do
    require "http"
    require "addressable/uri"
    
    puts "Brands count: #{Brand.count}"
    brands = brand_paginated_get("tag")
    brands.each do |brand|
      if b = Brand.where(title: brand['title']).first
        puts "Brand #{b.title} already exists."
      else
        puts "Creating brand #{brand['title']}"
        Brand.create!(title: brand['title'], slug: brand['slug'], uid: brand['uid'])
      end
    end

    puts "Brands count: #{Brand.count}"
  end

end

def brands_url(path, params = {})
  api_params = { type: 'brand', per_page: '100' }

  Addressable::URI.new({
    scheme: "https",
    host: "vg.prod.api.condenet.co.uk",
    path: File.join("0.0", path),
    query_values: api_params.merge(params)
  })
end
    
def brand_get(path, params = {})
  brand_url = brands_url(path, params)
  puts brand_url
  HTTP.get(brand_url).parse
end

def brand_paginated_get(path, options = {})
  params  = options.dup
  per_page = params.delete(:per_page) { 100 }
  page = 1
#  max     = params.delete(:max) { 1000 }
  results = []

  loop do
    data = brand_get(path, { page: page, per_page: per_page }.merge(params))

    break if (data.empty? || data['data'].nil?)
    items = data['data']['items']
    results += items


    page = page + 1
  end

  results
end

