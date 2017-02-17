env :PATH, ENV['PATH']
set :path, "/home/ubuntu/messenger_bot/current"
set :output, {:error => '/home/ubuntu/messenger_bot/shared/log/cron_errors.log', :standard => '/home/ubuntu/messenger_bot/shared/log/cron_output.log'}

every 10.minutes do
  rake "shows:major"
end
 
every 8.minutes do
  rake "shows:regular"
end
 
# every 15.minutes do
#   rake "articles:subs"
# end

# every 1.day do
#   rake "brands:populate"
# end

every 1.hour do
  rake "articles:top"
end

# Learn more: http://github.com/javan/whenever
