require 'mongo'
require 'thread'
require_relative "null_store"

module Marco
  module Storage
    class MongoStore < NullStore
      def initialize(options = {})
        @mongo      = options[:mongo]
        @collection = options[:collection]

        @semaphore = Mutex.new
      end

      def add(doc)
        @semaphore.synchronize do
          @mongo[@collection].insert_one(doc)
          doc[:_id]
        end
      end

      def exists?(query)
        @semaphore.synchronize do
          doc = @mongo[@collection].find(query).projection(_id: 1).limit(1).first
          not doc.nil?
        end
      end

      def get(query)
        @semaphore.synchronize do
          data = @mongo[@collection].find(query).limit(1).first
          data
        end
      end

      def remove(query)
        @semaphore.synchronize do
          @mongo[@collection].find(query).delete_one
        end
      end

      def count
        @mongo[@collection].find.count
      end

      def each
        @mongo[@collection].find.no_cursor_timeout do |cursor|
          cursor.each do |doc|
            yield doc
          end
        end
      end

      def clear
        @mongo[@collection].drop
      end
    end
  end
end