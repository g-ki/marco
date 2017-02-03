require_relative "../config/general"

require 'erb'
require 'fileutils'
require 'yaml'
require 'json'

module Cloud

  def name
    self.class.name.downcase.gsub('cloud::', '')
  end

  def load_config
    config_file = File.join(ENV['MARCO_ROOT'], 'config', 'cloud', name + '.yml')
    @config = YAML::load(File.open(config_file))
  end

  def parse_datafile(file)
    template = File.open(file).read
    renderer = ERB.new(template)

    renderer.result(binding)
  end

  def create(type)
    true
  end

  def destroy(id)
    true
  end

  def machines
    []
  end

  def master
    nil
  end

  def workers
    []
  end

  def token(reload: false)
    ''
  end

end

require_relative "cloud/setup"
require_relative "cloud/digitalocean"