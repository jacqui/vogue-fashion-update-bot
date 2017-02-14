class Content < ApplicationRecord
  validates :title, uniqueness: true, presence: true
  validates :label, uniqueness: true, presence: true
  validates :body, presence: true

  after_save :update_facebook

  include Facebook::Messenger

  def update_facebook
    case label
    when "greeting"
      Facebook::Messenger::Thread.set({
        setting_type: 'greeting',
        greeting: {
          text: body
        },
      }, access_token: ENV['ACCESS_TOKEN'])
    end
  end
end
