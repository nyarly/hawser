require 'mattock'
require 'hawser/baking-command'

module Hawser
  class Baking < Mattock::Tasklib
    include Caliph::CommandLineDSL

    default_namespace :baking

    setting :location, "us-west-1"

    setting :arch, "x86_64"
    setting :ec2_version_pattern, "1.4.0.5 20071010"

    dir(:ephemeral_dir, "/mnt",
        dir(:keyfile_dir, "keys",
            path(:private_key, "pk.pem"),
            path(:certificate_file, "cert.pem")))

    path(:signing_cert, "cert.pem")
    path(:signing_key, "key.pem")

    setting(:image_name).isnt(:required)
    setting(:bucket)

    setting :access_key
    setting :secret_key
    setting :aws_account_id

    setting(:remote_server, nested{
      setting(:address).isnt(:required)
      setting :port, 22
      setting :user, nil
    })

    def resolve_configuration
      ephemeral_dir.absolute_path = ephemeral_dir.relative_path

      super
      resolve_paths
    end

    def define
      in_namespace do
        Mattock::Rake::RemoteCommandTask.define_task(:create_dirs => :collect) do |task|
          task.remote_server = proxy_value.remote_server
          task.command = cmd("mkdir") do |mkdir|
            mkdir.options << "-p" #ok
            mkdir.options << keyfile_dir.abspath
          end
        end

        Mattock::Rake::CommandTask.define_task(:copy_cert => [:collect, :create_dirs]) do |task|
          task.runtime_definition do |task|
            task.command = cmd("scp") do |scp|
              scp.options << signing_cert.abspath
              scp.options << "#{remote_server.address}:#{certificate_file.abspath}"
            end
          end
        end

        Mattock::Rake::CommandTask.define_task(:copy_key => [:collect, :create_dirs]) do |task|
          task.runtime_definition do |task|
            task.command = cmd("scp") do |scp|
              scp.options << signing_key.abspath
              scp.options << "#{remote_server.address}:#{private_key.abspath}"
            end
          end
        end

        task :collect, [:target, :name] do |task, args|
          self.remote_server.address = args[:target]
          self.image_name = args[:name]
        end

        BakingCommand.define_task(:bake, [:target, :name] => [:collect, :copy_cert, :copy_key]) do |task|
          self.copy_settings_to(task)
          proxied = self.proxy_settings
          proxied.field_names = [:remote_server, :image_name, :bucket]
          proxied.to(task)
        end
      end
    end
  end
end
