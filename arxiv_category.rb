# -*- coding: utf-8 -*-

require 'nokogiri'
require 'open-uri'

class ArxivReadingException < Exception; end
class ArxivRssReadingException  < ArxivReadingException; end
class ArxivHtmlReadingException < ArxivReadingException; end


class ArxivCategory
  attr_accessor :name, :articles

  @@database_for_javascript = nil
  def self.set_database_for_javascript(file)
    @@database_for_javascript = file
  end


  def initialize(name, articles, oauth_token)
    @name        = name
    @articles    = articles
    @oauth_token = oauth_token
  end

  def read_from_rss(url)
    rss = RSS::Parser.parse(url)
    if rss.nil? or rss.items.length == 0 then
      raise ArxivRssReadingException
    end
    @articles = []
    rss.items.each do |i|
      # Higgs self-coupling measurements at the LHC. (arXiv:1206.5001v1 [hep-ph])
      m = Regexp.new('^(.+) \(arXiv:(\d\d\d\d\.\d\d\d\d)v\d+ \[(.+?)\](.*?)\)$').match(i.title)
      next if m.nil? or m[3] != @name or not m[4].empty?

      @articles.push ArxivArticle.new(m[1], i.dc_creator, @name, m[2])
    end
  end

  def read_from_html(url)
    begin
      doc = Nokogiri::XML(open(url)) { |conf| conf.noblanks.nonet }
    rescue
      raise ArxivHtmlReadingException
    end

    lists = doc.css('div#dlpage dl')
    raise ArxivHtmlReadingException if lists.nil? or lists.empty?

    dts = lists.first.css('dt')
    dds = lists.first.css('dd')
    raise ArxivHtmlReadingException if dts.nil? or dds.nil? or dts.length != dds.length

    @articles = []
    dts.length.times do |i|
      dt     = dts[i].content
      title  = dds[i].css('div.list-title').first.content
      author = dds[i].css('div.list-authors').first.content

      # "[1]arXiv:1206.5001 [pdf, ps, other]"
      # "Title: Higgs self-coupling measurements at the LHC\n"
      # "Authors:Matthew J. Dolan, \nChristoph Englert, \nMichael Spannowsky"

      number_match = Regexp.new('arXiv:(\d\d\d\d\.\d\d\d\d) ').match(dt)
      next unless number_match
      number = number_match[1]

      begin
        title.gsub!(/^Title:\s*/i,"").gsub!(/\s+/, " ")
        title.strip!
        author.gsub!(/^Authors?:\s*/i,"").gsub!(/\s+/, " ")
        author.strip!
      rescue
        raise ArxivHtmlReadingException
      end

      @articles.push ArxivArticle.new(title, author, @name, number)
    end
  end

  def send_tweets(first_announcement = nil)
    name_sym = @name.gsub(/-/, "").to_sym

    begin
      latest = YAML.load_file('arxiv_latest.yml')
      already_tweeted_id = latest[name_sym]
    rescue
    end
    latest ||= {}
    already_tweeted_id ||= ""

    tweeted_articles = 0
    begin
      data = ""
      first_tweet = true

      @articles.each do |a|
        next if a.number <= already_tweeted_id

        if first_tweet and first_announcement
          ArxivTwitter.send_tweet(@oauth_token, first_announcement)
        end
        first_tweet = false

        a.send_tweet(@oauth_token)
        already_tweeted_id = a.number
        data += a.to_json
        tweeted_articles += 1
      end
    rescue TweetingException => err
      raise err
    ensure
      if @@database_for_javascript
        open(@@database_for_javascript, 'a'){ |f| f << data }
        `wget http://www.misho-web.com/phys/arxiv_tw/generate.cgi` # hack for bang.js
      else
        print "\n--- FOR DATABASE ---\n"
        print data
        print "--------------------\n\n"
      end
    end

    latest[name_sym] = already_tweeted_id
    open('arxiv_latest.yml', "w") do |file|
      file.write(latest.to_yaml)
    end
    return tweeted_articles
  end

  def self.new_from_rss(name, url, oauth_token)
    a = self.new(name, nil, oauth_token)
    a.read_from_rss(url)
    a
  end

  def self.new_from_html(name, url, oauth_token)
    a = self.new(name, nil, oauth_token)
    a.read_from_html(url)
    a
  end
end



