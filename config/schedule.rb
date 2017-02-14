env :PATH, ENV['PATH']

# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
set :output, "/tmp/runway_cron.log"
#
every 15.minutes do
  rake "shows:populate"
end

every 5.minutes do
  rake "articles:subs"
end

every 30.minutes do
  rake "brands:populate"
end

every 12.hours do
  rake "articles:top"
end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever
