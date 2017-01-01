module Crawler::Manager

  ##
  # crawler : String
  # input : "Default::Extractor" -> path = 'default/extractor.rb'
  # return Default::Extractor
  ##
  def self.load(crawler)
    path = crawler.split('::').map { |s| underscore s }.join('/') + '.rb'

    require_relative '../../crawlers/' + path
    Object.const_get crawler
  end

  private
  ##
  # str   : String
  # input : "LinkExtractor"
  # return "link_extractor"
  ##
  def self.underscore(str)
    str
      .gsub(/::/, '/')
      .gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2')
      .gsub(/([a-z\d])([A-Z])/,'\1_\2')
      .tr("-", "_")
      .downcase
  end

end