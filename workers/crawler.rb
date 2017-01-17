require 'sneakers'
require 'logger'
require 'mechanize'
require 'json'
require 'redis'

require_relative "../lib/crawler"

Sneakers.configure :log => STDOUT, :amqp => "amqp://guest:guest@rabbitmq:5672"
Sneakers.logger.level = Logger::INFO
Thread.abort_on_exception = true

class WebCrawler
  include Sneakers::Worker

  from_queue 'in_pages',
              :workers => 2
              :threads => 2,
              :prefetch => 4,

  def work(msg)
    req = JSON.parse(msg, symbolize_names: true)
    crawler_class, action = req[:action].split('#')

    crawler_class = Crawler::Manager.load crawler_class

    crawler = crawler_class.new logger
    res = respond_to { crawler.get! req[:url], action, *req[:args] }

    res[:links] = crawler.queue
    res[:id] = req[:id]

    publish(res.to_json, to_queue: 'out_queue')
    logger.info "<#{req[:url]} was crawled! [STATUS: #{res[:status]}]>"

    ack!
  end

  private

  def respond_to()
    response = { status: 200 } # OK

    begin
      yield
    rescue Mechanize::ResponseCodeError => e
      response[:status] = e.response_code
      logger.error e
    rescue Mechanize::Error => e
      response[:status] = -1
      logger.error e
    rescue Timeout::Error => e
      response[:status] = -2
      logger.error e
    rescue StandardError => e
      response[:status] = -3
      logger.error e
    end

    response
  end

end