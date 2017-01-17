require 'thor'
require 'net/ssh'
require_relative "../config/general"
require_relative "cloud"


#
# $ marco up CLOUD
# $ marco start CLOUD
# $ marco stop CLOUD
# $ marco down CLOUD
#
#

module Marco
  class CLI < Thor

    desc "up CLOUD, N", "Create and prepare N machines in the CLOUD."
    def up(cloud, n = 1)
      client = Cloud::DigitalOcean.new

      puts "Current state of #{cloud}"
      client.print_info

      n.to_i.times do
        client.create
      end

      puts "Machines are set!"
    end

    desc "start CLOUD", "Start marco containers on the machines running in the CLOUD."
    option :crawlers, required: true, type: :numeric
    option :supervisors, type: :numeric, default: 1
    option :useTor, type: :boolean
    option :tors, type: :numeric
    option :db
    def start(cloud)
      client = Cloud::DigitalOcean.new

      master_ip = client.master.public_ip
      Net::SSH.start(master_ip, 'root', paranoid: false) do |ssh|
        ssh.exec! "docker network create --driver overlay marco-net"

        if options[:db]
          data_v = "mongodata_#{client.master.name}"
          config_v = "mongoconfig_#{client.master.name}"

          ssh.exec! "docker volume create --name #{data_v}"
          ssh.exec! "docker volume create --name #{config_v}"

          ssh.exec! "docker service create --network marco-net --mount type=volume,source=#{data_v},target=/data/db --mount type=volume,source=#{config_v},target=/data/configdb --constraint 'node.hostname == #{client.master.name}' --name mongo mongo:3.4"

          puts "Wait mongo..."
          sleep(10)

          ssh.exec! "docker service create --name mongoclient --network marco-net -p 3000:3000 --env MONGO_URL=mongodb://mongo:27017/client mongoclient/mongoclient"
        end

        ssh.exec "docker service create --name rabbitmq -p 8080:15672 --network marco-net rabbitmq:3.6-management"
        ssh.exec "docker service create --name redis --network marco-net redis:3.2"


        tors = options[:tors] || options[:crawlers] * 2
        puts "tors: #{tors}" if options[:useTor]
        ssh.exec "docker service create --name tor-proxy -p 4444:4444 --env tors=#{tors} --network marco-net mattes/rotating-proxy:latest" if options[:useTor]
        ssh.loop

        ssh.exec "docker service create --name supervisor --replicas=#{options[:supervisors]} --network marco-net marco sneakers work MarcoQueue --require workers/supervisor.rb"
        ssh.exec "docker service create --name crawler --replicas=#{options[:crawlers]} --network marco-net marco sneakers work WebCrawler --require workers/crawler.rb"
        ssh.loop
      end
    end

    desc "stop CLOUD", "Stop marco containers."
    def stop(cloud)
      client = Cloud::DigitalOcean.new

      master_ip = client.master.public_ip
      Net::SSH.start(master_ip, 'root', paranoid:false) do |ssh|
        ssh.exec! "docker service rm $(docker service ls -q)"
      end
    end

    desc "down CLOUD", "Removes machines from the CLOUD."
    def down(cloud)
      client = Cloud::DigitalOcean.new
      client.machines.each { |m| client.delete(m.id) }
    end

    desc "rebuild CLOUD", "Rebuild marco image on all machines."
    def rebuild(cloud)
      client = Cloud::DigitalOcean.new
      client.machines.each do |machine|
        m_ip = machine.public_ip
        Net::SSH.start(m_ip, 'root', paranoid: false) do |ssh|
          ssh.exec! "docker build https://github.com/gk95/marco.git -t marco"
        end
        puts "Machine: #{m_ip} pulled from github!!!"
      end
    end

  end
end