class Twitterfeed < ActiveRecord::Base
  attr_accessible :text, :title, :user, :video
  
    def self.parse_public_timeline
      url = URI.parse('http://api.twitter.com/1/statuses/public_timeline.json')
      req = Net::HTTP::Get.new(url.path)
      res = Net::HTTP.start(url.host, url.port) {|http|
        http.request(req)
      }
      json_string = res.body
      tweets = ActiveSupport::JSON.decode(json_string)    

      tweets.each do |tweet|      
        twittertext = tweet["text"]
        user_obj = tweet["user"]
        username = user_obj["screen_name"]
    
        twitterfeed = Twitterfeed.new
        twitterfeed.text = twittertext
        twitterfeed.user = username
        twitterfeed.save
      end
    end    
    
    def self.parse_trending_topics
      url = URI.parse('http://api.twitter.com/1/trends/2487956.json')
      req = Net::HTTP::Get.new(url.path)
      res = Net::HTTP.start(url.host, url.port) {|http|
        http.request(req)
      }
      json_string = res.body
      trending_topics = ActiveSupport::JSON.decode(json_string)    
      trending_topics.each do |trending_topic|
        trending_topic_obj = trending_topic["trends"]
        i=1
        trending_topic_obj.each do |topic|
          name = topic["name"]
          twitterfeed = Twitterfeed.new
          twitterfeed.text = name
          twitterfeed.user = i
          twitterfeed.save
          i=i+1
        end
      end
  end
  
  def self.parse_search_query(query)
    url = URI.parse('http://search.twitter.com/search.json')
    req = Net::HTTP::Get.new(url.path + '?q=' + query + '&lang=en')
    res = Net::HTTP.start(url.host, url.port) {|http|
      http.request(req)
    }
    json_string = res.body
    json_results = JSON.parse(json_string)
    json_results_obj = json_results["results"]
    
    json_results_obj.each do |search_result_obj|
      text = search_result_obj["text"]
      username = search_result_obj["from_user"]
      #text = 'RT @satrio_7: Jamie All Over - @MaydayParadeIND'
      #text = 'RT+%40satrio_7%3A+Jamie+All+Over+-+%40MaydayParadeIND'
      #text = 'whats my name by rihanna'
      #text = 'RT @lvnsykn: #nowplaying lady gaga - just dance! www.yahoo.com'
      #text = '\u30b8\u30e3\u30af\u30bd\u30f3\u796d\u308a\u306a\u3046\u266a #nowplaying Don\'t Stop \'Til You Get Enough / Michael Jackson -  (Album &quot;Off The Wall&quot;, Track 1)'
      twitterfeed = Twitterfeed.new
      unescaped_text = CGI.unescapeHTML(text)
      twitterfeed.text = unescaped_text
      #twitterfeed.user = username
      video_info = get_youtube_video(text)
      twitterfeed.video = video_info[0]
      twitterfeed.title = video_info[1]
      twitterfeed.user = video_info[2]
      twitterfeed.save
    end
  end
        
    def self.total_num_items
      @twitterfeeds.sum { |twitterfeed| twitterfeed.quantity }
    end
    
    def self.get_all_videos_for_page(twitterfeeds)
      @video_list = []
      twitterfeeds.each do |twitterfeed|
        if twitterfeed.video != nil
          @video_list = @video_list.concat([[twitterfeed.video, twitterfeed.title]])
        end
      end
            
      return @video_list
    end  
    
    def self.get_youtube_video(tweet)
      song_name = get_song_name(tweet)
      query = format_query(song_name)
      url = URI.parse('http://gdata.youtube.com/feeds/api/videos')
      http_url = url.path + '?q=' + query + '&orderby=relevance&start-index=1&max-results=1&v=2&alt=json'
      puts http_url
      req = Net::HTTP::Get.new(http_url)
      res = Net::HTTP.start(url.host, url.port) {|http|
        http.request(req)
      }
      json_string = res.body
      #puts "json string: #{json_string}"
      json_results = ActiveSupport::JSON.decode(json_string)    
      feed_results = json_results["feed"]
      entry_obj = feed_results["entry"]

      video = nil
      title = nil

      if entry_obj != nil
        entry_obj.each do |entry|

          id_obj = entry["id"]
          val_arr = id_obj.values
          vals = val_arr[0]
          video = vals[-11..-1]

          title_obj = entry["title"]
          val_arr = title_obj.values
          title = val_arr[0]
        end

      else
        puts feed_results  
      end

      return [video, title, song_name]

    end
    
    def self.get_song_name(tweet)

      #puts "the tweet is #{tweet}"
      r1 = Regexp.new(/\s?#\w+\s?/) #[^@(.+)]
      r2 = Regexp.new(/(http|https)?:?\/?\/?[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(([0-9]{1,5})?\/.*)?$/ix)
      r3 = Regexp.new(/@\w+/)
      r4 = Regexp.new(/\s?RT\s?/)
      r5 = Regexp.new(/\\u..../)
      song = tweet.gsub(r1, '') #remove #tags from tweet
      song = song.gsub(r2, '')
      song = song.gsub(r3, '')
      song = song.gsub(r4, '')
      song = song.gsub(r5, '')
      #puts "the song is #{song}"
      return song
    end
    
    private
      def self.format_query(query)
        formatted_query = CGI.escape(query)
        formatted_query = formatted_query.gsub(' ', '+')
        return formatted_query
      end
end
