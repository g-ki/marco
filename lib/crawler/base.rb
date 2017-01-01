require 'mechanize'
require 'json'

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
    def get(url, action = nil, args = [])
      page = @mech.get url
      @logger.info "<GET #{url}>"

      return public_send(action, page, *args) if action

      page
    end

    ##
    # url: "http://example.com"
    # callback: extract_data
    # cb_args: [...]
    ##
    # Send 'url' to the Crawler Queue for further procesing with 'callback' and 'cb_args'
    ##
    def craw(url, callback, *cb_args)
      link = {
        method: :get,
        url: url,
        action: "#{name}##{callback}",
        action_args: cb_args
      }

      @queue << link
    end

    def name
      self.class.name
    end
  end
end