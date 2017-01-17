module Marco
  module Storage
    class NullStore
      def initialize(_options = {})
      end

      def add(doc)
      end

      def exists?(query)
        false
      end

      def get(query)
        nil
      end

      def remove(query)
        true
      end

      def count
        0
      end

      def each
        yield nil
      end

      def clear
      end
    end
  end
end