require "sneakers"
require "sneakers/publisher"
require 'json'

Sneakers.configure :log => STDOUT, :amqp => "amqp://guest:guest@rabbitmq:5672", workers: 1
Sneakers.logger.level = Logger::INFO

pub = Sneakers::Publisher.new :amqp => "amqp://guest:guest@rabbitmq:5672"

msg = {
  method: :get,
  url: 'http://logon.com',
  action: "Default::Extractor#all_links",
  action_args: []
}

p msg

pub.publish(msg.to_json, to_queue: 'web_pages')

pub.instance_variable_get(:@bunny).stop