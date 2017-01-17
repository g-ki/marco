module Crawler
end

require_relative "../config/general"
require_relative "storage"

Dir[File.join(ENV['MARCO_ROOT'], "/plugins/*.rb")].each { |file| require file }

require_relative "crawler/manager"

require_relative "crawler/base"
require_relative "crawler/extractor"