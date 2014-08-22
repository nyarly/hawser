require 'mattock'
require 'hawser/credentialing'
require 'hawser/baking'
require 'hawser/servers'

module Hawser
  # Represents a cluster of servers on AWS
  #
  # @example in Rakefile
  # Hawser::Cluster.new do |bollard|
  #   bollard.name = "bollard"
  #   bollard.user = "ahab"
  # end
  #
  # @example at console
  # > rake bollard:servers:list
  # > rake bollard:bake[app1.bollard.com,app1-number1]
  #
  class Cluster < Mattock::Tasklib
    setting :name
    setting :user
    setting :bucket

    def resolve_configuration
      @namespace_name ||= name.downcase
      self.bucket ||= "#{name.downcase}-amis"
      super
    end

    def define
      in_namespace do
        creds = Hawser::Credentialing.new do |creds|
          copy_settings_to(creds)
          creds.cluster_name = name
        end

        Hawser::Baking.new do |bake|
          copy_settings_to(bake)
          creds.copy_settings_to(bake)
          creds.credentials.proxy_settings_to(bake)
        end

        Hawser::Servers.new do |servers|
          copy_settings_to(servers)
          servers.cluster_name = name
          creds.copy_settings_to(servers)
          creds.credentials.proxy_settings_to(servers)
        end

        namespace :baking do
          task :bake => "credentials:establish"
        end

        namespace :servers do
          task :list => "credentials:establish"
        end

        desc "Make an AMI copy of the running instance at :target named :name"
        task :bake, [:target, :name] => "baking:bake"
      end
    end
  end
end
