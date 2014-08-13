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
GLOBAL[:log] = []

def doTask(payload, task)
	case task
	when 'list'
		work
		http = EM::HttpRequest.new(BASEURL + payload).get
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
		http = EM::HttpRequest.new(BASEURL + payload).get
		http.callback {
			tree = Nokogiri::HTML http.response
			talkID = getTalkIDFromTalk tree
			audioLink = getMp3LinkFromTalk tree
			subtitleLink = getSubtitleLinkFromID talkID

			puts payload
			puts talkID
			puts audioLink
			puts subtitleLink
			puts '-'*44

			log = {:url => payload, :talkid => talkID, :audio => audioLink, :subtitle => subtitleLink}
			doTask log, 'log'

			done
		}
		http.errback {
			puts "list errback: #{http.error}"
			done
		}
	when 'log'
		work
		GLOBAL[:log] << payload
		done
	end
end

EM.run do
	doTask SEEDPATH, 'list'
end

File.open('output.log', 'w') do |file|
	GLOBAL[:log].each do |log|
		file.write log
		file.write "\n"
	end
end





