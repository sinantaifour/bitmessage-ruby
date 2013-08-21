# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'bitmessage/version'

Gem::Specification.new do |gem|
  gem.name          = "bitmessage"
  gem.version       = Bitmessage::VERSION
  gem.authors       = ["staii"]
  gem.email         = ["staiii@gmail.com"]
  gem.description   = %q{A library for communicating over the bitmessage protocol}
  gem.summary       = %q{The bitmessage-ruby library is still under development}
  gem.homepage      = "https://github.com/staii/bitmessage-ruby"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  #gem.add_development_dependency("minitest", "~> 4.1.0")
  gem.add_runtime_dependency('eventmachine')

  gem.required_ruby_version = '>= 1.9.0'
end

