# -*- coding: utf-8 -*-
require 'rubygems'
require 'htmlentities'
require 'json'

class ArxivArticle
  # TODO: get url_length from API : https://api.twitter.com/1.1/help/configuration.json
  @@url_length        = 28 # canonically 24 ( https://dev.twitter.com/rest/reference/get/help/configuration ), but reserve four more for safety.
  @@author_min_length = 60
  @@html_encoder      = HTMLEntities.new

  attr_accessor :title, :author, :category, :number, :tweet_id

  def initialize(title = "", author = "", category = "", number = "")
    @title    = @@html_encoder.decode(title.gsub(/\.\s*$/, ""))
    @author   = @@html_encoder.decode(author)
    @category = category
    @number   = number
    @tweet_id = nil
  end

protected
  def author_array
    @author.gsub(/<.+?>/,"").gsub(/^\s+/,"").gsub(/\s+$/,"").gsub(/\s*\(.*?\)\s*/,"").split(/, ?/)
  end

  def author_family_names
    author_array.map do |a|
      if Regexp.new('collaborations?$', Regexp::IGNORECASE).match(a)
        a.gsub(/aborations?$/i, '.')
      elsif am = Regexp.new('([^ ]+)$').match(a)
        am[1]
      else
        a
      end
    end
  end

  def shorten_authors(length = ArxivTwitter::TWITTER_MAX_LENGTH)
    a = author_array
    f = author_family_names

    [@author, a.join(", "), f.join(", ")].each do |candidate|
      return candidate if candidate.length <= length
    end

    # all family names cannot be used. so we have ", ..." at the end.
    f.inject do |result, item|
      temp = "#{result}, #{item}, ..."
      if temp.length <= length
        result = "#{result}, #{item}"
      else
        return "#{result}, ..."
      end
    end
  end

  def shorten_title(length = ArxivTwitter::TWITTER_MAX_LENGTH)
    @title.length > length ? title[0, length - 3] + "..." : @title
  end

public
  def to_tweet(length = ArxivTwitter::TWITTER_MAX_LENGTH)
    # Twitter shortens the url. So we use @@url_length variable defined above.
    # "[#{m[2]}] #{author} : #{title} http://arxiv.org/abs/#{m[2]}"
    #     12    1          3         1
    max_length = length - (@@url_length + 12 + 1 + 3 + 1)

    a = shorten_authors([@@author_min_length, max_length - title.length].max)
    t = shorten_title(max_length - a.length)

    "[#{@number}] #{a} : #{t} http://arxiv.org/abs/#{@number}"
  end

  def to_json
    return "\"#{@number}\":\"#{@tweet_id}\",\n"
  end

  def send_tweet(access_token)
    result = ArxivTwitter.send_tweet(access_token, self)
    begin
      @tweet_id = JSON.parse(result.read_body)["id"]
    rescue
      @tweet_id = nil
    end
    return @tweet_id
  end
end
