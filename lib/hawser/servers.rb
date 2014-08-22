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
      end
    end
  end
end
