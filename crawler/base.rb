require 'mechanize'
require_relative './queue'
require 'json'

module Crawler
  module Base
    include Crawler::Queue

    def initialize(publisher, logger)
      @mech = Mechanize.new
      @publisher = publisher
      @logger = logger
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

      return public_send(action, page, *args) if action

      page
    end

    def start(url, action = nil, args = [])
      @seed_url = url
      get(url, action, args)
    end

    def crawler_name
      @crawler_name ||= self.class.name.gsub("Crawler::", '')
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
        action: "#{crawler_name}##{callback}",
        action_args: cb_args
      }

      queue << link
    end


    ##
    # Call all methods,starting with extract_, on 'data_block'
    # collect all results and send them to #data_extracted
    ##
    def extract_data(data_block)
      result = {}
      extractable = self.methods.select { |m| m != :extract_data && m.to_s[/extract_/] }
      extractable.each do |extract_method|
        begin
          method_key = extract_method.match(/extract_(.+)$/)[1]
          result[method_key] = public_send(extract_method, data_block)
        rescue => e
          @logger.error "EXTRACT_ERROR: #{extract_method}: #{e}"
        end
      end

      data_extracted(result)
    end

    ##
    # Do something with the extracted data...
    ##
    def data_extracted(data)
      p data
      # insert data into store
      # ...
      # ....
      # ..
      data
    end

    def finalize(status)
      # send status
      # send links
      msg = {
        status: true,
        url: @seed_url,
        links: queue
      }
      @publisher.publish(msg.to_json, to_queue: 'craw_queue')
    end

  end
end