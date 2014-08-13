require 'nokogiri'

require 'eventmachine'
require 'em-http-request'

require './parser'

BASEURL = "http://www.ted.com"
#SEEDPATH = "/talks/browse?sort=popular"
SEEDPATH = "/talks/browse?page=19"
DLPATH = "/Volumes/SILVER/TED"
MAX_RETRY = 20

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
GLOBAL[:max] = 51
GLOBAL[:log] = []

def doTask(payload, task)
	case task
	when 'list'
		work
		doTask({:url => payload}, 'log')
		http = EM::HttpRequest.new(BASEURL + payload).get :redirects => 10
		http.callback {
			tree = Nokogiri::HTML http.response
			videos = getVideosFromList tree
			videos.each{|video| doTask video, 'video'}
			nextPage = getNextPageFromList tree
			if nextPage and GLOBAL[:pages] < GLOBAL[:max]
				doTask nextPage, 'list'
				GLOBAL[:pages] += 1
			end
			done
		}
		http.errback {
			puts "list errback: #{http.error}: #{payload}"
			work
			EM.add_timer(10) {
				doTask payload, 'list'
				done
			}
			done
		}
	when 'video'
		work
		http = EM::HttpRequest.new(BASEURL + payload).get :redirects => 10
		http.callback {
			tree = Nokogiri::HTML http.response
			talkID = getTalkIDFromTalk tree
			audioLink = getMp3LinkFromTalk tree
			videoLink = getMp4LinkFromTalk tree
			subtitleLink = getSubtitleLinkFromID talkID

			talk = {:url => payload, :talkid => talkID, :audio => audioLink, :subtitle => subtitleLink, :video => videoLink}
			doTask talk, 'log'

			audioPayload = {:url => talk[:audio], :extension => 'mp3', :talkid => talk[:talkid], :retry => 0}
			subtitlePayload = {:url => BASEURL + talk[:subtitle], :extension => 'json', :talkid => talk[:talkid], :retry => 0}
			videoPayload = {:url => talk[:video], :extension => 'mp4', :talkid => talk[:talkid], :retry => 0}
=begin
			if talk[:talkid] and talk[:audio] and talk[:subtitle]
				doTask audioPayload, 'download'
				doTask subtitlePayload, 'download'
			end
=end
			if talk[:talkid] and talk[:audio] == nil and talk[:subtitle] and talk[:video]
				doTask subtitlePayload, 'download'
				doTask videoPayload, 'download'
			end

			done
		}
		http.errback {
			puts "video errback: #{http.error}: #{payload}"
			work
			EM.add_timer(10) {
				doTask payload, 'video'
				done
			}
			done
		}
	when 'download'
		work
		path = File.join DLPATH, "#{payload[:talkid]}.#{payload[:extension]}"
		if File.exists? path
			done
		else
			http = EM::HttpRequest.new(payload[:url]).get :redirects => 10
			http.callback {
				work
				writeFile = proc do
					File.open(path, 'wb') do |file|
						file.write http.response
					end
				end
				EM.defer writeFile, done
				done
			}
			http.errback {
				puts "download errback: #{http.error}: #{payload}"
				if payload[:retry] < MAX_RETRY
					payload[:retry] += 1
					work
					EM.add_timer(payload[:retry]) {
						doTask payload, 'download'
						done
					}
				end
				done
			}
		end

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





