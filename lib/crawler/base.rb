require 'mechanize'

module Crawler
  module Base
    attr_reader :queue

    def initialize(logger)
      @mech = Mechanize.new
      @logger = logger
      @queue = []
    end

    ##
    # url: "http://example.com"
    # action: extract_data
    # args: [...]
    ##
    # Make get request to 'url' and then call 'action' with arguments(response form the request, args)
    ##
    def get!(url, callback = nil, *args)
      page = @mech.get url
      @logger.info "<GET #{url}>"

      return public_send(callback, page, *args) if callback

      page
    end

    ##
    # url: "http://example.com"
    # callback: extract_data
    # cb_args: [...]
    ##
    # Send 'url' to the Crawler Queue for further procesing with 'callback' and 'args'
    ##
    def get(url, callback, *args)
      link = {
        url: url,
        action: "#{name}##{callback}",
        action_args: args
      }

      @queue << link
    end

    def name
      self.class.name
    end
  end
end