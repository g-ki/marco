module Default
  class Extractor
    include Crawler::Base

    ##
    # get all links from a page and send them to be crawled
    ##
    def all_links(page)
      @logger.info "<GET ALL LINKS!>"
      page.links.each do |link|
        begin
          url = link.resolved_uri.to_s
          get(url, :all_links)
        rescue Exception => e
          @logger.error e
        end
      end
    end

  end
end