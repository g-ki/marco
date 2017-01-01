require "sneakers"
require "json"

require 'logger'
require 'sneakers/runner'
require 'json'
require 'redis'
require 'hiredis'

$redis = Redis.new host: "redis", driver: :hiredis
$counter = 0

rmq_addr = "rabbitmq"
Sneakers.configure :log => STDOUT, :amqp => "amqp://guest:guest@rabbitmq:5672", workers: 1
Sneakers.logger.level = Logger::INFO

class MarcoQueue
  include Sneakers::Worker

  from_queue 'craw_queue'

  def work(msg)
    msg = JSON.parse(msg, symbolize_names: true)

    logger.info "<INFO from #{msg[:msg][:url]}>"
    logger.info ($counter += 1).to_s
    if (!msg[:stats][:error])
      msg[:links].each do |link|
        next unless $redis.sadd('visited', link[:url])

        publish(link.to_json, to_queue: 'web_pages')
      end
    end

    ack!
  end
end