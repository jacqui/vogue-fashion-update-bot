include Facebook::Messenger
namespace :bot do
  desc "sets up the persistent menu"
  task menu: :environment do
    Facebook::Messenger::Thread.set({
      setting_type: 'call_to_actions',
      thread_state: 'existing_thread',
      call_to_actions: [
        {
          type: 'postback',
          title: 'Upcoming Shows',
          payload: 'upcoming'
        },
        {
          type: 'postback',
          title: 'Our Picks',
          payload: 'highlights'
        },
        {
          type: 'postback',
          title: 'Settings',
          payload: 'settings'
        },
        {
          type: 'web_url',
          title: 'Visit Vogue.co.uk',
          url: 'http://vogue.co.uk/'
        }
      ]
    }, access_token: ENV['ACCESS_TOKEN'])
  end

  desc "sets up the greeting text"
  task greeting: :environment do

    Facebook::Messenger::Thread.set({
      setting_type: 'greeting',
      greeting: {
        text: 'Chat with Vogue for the latest fashion news straight from the catwalk.'
      },
    }, access_token: ENV['ACCESS_TOKEN'])

    Facebook::Messenger::Thread.set({
      setting_type: 'call_to_actions',
      thread_state: 'new_thread',
      call_to_actions: [
        {
          payload: 'get_started'
        }
      ]
    }, access_token: ENV['ACCESS_TOKEN'])


  end
end
