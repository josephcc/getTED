require 'net/http'
require 'nokogiri'


def getVideosFromList(tree)
	if tree.class != Nokogiri::HTML::Document
		tree = Nokogiri::HTML tree
	end
	links = tree.xpath '//a'
	links = links.to_a.map{|link| link.attr 'href'}
	links = links.select{|link| /^\/talks\/[^?]*$/.match link}
	links = links.reject{|link| link == '/talks/browse'}
	links.uniq
end

def getNextPageFromList(tree)
	if tree.class != Nokogiri::HTML::Document
		tree = Nokogiri::HTML tree
	end
	links = tree.xpath("//a[@rel='next' and text()='Next']")
#	throw "more than one next link on list page" unless links.size == 1
	if links.size == 0
		return nil
	end
	links[0].attr 'href'
end

=begin
<script>
  __ga('set', "dimension2", 66);
</script>
=end
def getTalkIDFromTalk(tree)
	if tree.class != Nokogiri::HTML::Document
		tree = Nokogiri::HTML tree
	end
	scripts = tree.xpath "//script"
	scripts = scripts.map{|script| script.text.strip}
	scripts = scripts.select{|script| /^__ga\(['"]set['"],\s*['"]dimension2['"],\s*\d+\);$/.match script}
#	throw "more than one talk ID on talk page: #{scripts}" unless scripts.size == 1
	if scripts.size == 0
		return nil
	end
	script = scripts[0]
	talkID = /^__ga\(['"]set['"],\s*['"]dimension2['"],\s*(\d+)\);$/.match(script)[1]
	talkID.to_i
end

def getSubtitleLinkFromID(talkID)
	"/talks/subtitles/id/#{talkID}/lang/en"
end

#"audioDownload":"http://download.ted.com/talks/SirKenRobinson_2006.mp3?apikey=489b859150fc58263f17110eeb44ed5fba4a3b22"
def getMp3LinkFromTalk(tree)
	if tree.class != Nokogiri::HTML::Document
		tree = Nokogiri::HTML tree
	end
	scripts = tree.xpath "//script"
	scripts = scripts.map{|script| script.text.strip}
	scripts = scripts.select{|script| /['"]audioDownload['"]\s*:\s*['"]http:\/\/download.ted.com\/talks\/[^'"]+['"]/.match script} 
#	throw "more than one talk audio on talk page: #{scripts}" unless scripts.size <= 1
	if scripts.size == 0
		return nil
	end
	script = scripts[0]
	mp3Link = /['"]audioDownload['"]\s*:\s*['"](http:\/\/download.ted.com\/talks\/[^'"]+)['"]/.match(script)[1]
	mp3Link
end

#"file":"http://download.ted.com/talks/SirKenRobinson_2006-320k.mp4?apikey=489b859150fc58263f17110eeb44ed5fba4a3b22"
def getMp4LinkFromTalk(tree)
	if tree.class != Nokogiri::HTML::Document
		tree = Nokogiri::HTML tree
	end
	scripts = tree.xpath "//script"
	scripts = scripts.map{|script| script.text.strip}
	scripts = scripts.select{|script| /['"]file['"]\s*:\s*['"]http:\/\/download.ted.com\/talks\/[^'"]+\.mp4[^"']+['"]/.match script} 
#	throw "more than one talk audio on talk page: #{scripts}" unless scripts.size <= 1
	if scripts.size == 0
		return nil
	end
	script = scripts[0]
	mp4Link = /['"]file['"]\s*:\s*['"](http:\/\/download.ted.com\/talks\/[^'"]+\.mp4[^"']+)['"]/.match(script)[1]
	mp4Link
end

if __FILE__ == $0

	BASEURL = "www.ted.com"
	SEEDPATH = "/talks/browse?sort=popular"

	html = Net::HTTP.get BASEURL, SEEDPATH
	videos = getVideosFromList html
	nextPage = getNextPageFromList html

	puts videos
	puts nextPage
	puts

=begin
	html = Net::HTTP.get BASEURL, nextPage
	videos = getVideosFromList html
	nextPage = getNextPageFromList html

	puts videos
	puts nextPage
=end

	videos.each do |video|
		html = Net::HTTP.get BASEURL, video
		talkID = getTalkIDFromTalk html
		mp3Link = getMp3LinkFromTalk html
		mp4Link = getMp4LinkFromTalk html
		subLink = getSubtitleLinkFromID talkID

		puts
		puts talkID
		puts mp3Link
		puts mp4Link
		puts subLink
	end

end
