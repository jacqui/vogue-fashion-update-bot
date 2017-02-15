env :PATH, ENV['PATH']

# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
set :output, "/tmp/runway_cron.log"
#
every 1.hour do
  rake "shows:major"
end

every 90.minutes do
  rake "shows:regular"
end

every 15.minutes do
  rake "articles:subs"
end

every 1.day do
  rake "brands:populate"
end

every 6.hours do
  rake "articles:top"
end

# Learn more: http://github.com/javan/whenever
