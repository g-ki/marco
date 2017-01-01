require 'json'

module Crawler
  module Extractor
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

  end
end