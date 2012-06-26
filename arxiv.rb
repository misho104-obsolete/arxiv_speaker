#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require_relative 'arxiv_twitter'
require_relative 'arxiv_article'
require_relative 'arxiv_category'
require 'rubygems'
require 'oauth'
require 'rss'
require 'yaml'

def send_mail(text, target = "xxx-xx")
  print "mail : #{text} / #{target}\n"; return #MOCK

  title = "[arXivSpeaker] #{target} : `date '+%Y/%m/%d %H:%M'`"
  `echo #{text} | mail -s "#{title}" root`
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

targets.each do |target|
  token = @tokens[target.gsub(/-/, "").to_sym]
  unless token
    send_mail("oauth_token for #{target} not found.")
    next
  end

  begin
    ac = ArxivCategory.new_from_html(target, "http://arxiv.org/list/#{target}/new", token)
  rescue ArxivReadingException, str = nil
    p str
    send_mail("arXiv:#{target} cannot be obtained.")
    next
  end

  first_announcement = Time.now.strftime("*** [%d %b] New submissions for #{target} ***")
# first_announcement += " [sorry for hep-ex users; this is a test run. today's articles again. ]"

  ac.send_tweets(first_announcement)

  sleep 60 if @@go_ahead # if some crucial error occurs, misho will stop executing the following categories.
end

`wget http://www.misho-web.com/phys/arxiv_tw/generate.cgi` # hack for bang.js


