require 'sneakers'
require 'logger'
require 'sneakers/runner'
require 'mechanize'
require 'json'
require 'redis'
require_relative "Crawler/crawler"
require_relative "Crawler/queue"

rmq_addr = "rabbitmq"
Sneakers.configure :log => STDOUT, :amqp => "amqp://guest:guest@#{rmq_addr}:5672"
Sneakers.logger.level = Logger::INFO

# Crawler.configure

class WebCrawler
  include Sneakers::Worker

  from_queue 'web_pages'

  def work(msg)
    msg = JSON.parse(msg, symbolize_names: true)
    crawler_class, action = msg[:action].split('#')
    crawler = Crawler.load crawler_class

    c = crawler.new self, logger

    begin
      logger.info "<CRAW #{msg[:url]}>"
      c.start msg[:url], action
    rescue Exception => e
      c.finalize(false)
      logger.error "ERROR at #{msg[:url]}"
      logger.error e
      raise
    end


    c.finalize(true)
    logger.info "<#{msg[:url]} was crawled!>"
    ack!
  end

end

r = Sneakers::Runner.new([WebCrawler])
r.run