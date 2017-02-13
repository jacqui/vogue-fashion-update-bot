json.extract! sent_message, :id, :type, :brand_id, :user_id, :article_id, :show_id, :sent_at, :text, :created_at, :updated_at
json.url sent_message_url(sent_message, format: :json)