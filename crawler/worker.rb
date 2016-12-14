require 'sneakers'
require 'logger'
require 'mechanize'
require 'json'
require 'redis'

require_relative "crawler"

rmq_addr = "rabbitmq"
Sneakers.configure :log => STDOUT, :amqp => "amqp://guest:guest@#{rmq_addr}:5672"
Sneakers.logger.level = Logger::INFO
Thread.abort_on_exception = true

class WebCrawler
  include Sneakers::Worker

  from_queue 'web_pages'

  def work(msg)
    logger.info '<Recived>'
    msg = JSON.parse(msg, symbolize_names: true)
    crawler_class, action = msg[:action].split('#')

    crawler_class = Crawler.load crawler_class

    response = {
      msg: msg,
      stats: {
        error: false
      }
    }

    crawler = crawler_class.new logger

    begin
      crawler.get msg[:url], action
    rescue Mechanize::ResponseCodeError => e
      response[:stats].merge!({
        error: true,
        response_code: e.response_code
      })
      logger.error e
    rescue Mechanize::Error, Timeout::Error => e
      response[:stats].merge!({
        error: true
      })
      logger.error e
    end

    response[:links] = crawler.queue

    publish(response.to_json, to_queue: 'craw_queue')
    logger.info "<#{msg[:url]} was crawled!>"

    return reject! if response[:stats][:error]
    ack!
  end
end