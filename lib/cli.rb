require 'thor'
require 'net/ssh'
require_relative "../config/general"
require_relative "cloud"


#
# $ marco up CLOUD
# $ marco start CLOUD
# $ marco craw CLOUD
# $ marco pause CLOUD
# $ marco down CLOUD
# $ marco info CLOUD
# $ marco rebuild CLOUD
#
#

module Marco
  class CLI < Thor

    desc "up CLOUD, N", "Create and prepare N machines in the CLOUD."
    option :config, type: :hash, required: true
    def up(cloud)
      config = options[:config]
      client = Cloud::DigitalOcean.new

      puts "Current state of #{cloud}"
      client.print_info

      unless client.master?
        puts "Creating master machine"
        client.create 'master'
        Cloud::Setup.master(client)
        Cloud::Setup.database(client, client.master)
      end

      config.each do |type, size|
        size.to_i.times do
          client.create type
        end
      end

      puts "Machines are started!"
      client.print_info

      Cloud::Setup.wait_swarm(client)
      Cloud::Setup.label_roles(client, client.machines)

      Cloud::Setup.rmq client
      Cloud::Setup.redis client
      puts "Machines are set!"
    end

    desc "start CLOUD", "Start marco containers on the machines running in the CLOUD."
    option :crawlers, type: :numeric
    option :supervisors, type: :numeric
    # option :useTor, type: :boolean
    # option :tors, type: :numeric
    def start(cloud)
      client = Cloud::DigitalOcean.new

      supervisors = client.machines.count { |m| m.name['supervisor'] }
      crawlers = client.machines.count { |m| m.name['crawler'] }

      supervisors = options[:supervisors] if options[:supervisors]
      crawlers = options[:crawlers] if options[:crawlers]

      Cloud::Setup.supervisor client, supervisors
      Cloud::Setup.crawler client, crawlers
    end

    desc "seed CLOUD", "Start crawling"
    def seed(cloud)
      client = Cloud::DigitalOcean.new
      Cloud::Setup.start_craw client
    end

    desc "pause CLOUD", "Pause crawlers."
    def pause(cloud)
      client = Cloud::DigitalOcean.new
      Cloud::Setup.ssh_master(client) do |ssh|
        ssh.exec! "docker service rm $(docker service ls -q -f name=crawler)"
        ssh.exec! "docker service rm $(docker service ls -q -f name=supervisor)"
      end
    end

    # desc "stop CLOUD", "Stop marco containers."
    # def stop(cloud)
    #   client = Cloud::DigitalOcean.new

    #   Cloud::Setup.ssh_master(client) do |ssh|
    #     ssh.exec! "docker service rm $(docker service ls -q -f name=crawler)"
    #     ssh.exec! "docker service rm $(docker service ls -q -f name=supervisor)"
    #     ssh.exec! "docker service rm $(docker service ls -q -f name=redis)"
    #     ssh.exec! "docker service rm $(docker service ls -q -f name=rabbitmq)"
    #   end
    # end

    desc "down CLOUD", "Removes machines from the CLOUD."
    option :total, type: :boolean, aliases: '-t'
    def down(cloud)
      client = Cloud::DigitalOcean.new
      client.print_info
      client.workers.each { |m| client.delete(m.id) }
      client.delete(client.master.id) if options[:total]
      client.print_info
    end

    desc "rebuild CLOUD", "Rebuild marco image on all machines."
    def rebuild(cloud)
      client = Cloud::DigitalOcean.new
      client.machines.each do |machine|
        Cloud::Setup.ssh_master(client) do |ssh|
          ssh.exec! "docker pull george95/marco"
        end
        puts "Machine: #{m_ip} pulled from docker hub!!!"
      end
    end

    desc "info CLOUD", "Print status of machines."
    def info(cloud)
      client = Cloud::DigitalOcean.new
      puts "Current state of #{cloud}"
      client.print_info
    end

  end
end