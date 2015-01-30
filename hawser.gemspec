Gem::Specification.new do |spec|
  spec.name		= "hawser"
  spec.version		= "0.1.1"
  author_list = {
    "Judson Lester" => 'nyarly@gmail.com'
  }
  spec.authors		= author_list.keys
  spec.email		= spec.authors.map {|name| author_list[name]}
  spec.summary		= "AWS tools for towing your servers around"
  spec.description	= <<-EndDescription
  A toolbelt of utilities for doing stuff with AWS
  EndDescription

  spec.rubyforge_project= spec.name.downcase
  spec.homepage        = "http://nyarly.github.com/#{spec.name.downcase}"
  spec.required_rubygems_version = Gem::Requirement.new(">= 0") if spec.respond_to? :required_rubygems_version=

  # Do this: y$@"
  # !!find lib bin doc spec spec_help -not -regex '.*\.sw.' -type f 2>/dev/null
  spec.files		= %w[
    lib/hawser.rb
    lib/hawser/cluster.rb
    lib/hawser/credentialing.rb
    lib/hawser/servers.rb
    lib/hawser/baking-command.rb
    lib/hawser/baking.rb
    spec/hawser_spec.rb
    spec_help/gem_test_suite.rb
  ]

  spec.test_file        = "spec_help/gem_test_suite.rb"
  spec.licenses = ["MIT"]
  spec.require_paths = %w[lib/]
  spec.rubygems_version = "1.3.5"

  spec.has_rdoc		= true
  spec.extra_rdoc_files = Dir.glob("doc/**/*")
  spec.rdoc_options	= %w{--inline-source }
  spec.rdoc_options	+= %w{--main doc/README }
  spec.rdoc_options	+= ["--title", "#{spec.name}-#{spec.version} Documentation"]

  spec.add_dependency("aws-sdk", "< 2.0")
  spec.add_dependency("mattock", "> 0")

  #spec.post_install_message = "Thanks for installing my gem!"
end
