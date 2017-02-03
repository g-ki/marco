#!/usr/bin/ruby

require 'droplet_kit'
require 'net/ssh'

module Cloud
  class DigitalOcean
    include Cloud
    attr_reader :droplets
    alias_method :machines, :droplets

    def initialize
      load_config

      @client = DropletKit::Client.new(access_token: @config['token'])

      load_droplets
    end

    def load_droplets
      @droplets = @client.droplets.all.select { |d| d.name[/^#{@config['prefix']}-/] }
    end

    def master?
      master != nil
    end

    def master
      @master ||= @droplets.find { |d| droplet_type(d) == 'master' }
    end

    def workers
      @droplets.reject { |d| master.id == d.id }
    end

    def droplet_type(droplet)
      droplet.name.match(/^#{@config['prefix']}-(\w+)-/)[1]
    end

    def print_info
      if @droplets.size == 0
        puts "There is no droplets created. Create one.\n"
      else
        @droplets.each do |d|
          type = droplet_type d
          puts "#{d.id} #{d.name} (type: #{type}, ip: #{d.public_ip}, pvt ip: #{d.private_ip}, status: #{d.status})"
        end
        nil
      end
    end

    def create(type = nil)
      raise "Create master first!" if type != 'master' && !master?

      hostname = "#{@config['prefix']}-#{type}-#{droplets.size}" # TODO: better naming, avoid collision

      file_name = type == 'master' ? type : 'worker'
      userdata_file = File.join(ENV['MARCO_ROOT'], 'config', 'cloud', 'scripts', file_name + '.config.erb')

      userdata = parse_datafile(userdata_file)

      options = @config['droplet']

      droplet = DropletKit::Droplet.new(
        name: hostname,
        region: options['region'],
        size: options['size'],
        image: options['image'],
        private_networking: true,
        ssh_keys: @config['ssh_key_ids'],
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

        @droplets << created

        if type == 'master'
          print "Get swarm token... (30 secs)"
          sleep(30)
          token
        end
      else
        puts "Some error has occurred on droplet create (status was not 'new')"
        return false
      end

      return true
    end

    def delete(droplet_id)
      @client.droplets.delete(id: droplet_id) # validate success of this operation
      droplets.reject! { |d| d.id == droplet_id }
      puts "Success: #{droplet_id} deleted"
    end

    def token()
      return @worker_token if @worker_token

      master_ip = master.public_ip
      token = ""

      Net::SSH.start(master_ip, 'root', paranoid: false) do |ssh|
        while token.empty?
          ssh.exec! "docker swarm join-token worker -q" do |channel, stream, data|
            token << data if stream == :stdout
          end

          if token.empty?
            print '..'
            sleep(15)
          end
        end
        puts token
        @worker_token = token.chomp
      end

      @worker_token
    end

  end
end
