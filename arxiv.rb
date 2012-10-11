#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require_relative 'arxiv_twitter'
require_relative 'arxiv_article'
require_relative 'arxiv_category'
require 'rubygems'
require 'oauth'
require 'rss'
require 'yaml'

MAX_TRIAL      = 6
LONG_SLEEP_SEC = 1200 # 20min x 6trial = 2hours; valid both for summer and winter

def send_mail(text, target = "xxx-xx")
  p "#{target} : #{text}"

  title = "[arXivSpeaker] #{target} : `date '+%Y/%m/%d %H:%M'`"
  `echo #{text} | mail -s "#{title}" root`
end

def get_token(target)
  @tokens[target.gsub(/-/, "").to_sym]
end

def execute(target)
  token = get_token(target)
  unless token
    send_mail("oauth_token for #{target} not found.", target)
    return nil
  end

  begin
    ac = ArxivCategory.new_from_html(target, "http://arxiv.org/list/#{target}/new", token)
  rescue ArxivReadingException, str = nil
    p str
    message =  "arXiv:#{target} cannot be obtained."
    message += " Error: #{str}" if str
    send_mail(message, target)
    return nil
  end

  first_announcement = Time.now.strftime("*** [%d %b] New submissions for #{target} ***")
# first_announcement += " [sorry for hep-ex users; this is a test run. today's articles again. ]"

  articles = ac.send_tweets(first_announcement)
  return articles
end

# ==============================================================================

targets = [ 'hep-ph', 'hep-th', 'hep-ex', 'hep-lat' ]

if ARGV.length > 0
  if targets.member? ARGV[0]
    targets = [ ARGV[0] ]
  else
    p "#{ARGV[0]} is not a valid target."
    exit 1
  end
end

# - - - - - - - -

config = YAML.load_file('arxiv_config.yml')

@@go_ahead = false
if config[:go_ahead]
  if config[:database_for_javascript]
    ArxivCategory.set_database_for_javascript(config[:database_for_javascript])
  end
  ArxivTwitter.set_go_ahead(true)
  @@go_ahead = true
end

@tokens = {}
config[:tokens].each do |k,v|
  @tokens[k] = OAuth::AccessToken.new(
                 OAuth::Consumer.new(v[:ck], v[:cs], :site=>"http://api.twitter.com"),
                 v[:at], v[:as])
end


# - - - - - - - -
if false  # for announcement
  targets.each do |target|
    announcement = "Sorry for the late announcement for 11 Oct. updates. Now the problem is fixed."
    ArxivTwitter.send_tweet(get_token(target), announcement)
  end
  exit 0
end 


trial = {}
targets.push(LONG_SLEEP_SEC) # Fixnum means sleep (in sec.)

while targets.size > 0
  target = targets.shift

  if target.class == Fixnum # long sleep!
    if targets.size > 0
      sleep target
      targets.push(target)
    else
      # exit from this while loop.
    end
  else
    tweeted = execute(target)

    if tweeted.nil? or tweeted == 0 # nil=>ERROR, 0=>NO ARTICLE
      sym = target.gsub(/-/, "").to_sym
      trial[sym] = (trial[sym] || 0) + 1

      if trial[sym] < MAX_TRIAL
        targets.push(target) # retry after a long sleep
      else
        message =  "arXiv:#{target} cannot be obtained"
        if tweeted.nil?
          message += " with unexpected errors."
        else
          message += ". No Article found."
        end
        announcement = Time.now.strftime("*** [%d %b] #{message} ***")

        ArxivTwitter.send_tweet(get_token(target), announcement)
        send_mail(message, target)
      end
    else
      # No problem. Finish.
      sleep 60 if @@go_ahead # if some crucial error occurs, misho will stop executing the following categories.
    end
  end
end

