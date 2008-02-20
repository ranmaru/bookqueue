xml.instruct! :xml, :version=>"1.0" 
xml.rss(:version=>"2.0", 
        "xmlns:geo"     => "http://www.w3.org/2003/01/geo/wgs84_pos#",
        "xmlns:content" => "http://purl.org/rss/1.0/modules/content/",
        "xmlns:media"   => "http://search.yahoo.com/mrss/"
        ){
  xml.channel{
    xml.title("caffo's book queue")
    xml.link("http://books.nodecaf.org/")
    xml.description("caffo's book queue: currently reading, finished books and next ones.")
    xml.language('en-us')
      for post in @posts
        xml.item do
          xml.title(post.title)
          xml.description(post.body)           
          xml.pubDate(post.created_at.strftime("%a, %d %b %Y %H:%M:%S %z"))
          xml.link(post.link)
        end
      end
  }
}