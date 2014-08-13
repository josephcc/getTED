require 'nokogiri'

require 'eventmachine'
require 'em-http-request'

require './parser'

BASEURL = "http://www.ted.com"
SEEDPATH = "/talks/browse?sort=popular"

GLOBAL = {:workers => 0}

def work
	GLOBAL[:workers] += 1
end

def done
	GLOBAL[:workers] -= 1
	if GLOBAL[:workers] <= 0
		EM.stop
	end
end

GLOBAL[:pages] = 1
GLOBAL[:max] = 3

def doTask(url, task)
	case task
	when 'list'
		work
		http = EM::HttpRequest.new(BASEURL + url).get
		http.callback {
			tree = Nokogiri::HTML http.response
			videos = getVideosFromList tree
			videos.each{|video| doTask video, 'video'}
			nextPage = getNextPageFromList tree
			if GLOBAL[:pages] < GLOBAL[:max]
				doTask nextPage, 'list'
				GLOBAL[:pages] += 1
			end
			done
		}
		http.errback {
			puts "list errback: #{http.error}"
			done
		}
	when 'video'
		work
		http = EM::HttpRequest.new(BASEURL + url).get
		http.callback {
			tree = Nokogiri::HTML http.response
			talkID = getTalkIDFromTalk tree
			mp3Link = getMp3LinkFromTalk tree
			subLink = getSubtitleLinkFromID talkID

			puts url
			puts talkID
			puts mp3Link
			puts subLink
			puts '-'*44

			done
		}
		http.errback {done}
	end
end

EM.run do
	doTask SEEDPATH, 'list'
end






