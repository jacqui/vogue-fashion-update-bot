class Content < ApplicationRecord
  validates :title, uniqueness: true, presence: true
  validates :label, uniqueness: true, presence: true
  validates :body, presence: true

  URL_TRACKING_PARAMS = "?utm_campaign=trial&utm_medium=social&utm_source=facebookbot"

  after_save :update_facebook

  include Facebook::Messenger

  def self.find_match_for(text)
    begin
      all_inputs = Content.pluck(:title)
      if matched_title = FuzzyMatch.new(all_inputs).find(text)
        content = Content.where(title: matched_title).first
        puts "Found a matching input: #{content.id} - #{content.body}"
        return content
      end
    rescue => e
      puts e
    end
  end

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

  def self.get_started(payload = "get_started")
    Facebook::Messenger::Thread.set({
      setting_type: 'call_to_actions',
      thread_state: 'new_thread',
      call_to_actions: [
        {
          payload: payload
        }
      ]
    }, access_token: ENV['ACCESS_TOKEN'])
  end

  def self.persist_menu
    Facebook::Messenger::Thread.set({
      setting_type: 'call_to_actions',
      thread_state: 'existing_thread',
      call_to_actions: [
        {
          type: 'postback',
          title: 'Top Stories',
          payload: 'top_stories'
        },
        {
          type: 'postback',
          title: 'Latest Shows',
          payload: 'latest'
        },
        {
          type: 'web_url',
          title: 'Subscribe to Vogue',
          url: 'http://www.vogue.co.uk/subscribe/' + CGI.escape(URL_TRACKING_PARAMS)
        }
      ]
    }, access_token: ENV['ACCESS_TOKEN'])
  end
end
