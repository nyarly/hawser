require 'mattock'
require 'aws-sdk'

module Hawser
  class Credentialing < Mattock::TaskLib
    default_namespace :credentials

    setting :user
    setting :cluster_name

    setting :credentials, nested{
      nil_fields :access_key, :secret_key, :certificate_id, :password, :aws_account_id
      setting :mfa, true
    }

    setting :key_size, 4096

    setting :cert, nested{
      setting :lifetime, nested{
        setting :years, 1
        setting :days, 0
        setting :hours, 0
        setting :minutes, 0
        setting :seconds, 0
        setting :total_seconds
    }
    }

    setting :iam, nil
    setting :iam_user, nil

    dir(:creds_root, "credentials",
        dir(:cluster_dir,
            dir(:user_dir,
                path(:creds_csv, "creds.csv"),
                path(:config_yaml, "config.yaml"),
                path(:signing_cert, "cert.pem"),
                path(:signing_key, "key.pem"))))

    def resolve_configuration
      cluster_dir.relative_path = cluster_name
      user_dir.relative_path = user

      cert.lifetime.total_seconds =
        cert.lifetime.seconds + 60 * (
          cert.lifetime.minutes + 60 * (
            cert.lifetime.hours + 24 * (
              cert.lifetime.days + 365 * cert.lifetime.years)))

      super

      resolve_paths
    end

    def signing_key_content
      require 'openssl'
      if key_size <= 1024
        raise "Refusing to create an insecure RSA key"
      end

      #XXX Consider using a passphrase here - although #managment for baking
      #etc...
      key = OpenSSL::PKey::RSA.generate(key_size)

      key.to_pem
    end

    def signing_cert_content(key_string)
      require 'openssl'

      key = OpenSSL::PKey.read(key_string)

      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = 2
      cert.public_key = key.public_key
      cert.not_before = Time.now
      cert.not_after = cert.not_before + self.cert.lifetime.total_seconds

      File.open(task.name, "w") do |pem_file|
        pem_file.write(cert.to_pem)
      end
    end

    def load_from_yaml(string)
      require 'yaml'
      config = YAML::load(string)

      credentials.aws_account_id = config["aws_account_id"] if config.has_key? "aws_account_id"
      credentials.access_key = config["access_key"] if config.has_key? "access_key"
      credentials.secret_key = config["secret_key"] if config.has_key? "secret_key"
      credentials.password = config["password"] if config.has_key? "password"
      credentials.certificate_id = config["certificate_id"] if config.has_key? "certificate_id"
      credentials.mfa = config["mfa"] if config.has_key? "mfa"
    end

    def load_from_csv(string)
      require 'csv'

      rows = CSV.new(string).to_a

      rows.shift #headers
      row = rows.find do |name, key, secret|
        name =~ /^#{user}$/i
      end
      if row.nil?
        fail "Couldn't find Access credentials line for #{user.inspect} in #{rows.map{|name, _,_| name}.inspect}"
      end

      _, key, secret = *row

      credentials.access_key = key
      credentials.secret_key = secret
    end

    def find_cert_id(cert_body)
      remote_cert = iam_user.signing_certificates.find do |certificate|
        certificate.contents == cert_body
      end

      unless remote_cert.nil?
        credentials.certificate_id = remote_cert.id
      end
    end

    def define
      in_namespace do
        directory user_dir.abspath

        file signing_cert.abspath => signing_key.abspath do |task|
          key = File::read(signing_key.abspath)
          File.write(task.name, signing_cert_content(key))
        end

        file signing_key.abspath do |task|
          File.write(task.name, signing_key_content)
        end

        task :load do
          if File::exists?(config_yaml.abspath)
            load_from_yaml(File::read(config_yaml.abspath))
          end
        end

        task :store do
          require 'yaml'

          File::open(config_yaml.abspath, "w") do |config|
            config.write YAML.dump(Hash[credentials.to_hash.map do |key,value|
              [key.to_s, value]
            end])
          end
        end

        task :iam => "get:access" do
          self.iam = AWS::IAM.new(:access_key_id => credentials.access_key, :secret_access_key => credentials.secret_key)
        end

        task :iam_user => :iam do
          self.iam_user = iam.users[user]
        end

        namespace :get do
          task :access => :load do
            if credentials.access_key.nil? or not credentials.secret_key.nil?
              load_from_csv(File.read(creds_csv.abspath))
            end
          end

          task :aws_account_id => :iam do
            credentials.aws_account_id = iam.users.first.arn.split(":")[4]
          end

          task :certificate_id => [:iam_user, signing_cert.abspath] do
            if credentials.certificate_id.nil?
              find_cert_id(File::read(signing_cert.abspath))
            end
          end
        end
        task :get => %w{get:access get:certificate_id get:aws_account_id}

        namespace :set do
          task :password => :iam_user do
            unless credentials.password.nil?
              iam_user.login_policy.password = credentials.password
            end
          end

          task :certificate => [:iam_user, signing_cert.abspath, "get:certificate_id"] do
            if !credentials.certificate_id.nil?
              begin
                iam_user.signing_certificates[credentials.certificate_id].contents
                next
              rescue AWS::Core::Resource::NotFound
              end
            end

            cert = iam_user.signing_certificates.upload(File::read(signing_cert.abspath))
            credentials.certificate_id = cert.id
          end
        end

        desc "Set up credentials for #{user} on cluster_name #{cluster_name}"
        task :establish => %w{get set:certificate store}
      end
    end
  end
end
