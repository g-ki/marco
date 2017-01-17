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
Sneakers.configure :log => STDOUT, :amqp => "amqp://guest:guest@rabbitmq:5672"
Sneakers.logger.level = Logger::INFO

class MarcoQueue
  include Sneakers::Worker

  from_queue 'out_queue',
              workers: 1,
              threads: 2

  def work(msg)
    res = JSON.parse(msg, symbolize_names: true)

    logger.info "<INFO from #{res[:id]} [STATUS: #{res[:status]}]>"
    logger.info ($counter += 1).to_s
    res[:links].each do |link|
      next unless $redis.sadd('visited', link[:url])

      publish(link.to_json, to_queue: 'in_queue')
    end

    ack!
  end
end