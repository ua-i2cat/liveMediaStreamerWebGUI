# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rmixer/version'

Gem::Specification.new do |spec|
  spec.name          = "rmixer"
  spec.version       = Rmixer::VERSION
  spec.authors       = ["i2CAT Foundation"]
  spec.email         = ["ignacio.contreras@i2cat.net"]
  spec.description   = %q{Mixer remote API Ruby implementation}
  spec.summary       = %q{Mixer remote API}
  spec.homepage      = ""

  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "yard"
end
