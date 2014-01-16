#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require_relative 'arxiv_twitter'
require_relative 'arxiv_article'
require_relative 'arxiv_category'
require 'rubygems'
require 'oauth'
require 'rss'
require 'yaml'

#
# Usage: ./arxiv.rb NAME    # => execute the target whose :name is NAME.
#        ./arxiv.rb         # => execute all the targets in the config file.
#

#
# After an execution of each category,
#   the category is removed IF the articles are found and tweeted OR trial reaches to MAX_TRIAL.
# When the process reaches to the tail of the category list, LONG SLEEP takes place.
#
# arXiv is updated at 00:00 UTC in summer and 01:00 UTC.
# You can cover both schedules with running this script at 00:00 UTC (with MAX_TRIAL = 6 and LONG_SLEEP_SEC = 1200).
#
#    For example in WINTER time, first execution (at 00:00) cannot found any articles since arXiv is not updated.
#    Thus all categories are executed again around 00:20 and 00:40, ...,
#      and probably the 5th execution (around 01:20) found the (updated) articles.
#    If 6th trial (around 01:40) fails, this script concludes no new articles are submitted and tweets so.
#
MAX_TRIAL       = 6
LONG_SLEEP_SEC  = 1200 # takes place between trials; 20min x 6trial = 2hours (see above!)
SHORT_SLEEP_SEC = 60   # takes place between the executions of each category.

@admin_email = nil
@go_ahead    = false



def send_mail(text, category_name = "xxx-xx")
  print "[SENDING EMAIL] #{category_name} : #{text}\n"

  if @go_ahead and @admin_email
    title = "[arXivSpeaker] #{category_name} : `date '+%Y/%m/%d %H:%M'`"

    # THIS SCRIPT USES "MAIL" COMMAND ON YOUR SERVER!
    `echo #{text} | mail -s "#{title}" '#{@admin_email}'`
  end
end


def do_sleep(duration)
  if @go_ahead
    sleep duration
  else
    print "[INFO] 'sleep' for #{duration} sec.\n"
  end
end


def execute(target)
  name  = target[:name]
  url   = target[:url] || "http://arxiv.org/list/#{name}/new"
  token = target[:token]

  if @go_ahead and not token
    send_mail("oauth_token for #{name} not found.", name)
    return nil
  end

  begin
    ac = ArxivCategory.new_from_html(name, url, token)
  rescue ArxivReadingException, str = nil
    print "[ERROR] ArxivReadingException! #{str}\n"
    message =  "arXiv:#{name} cannot be obtained."
    message += " Error: #{str}" if str
    send_mail(message, name)
    return nil
  end

  first_announcement = Time.now.strftime("*** [%d %b] New submissions for #{name} ***")
# first_announcement += " [sorry for hep-ex users; this is a test run. today's articles again. ]"

  ac.send_tweets(first_announcement) # returns the number of tweeted articles.
end


# ============================================================================== #
#                                THE MAIN ROUTINE                                #
# ============================================================================== #

config = YAML.load_file('arxiv_config.yml')

if ARGV.length > 0
  targets = config[:targets].select{ |t| t[:name] == ARGV[0] }
else
  targets = config[:targets]
end
if targets.nil? or targets.empty?
  print "[ERROR] no target found."
  exit 1
end

@admin_email = config[:email]    || nil
@go_ahead    = config[:go_ahead] || false
ArxivCategory.set_database_file(config[:database_file]) if config[:database_file]
ArxivTwitter.set_go_ahead(@go_ahead)


targets.each_with_index do |t, ind| # prepare tokens
  if @go_ahead
    token = OAuth::AccessToken.new(
              OAuth::Consumer.new(t[:consumer_key], t[:consumer_secret], :site=>"https://api.twitter.com"),
              t[:access_token], t[:access_secret])
    unless token
      print "[ERROR] invalid token for category #{t[:name]}."
      exit 1
    end
    targets.at(ind)[:token] = token
  end
end

# ---------------------
# code for announcement
#
if false
  targets.each do |target|
    announcement = "Sorry for the late announcement for 11 Oct. updates. Now the problem is fixed."
    ArxivTwitter.send_tweet(target[:token], announcement)
  end
  exit 0
end
# ---------------------

while true
  to_retry = []
  while targets.size > 0
    target = targets.shift
    tweeted = execute(target)

    # error handling
    if tweeted.nil? or tweeted == 0 # nil=>ERROR, 0=>NO ARTICLE
      target[:tried] = (target[:tried] || 0) + 1

      if target[:tried] < MAX_TRIAL
        to_retry.push(target)
      else
        # abandon
        message =  "arXiv:#{target[:name]} cannot be obtained"
        message += tweeted.nil? ? " with unexpected errors." : ". No Article found."
        announcement = Time.now.strftime("*** [%d %b] #{message} ***")

        ArxivTwitter.send_tweet(target[:token], announcement)
        send_mail(message, target[:name])
      end
    end

    # be gentle
    do_sleep(SHORT_SLEEP_SEC) if targets.size > 0
  end
  break if to_retry.empty?
  do_sleep(LONG_SLEEP_SEC)
  targets = to_retry
end
