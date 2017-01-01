#!/usr/bin/ruby

require 'droplet_kit'
require 'erb'
require 'fileutils'
require 'yaml'
require 'json'

class ElasticMarco
  def initialize
    config = YAML::load(File.open('config.yml'))

    @ssh_key_ids = config['ssh_key_ids'].to_a

    @files = {
      inventory: config['inventory_file'],
      master: config['userdata_master'],
      worker: config['userdata_worker']
    }

    @hostname_prefix = config['droplet_options']['hostname_prefix']
    @region = config['droplet_options']['region']
    @size = config['droplet_options']['size']
    @image = config['droplet_options']['image']

    @client = DropletKit::Client.new(access_token: config['token'])
    @inventory = {}

    get_inventory
  end

  def get_inventory

    if File.exist?(@files[:inventory]) == false
      raise "Inventory file doesn't exist! Create one."
    else
      file = File.read(@files[:inventory])
      file = "{}" if (file.empty?)
      @inventory = JSON.parse file, symbolize_names: true

      #load
      @inventory[:droplets].each do |droplet_id, value|
        droplet = @client.droplets.find(id: droplet_id)
        if droplet == '{"id":"not_found","message":"The resource you were accessing could not be found."}'
          raise "Inventory file contains a non-existent droplet id (#{droplet.id})!"
        else
          @inventory[:droplets][droplet_id][:droplet] = droplet
        end
      end
    end
  end

  def print_inventory
    if @inventory[:droplets].size == 0
      puts "The inventory file is empty. Use the create command.\n"
    else
      @inventory[:droplets].each do |id, value|
        droplet = value[:droplet]
        type = value[:type]
        puts "#{droplet.id} #{droplet.name} (type: #{type}, ip: pvt ip: #{droplet.public_ip} pvt ip: #{droplet.private_ip}, status: #{droplet.status})"
      end
      nil
    end
  end

  def create_server(type = 'worker')
    hostname = "#{@hostname_prefix}-#{type}-#{@inventory[:droplets].size}"
    userdata_file = @files[type.to_sym]

    userdata = parse_datafile(userdata_file)

    droplet = DropletKit::Droplet.new(
      name: hostname,
      region: @region,
      size: @size,
      image: @image,
      private_networking: true,
      ssh_keys: @ssh_key_ids,
      user_data: userdata
    )

    created = @client.droplets.create(droplet)
    droplet_id = created.id

    if (created.status == 'new')
      while created.status != 'active'
        print '.'
        sleep(15)  # wait for droplet to become active before checking again
        created = @client.droplets.find(id: droplet_id)
      end
      # droplet status is now 'active'
      @inventory[:droplets][created.id] = { type: type, droplet: created }

      save_inventory
      puts "Success: #{droplet_id} created and added to backend."

      if type == 'master'
        print "Get swarm token... (30 secs)"
        sleep(30)
        worker_token reload: true
        save_inventory
      end
    else
      puts "Some error has occurred on droplet create (status was not 'new')"
    end
  end

  def delete_server(droplet_id)
    if @inventory[:droplets][droplet_id.to_s.to_sym].nil?
      raise "Specified line does not exist in inventory! (line_number)"
    else
      @client.droplets.delete(id: droplet_id)
      @inventory[:droplets].delete droplet_id.to_s.to_sym
      save_inventory
      puts "Success: #{droplet_id} deleted and removed from backend."
    end
  end

  def master
    return @master if @master
    @master = @inventory[:droplets].select { |k, v| v[:type] == 'master' }.values.first[:droplet]
  end

  def worker_token(reload: false)
    return @inventory[:worker_token] if !reload && @inventory[:worker_token]

    master_ip = master.public_ip

    cmd = "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@#{master_ip} docker swarm join-token worker -q"
    token = `#{cmd}`
    while $?.exitstatus != 0
      print ".."
      sleep(15)
      token = `#{cmd}`
    end
    @inventory[:worker_token] = token.chomp
  end

  def parse_datafile(file)
    template = File.open(file).read
    renderer = ERB.new(template)

    renderer.result(binding)
  end

  def save_inventory
    json = @inventory.to_json
    inv = JSON.parse json, symbolize_names: true
    inv[:droplets].each {|k, v| v.delete(:droplet) }
    File.open('inventory.json', 'w') { |f| f.puts inv.to_json }
    puts "Inventory is saved!!!"
  end

end