require "sneakers"
require "sneakers/publisher"
require 'json'

Sneakers.configure :log => STDOUT, :amqp => "amqp://guest:guest@rabbitmq:5672", workers: 1
Sneakers.logger.level = Logger::INFO

seeds = [
  { url: 'http://www.biznes-katalog.bg/', action: "Default::Extractor#get_page", args: [] },
  { url: 'http://www.dmoz.org/', action: "Default::Extractor#get_page", args: [] },
  { url: 'http://www.goworkable.com/', action: "Default::Extractor#get_page", args: [] },
]

seeds.each do |seed|
  Sneakers.publish(seed.to_json, to_queue: 'in_queue')
end

