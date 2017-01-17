module Default
  class Extractor
    include Crawler::Base
    include Crawler::Extractor

    def get_page(page)
      all_links(page)

      extract_data(page)
    end

    ##
    # get all links from a page and send them to be crawled
    ##
    def all_links(page)
      @logger.info "<GET ALL LINKS!>"
      page.links.each do |link|
        begin
          url = link.resolved_uri.to_s
          get(url, :get_page)
        rescue Exception => e
          @logger.error e
        end
      end
    end

    # EXTRACTORS

    def extract_title(page)
      page.title
    end

    def extract_vector(page)
      [
        page.images.size, page.forms.size, page.links.size,
        page.search("h1").size, page.search("h2").size,
        page.search("table").size
      ]
    end

    def extract_url(page)
      page.uri.to_s
    end

    def data_extracted(data)
      @logger.info data.to_s
      collection = URI.parse(URI.encode(data[:url])).host
      store = MongoPersistor.new('web_data').store(collection)

      store.add(data)
    end

  end
end