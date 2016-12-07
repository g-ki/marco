require "sneakers"
require "json"
require_relative "publisher"

require 'logger'
require 'sneakers/runner'
require 'json'
require 'redis'
require 'hiredis'
require 'em-synchrony'


$pub  = Marco::Publisher.new host: 'rabbitmq'
$redis = Redis.new host: "redis", driver: :hiredis

rmq_addr = "rabbitmq"
Sneakers.configure :log => STDOUT, :amqp => "amqp://guest:guest@#{rmq_addr}:5672", workers: 1
Sneakers.logger.level = Logger::INFO

class MarcoQueue
  include Sneakers::Worker

  from_queue 'craw_queue'

  def work(msg)
    msg = JSON.parse(msg, symbolize_names: true)
    logger.info "<INFO from #{msg[:url]} status: #{msg[:status]}>"
    if (msg[:status])
      msg[:links].each do |link|
        next unless $redis.sadd('visited', link[:url])

        publish link.to_json, to_queue: 'web_pages'
      end
    end

    ack!
  end

end

msg = {
  method: :get,
  url: '',
  action: "Default::Extractor#all_links",
  action_args: []
}

urls = ["http://logon.com"]

urls.each do |url|
  msg[:url] = url
  $pub.publish msg.to_json, to_queue: 'web_pages'
end

r = Sneakers::Runner.new([MarcoQueue])
r.run