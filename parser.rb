require 'net/http'
require 'nokogiri'

BASEURL = "www.ted.com"
SEEDPATH = "/talks/browse?sort=popular"

def getVideosFromList(html)
	tree = Nokogiri::HTML html
	links = tree.xpath '//a'
	links = links.to_a.map{|link| link.attr 'href'}
	links = links.select{|link| /^\/talks\/[^?]*$/.match link}
	links = links.reject{|link| link == '/talks/browse'}
	links.uniq
end

def getNextPageFromList(html)
	tree = Nokogiri::HTML html
	links = tree.xpath("//a[@rel='next' and text()='Next']")
	throw "more than one next link on list page" unless links.size == 1
	links[0].attr 'href'
end

=begin
<script>
  __ga('set', "dimension2", 66);
</script>
=end
def getTalkIDFromTalk(html)
	tree = Nokogiri::HTML html
	scripts = tree.xpath "//script"
	scripts = scripts.map{|script| script.text.strip}
	scripts = scripts.select{|script| /^__ga\(['"]set['"],\s*['"]dimension2['"],\s*\d+\);$/.match script}
	throw "more than one talk ID on talk page" unless scripts.size == 1
	script = scripts[0]
	talkID = /^__ga\(['"]set['"],\s*['"]dimension2['"],\s*(\d+)\);$/.match(script)[1]
	talkID.to_i
end

def getSubtitleLinkFromID(talkID)
	"/talks/subtitles/id/#{talkID}/lang/en"
end

#"audioDownload":"http://download.ted.com/talks/SirKenRobinson_2006.mp3?apikey=489b859150fc58263f17110eeb44ed5fba4a3b22"
def getMp3LinkFromTalk(html)
	tree = Nokogiri::HTML html
	scripts = tree.xpath "//script"
	scripts = scripts.map{|script| script.text.strip}
	scripts = scripts.select{|script| /['"]audioDownload['"]\s*:\s*['"]http:\/\/download.ted.com\/talks\/[^'"]+['"]/.match script} 
	throw "more than one talk ID on talk page" unless scripts.size == 1
	script = scripts[0]
	mp3Link = /['"]audioDownload['"]\s*:\s*['"](http:\/\/download.ted.com\/talks\/[^'"]+)['"]/.match(script)[1]
	mp3Link
end

if __FILE__ == $0

	html = Net::HTTP.get BASEURL, SEEDPATH
	videos = getVideosFromList html
	nextPage = getNextPageFromList html

	puts videos
	puts nextPage
	puts


	html = Net::HTTP.get BASEURL, nextPage
	videos = getVideosFromList html
	nextPage = getNextPageFromList html


	puts videos
	puts nextPage

	html = Net::HTTP.get BASEURL, videos[0]
	talkID = getTalkIDFromTalk html
	mp3Link = getMp3LinkFromTalk html
	subLink = getSubtitleLinkFromID talkID

	puts
	puts talkID
	puts mp3Link
	puts subLink

end
