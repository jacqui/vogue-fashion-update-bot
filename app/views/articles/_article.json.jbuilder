json.extract! article, :id, :title, :url, :publish_time, :created_at, :updated_at
json.url article_url(article, format: :json)