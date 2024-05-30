# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'brew/gem/version'

Gem::Specification.new do |spec|
  spec.name          = "brew-gem"
  spec.version       = Brew::Gem::VERSION
  spec.authors       = ["Nick Sieger"]
  spec.email         = ["nick@nicksieger.com"]

  spec.summary       = %q{Generate Homebrew formulas to install standalone ruby gems.}
  spec.description   = %q{This gem can be installed with "brew install brew-gem" and used to install gems with "brew gem install <gem>".}
  spec.homepage      = "https://github.com/sportngin/brew-gem"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake", "~> 13.2"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "aruba", "~> 0.14.0"
end
