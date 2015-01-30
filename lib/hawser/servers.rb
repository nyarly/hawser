require "mattock"
require 'aws-sdk'

module Hawser
  class Servers < Mattock::Tasklib
    default_namespace :servers

    setting :cluster_name
    setting :access_key
    setting :secret_key
    setting :region, "us-west-1"

    def define
      in_namespace do
        desc "List servers for #{cluster_name}"
        task :list do
          require 'yaml'
          ec2 = AWS::EC2.new(:region => region, :access_key_id => access_key, :secret_access_key => secret_key)
          puts(YAML::dump( ec2.instances.map do |instance|
            { "cluster_name" => cluster_name,
              "platform" => "aws",
              "id_from_platform" => instance.instance_id,
              "private_dns_name" => instance.public_dns_name,
              "public_dns_name" => instance.public_dns_name,
              "private_ip_address" => instance.private_ip_address,
              "public_ip_address" => instance.public_ip_address,
              "architecture" => instance.architecture.to_s,
              "availability_zone" => instance.placement[:availability_zone],
              "launch_time" => instance.launch_time,
              "image_id" => instance.image_id,
              "key_name" => instance.key_name }
          end))
        end

        desc "View details for a server for #{cluster_name}"
        task :view, [:id] do |task, args|
          if args[:id].nil?
            fail ":id is required"
          end
          require 'yaml'
          ec2 = AWS::EC2.new(:region => region, :access_key_id => access_key, :secret_access_key => secret_key)

          instance = ec2.instances.find do |inst|
            inst.instance_id == args[:id]
          end

          if instance.nil?
            fail "Couldn't find instance with id #{args[:id]} in #{ec2.instances.map{|inst| inst.instance_id}}"
          end

          require 'pp'
          pp instance
          pp instance.class.ancestors
          puts instance.to_yaml
          pp instance.block_device_mappings

        end
      end
    end
  end
end
