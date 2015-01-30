require 'mattock'
require 'aws-sdk'

module Hawser
  class Volumes < Mattock::Tasklib
    default_namespace :volume

    setting :cluster_name
    setting :access_key
    setting :secret_key
    setting :region, "us-west-1"

    def define
      in_namespace do
        desc "Clone <from_dev> on <from_instance> to <to_dev> on <to_instance>"
        task :clone, [:from_instance, :from_dev, :to_instance, :to_dev] do |task, args|
          missing = [:from_instance, :from_dev, :to_instance].find_all do |key|
            args[key].nil?
          end

          unless missing.empty?
            fail "Missing required arguments: #{missing.inspect}"
          end

          to_dev = args[:to_dev] || args[:from_dev]

          ec2 = AWS::EC2.new(:region => region, :access_key_id => access_key, :secret_access_key => secret_key)

          instances = ec2.instances
          from_instance = instances.find do |inst|
            inst.instance_id == args[:from_instance]
          end

          to_instance = instances.find do |inst|
            inst.instance_id == args[:to_instance]
          end

          missing_instances = []
          if from_instance.nil?
            missing_instances << "Missing instance for #{args[:from_instance].inspect}"
          end
          if to_instance.nil?
            missing_instances << "Missing instance for #{args[:to_instance].inspect}"
          end
          unless missing_instances.empty?
            fail "Missing instances: #{missing_instances.join.inspect}"
          end

          require 'pp'
          from_device = from_instance.block_devices.find do |dev|
            dev[:device_name] == args[:from_dev]
          end
          unless from_device
            fail "No device mapped to #{args[:from_instance]} on #{args[:from_dev]}"
          end

          if to_instance.block_devices.any?{|dev| dev[:device_name] == to_dev}
            fail "A device is already mapped to #{args[:to_instance]} on #{to_dev}"
          end

          from_volume = ec2.volumes.find do |vol|
            from_device[:ebs][:volume_id] == vol.id
          end

          unless from_volume
            fail "No volume matches #{from_device[:ebs][:volume_id].inspect}"
          end

          snapshot_desc = from_volume.tags["Name"] || "From #{args[:from_instance]}:#{args[:from_dev]}"

          intermediate_snapshot = from_volume.create_snapshot(snapshot_desc)
          at_exit{ intermediate_snapshot.delete }

          wait_for_status("intermediate snapshot", intermediate_snapshot, :completed)

          new_volume = intermediate_snapshot.create_volume(to_instance.availability_zone)

          wait_for_status("volume creation", new_volume, :available)

          new_volume.attach_to(to_instance, to_dev)

          wait_for_status("volume attachment", new_volume, :in_use)

          puts "Done"
        end
      end

    end

    def wait_for_status(name, resource, goal)
      puts "Waiting for #{name}"
      until [goal, :error].include?(resource.status)
        print "."
        sleep 1
      end

      puts "\n  #{name} complete. Status: #{resource.status.inspect}"
      fail if resource.status != goal
    end

  end
end
