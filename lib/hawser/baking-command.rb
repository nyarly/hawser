require 'mattock'

module Hawser
  class BakingCommand < Mattock::Rake::RemoteCommandTask
    setting :arch, "x86_64"
    setting :ec2_version_pattern, "1.4.0.5 20071010"

    setting :absolute_path, "/"

    setting :region, "us-west-1"

    dir(:ephemeral_dir, "mnt",
        dir(:keyfile_dir, "keys",
            path(:private_key, "pk.pem"),
            path(:certificate_file, "cert.pem")))

    runtime_setting :image_name
    runtime_setting :prefix

    runtime_setting :bucket
    runtime_setting :access_key
    runtime_setting :secret_key
    runtime_setting :aws_account_id

    runtime_setting :manifest_name
    runtime_setting :manifest_path

    def resolve_configuration
      super

      resolve_paths
    end

    def resolve_runtime_configuration
      if field_unset?(:prefix)
        self.prefix = image_name
      end

      if field_unset?(:manifest_name)
        self.manifest_name = "#{prefix}.manifest.xml"
      end

      if field_unset?(:manifest_path)
        self.manifest_path = File::join(ephemeral_dir.abspath, manifest_name)
      end

      super
    end

    def command
      cmd("(ec2-bundle-vol --version | grep \"#{ec2_version_pattern}\")") &
        (cmd("rm") {|rm|
        rm.options = ["-f", File::join(ephemeral_dir.abspath, prefix || "no-such-file") ]
      }) &
        (cmd("ec2-bundle-vol") { |bundle|
        bundle.options += ["-k", private_key.abspath ]
        bundle.options += ["-c", certificate_file.abspath ]
        bundle.options += ["--user", aws_account_id ]

        bundle.options += ["--destination", ephemeral_dir.abspath ]
        bundle.options += ["--prefix", prefix ]
        bundle.options += ["--arch", arch ]
        bundle.options += %w{-i /etc/ec2/amitools/cert-ec2.pem}
        bundle.options += ["-i", '$(ls /etc/ssl/certs/*.pem | tr \\\\n ,)']
        bundle.options += %w{--ec2cert /etc/ec2/amitools/cert-ec2.pem}
        bundle.options += ["-e", keyfile_dir.abspath]
      }) &
        (cmd("ec2-upload-bundle") {|upload|
        upload.options += ["-b", bucket ]
        upload.options += ["-m", manifest_path]
        upload.options += ["-a", access_key ]
        upload.options += ["-s", secret_key ]
        upload.options += ["--location", region ]
        upload.options += ["--retry"]
      }) &
        (cmd("ec2-register") {|register|
        register.options << "#{bucket}/#{manifest_name}"
        register.options += ["-n", image_name]
        register.options += ["--region", region]
        register.options += ["--aws-access-key", access_key]
        register.options += ["--aws-secret-key", secret_key]
      })
    end
  end
end
