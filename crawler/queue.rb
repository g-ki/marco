require 'redis'
require 'json'

module Crawler
  module Queue

    def queue
      @queue ||= []
    end

  end
end