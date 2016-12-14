module Crawler
  module Mongodb

    def self.client
      @client = Mongo::Client.new([ 'mongo:27017' ], :database => 'extracted')
    end

    def insert(data)
      Mongodb.insert_one data
    end

  end
end
