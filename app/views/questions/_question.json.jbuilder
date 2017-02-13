json.extract! question, :id, :order, :text, :created_at, :updated_at
json.url question_url(question, format: :json)