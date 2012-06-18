#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'rubygems'
require 'oauth'
require 'rss'
require 'yaml'

def oauth_update(text, user)
  access_token = @tokens[user]
  result = ""
  count = 0
  while true
    count += 1
    begin
      result = access_token.post('http://twitter.com/statuses/update.xml', 'status'=> text)
    rescue
      p "FAILED: #{text}"
      if count > 4 
        str = "arXiv:#{tt} cannot be obtained."
        title = "[arXivSpeaker] #{str} : `date '+%Y/%m/%d %H:%M'`"
        `echo #{str} | mail -s "#{title}" root`
        exit 1
      end
    else
      return  (r = Regexp.new('<id>(\d+)</id>').match(result.read_body)) ? r[1] : ""
    end
  end
end

def save_ids(arxiv, tw)
  open('/vol1/www/html/arxiv/tw.dat', 'a') do |f|
    f << '"' << arxiv << '":"' << tw << '",' << "\n"
  end
end

def generate_authors(author_string, max_length)
  authors = author_string.gsub(/<.+?>/,"").gsub(/^\s+/,"").gsub(/\s+$/,"").gsub(/\s*\(.*?\)\s*/,"").split(/, ?/)
  family  = authors.map do |a|
    if Regexp.new('collaboration$', Regexp::IGNORECASE).match(a)
      a.gsub(/aboration$/, "")
    elsif am = Regexp.new('([^ ]+)$').match(a)
      am[1]
    else
      a
    end
  end
  author = ""
  if authors.join(", ").length <= [30, max_length].max
    author = authors.join(", ")
  elsif family.join(", ").length <= [30, max_length].max
    author = family.join(", ")
  else
    author = family.shift
    while true
      break if family.length == 0
      a = family.shift
      if author.length + 2 + a.length + 5 > [30, max_length].max # 2 for ", ", 5 for ", ..."
        author += ", ..."
        break
      end
      author += ", #{a}"
    end
  end
  return author
end

def truncate_title(title, len)
  return title.length > len ? title[0, len-3] + '...' : title
end

targets = [ 'hep-ph', 'hep-th', 'hep-ex', 'hep-lat' ]

if ARGV.length > 0
  if targets.member? ARGV[0]
    targets = [ ARGV[0] ]
  else
    p "#{ARGV[0]} is not a valid target." 
    exit 1
  end
end	

@tokens = {}
YAML.load_file('arxiv.yml').each do |k,v|
  @tokens[k] = OAuth::AccessToken.new(
                 OAuth::Consumer.new(v[:ck], v[:cs], :site=>"http://api.twitter.com"),
                 v[:at], v[:as])
end

@latest = YAML.load_file('arxiv_latest.yml')

targets.each do |tt|
  rss = RSS::Parser.parse("http://arxiv.org/rss/#{tt}")
  if rss.nil? or rss.items.length == 0 then
    str = "arXiv:#{tt} cannot be obtained."
    title = "[arXivSpeaker] #{str} : `date '+%Y/%m/%d %H:%M'`"
    `echo #{str} | mail -s "#{title}" root`
    next
  end

  user = tt.gsub(/-/,"").to_sym

  message = Time.now.strftime("*** [%d %b] New submissions for #{tt} ***")
# message += " [sorry for hep-ex users; this is a test run. today's articles again. ]"
  oauth_update(message, user)

  rss.items.each do |i|
    next unless m = Regexp.new('^(.+) \(arXiv:(\d\d\d\d\.\d\d\d\d)v\d+ \[(.+?)\](.*?)\)$').match(i.title)
    next if m[3] != tt or m[4] != ""
    next if @latest[user] >= m[2]

    @latest[user] = m[2]

    title = m[1].gsub(/\.$/, "")
    title_author_length = 100
    author = generate_authors(i.dc_creator, title_author_length - title.length)
    title = truncate_title(title, title_author_length - author.length)
    text = "[#{m[2]}] #{author} : #{title} http://arxiv.org/abs/#{m[2]}"
    #       11       1          3         1     20 (+4)   : thus author + title < 100
    print "#{text}\n"

    tw_id = oauth_update(text, user)
    save_ids(m[2], tw_id) if (not tw_id.nil?) and (tw_id != "")

    sleep(3)
  end
  p "#{tt} done."
  sleep(30)
end

open('arxiv_latest.yml', "w") do |file|
  file.write(@latest.to_yaml)
end

`wget http://www.misho-web.com/phys/arxiv_tw/generate.cgi`

