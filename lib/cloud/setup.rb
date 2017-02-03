#!/usr/bin/ruby

require 'droplet_kit'
require 'net/ssh'

module Cloud
  module Setup
    module_function

    def ssh_master(client, &block)
      Net::SSH.start(client.master.public_ip, 'root', paranoid: false, &block)
    end

    def wait_swarm(client)
      puts "Wait machines to join the swarm!"
      ssh_master(client) do |ssh|
        machines = 0
        while machines < client.machines.size
          output = ""
          ssh.exec! "docker node ls -q" do |channel, stream, data|
            output << data if stream == :stdout
          end
          machines = output.lines.count
          if machines < client.machines.size
            print "#{machines}/#{client.machines.size}"
            print '..'
            sleep(15)
          end
        end
      end
    end

    def master(client)
      ssh_master(client) do |ssh|
        ssh.exec! "docker network create --driver overlay marco-net"

        ssh.exec! "docker service create \
                    --publish=8888:8080/tcp \
                    --constraint=node.role==manager \
                    --mount=type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
                    --name=viz bargenson/docker-swarm-visualizer"

        ssh.exec! "docker service create  \
                    --network marco-net \
                    --publish=3000:3000 \
                    --env MONGO_URL=mongodb://mongo:27017/client \
                    --constraint=node.role==manager \
                    --name mongoclient mongoclient/mongoclient"
      end
    end

    def database(client, machine)
      data_v = "mongodata_#{machine.name}"
      config_v = "mongoconfig_#{machine.name}"

      # create volumes
      Net::SSH.start(machine.public_ip, 'root', paranoid: false) do |ssh|
        output = ""
        ssh.exec! "docker volume ls -q -f name=#{config_v}" do |channel, stream, data|
          output << data if stream == :stdout
        end

        if output.empty?
          ssh.exec! "docker volume create --name #{data_v}"
          ssh.exec! "docker volume create --name #{config_v}"
        end
      end

      # create database service
      ssh_master(client) do |ssh|
        ssh.exec! "docker service create --network marco-net \
                  --mount type=volume,source=#{data_v},target=/data/db \
                  --mount type=volume,source=#{config_v},target=/data/configdb \
                  --constraint=node.hostname==#{machine.name} \
                  --name mongo mongo:3.4"
      end
    end

    def label_roles(client, machines, labels = {})
      ssh_master(client) do |ssh|
        machines.each do |machine|
          type = client.droplet_type(machine)
          role = labels[type] || type

          ssh.exec! "docker node update \
                      --label-add marco.role=#{role} \
                      $(docker node ls -q -f name=#{machine.name})"
        end
      end
    end

    def redis(client, replicas = 1)
      ssh_master(client) do |ssh|
        ssh.exec "docker service create \
                  --network marco-net \
                  --constraint=node.labels.marco.role==supervisor \
                  --name redis redis:3.2"
      end
    end

    def rmq(client)
      ssh_master(client) do |ssh|
        ssh.exec "docker service create \
                    --publish 8080:15672 \
                    --network marco-net \
                    --constraint=node.labels.marco.role==queue \
                    --name rabbitmq rabbitmq:3.6-management"
      end
    end

    def crawler(client, replicas = 1)
      ssh_master(client) do |ssh|
        ssh.exec "docker service create \
                  --network marco-net \
                  --replicas=#{replicas} \
                  --constraint=node.labels.marco.role==crawler \
                  --name crawler george95/marco \
                  sneakers work WebCrawler --require workers/crawler.rb"
      end
    end

    def supervisor(client, replicas = 1)
      ssh_master(client) do |ssh|
        ssh.exec "docker service create \
                  --network marco-net \
                  --replicas=#{replicas} \
                  --constraint=node.labels.marco.role==supervisor \
                  --name supervisor george95/marco \
                  sneakers work MarcoQueue --require workers/supervisor.rb"
      end
    end

    def start_craw(client)
      ssh_master(client) do |ssh|
        ssh.exec "docker service create \
                  --network marco-net \
                  --constraint=node.labels.marco.role==supervisor \
                  --restart-condition none \
                  --name start_craw george95/marco \
                  ruby init.rb"
      end
    end

  end
end
