json.extract! response, :id, :question_id, :option_id, :text, :created_at, :updated_at
json.url response_url(response, format: :json)