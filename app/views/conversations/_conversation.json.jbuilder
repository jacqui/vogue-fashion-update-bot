json.extract! conversation, :id, :user_id, :started_at, :last_message_sent_at, :transcript, :created_at, :updated_at
json.url conversation_url(conversation, format: :json)