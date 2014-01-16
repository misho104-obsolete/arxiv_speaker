class TweetingException < Exception; end

class ArxivTwitter
  TWITTER_UPDATE_API = 'https://api.twitter.com/1.1/statuses/update.json'
  TWITTER_MAX_LENGTH = 140
  MAX_TRIES          = 4

  @@go_ahead = false
  def self.set_go_ahead(bool)
    @@go_ahead = bool
  end

  def self.send_tweet(token, content)
    text = nil
    begin
      if content.instance_of?(ArxivArticle)
        text = content.to_tweet(TWITTER_MAX_LENGTH)
      elsif content.instance_of?(String)
        text = content
      else
        return nil
      end
    rescue
      return nil
    end

    count = 0
    begin
      count += 1
      if @@go_ahead
        result = token.post(TWITTER_UPDATE_API, 'status'=> text)
        sleep 4 # be gentle...
      else
        print "TWEETING: #{text}\n";
      end
    rescue
      p "FAILED: #{text}"
      raise TweetingException if count > MAX_TRIES
      retry
    end
    return result
  end
end
