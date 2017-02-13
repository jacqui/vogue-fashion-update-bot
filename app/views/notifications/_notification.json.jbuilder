json.extract! notification, :id, :user_id, :article_id, :brand_id, :sent_at, :sent, :show_id, :created_at, :updated_at
json.url notification_url(notification, format: :json)