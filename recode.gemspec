# -*- encoding: utf-8 -*-
require File.expand_path('../lib/recode/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ['Thibaut Barrère']
  gem.email         = ['thibaut.barrere@gmail.com']
  gem.description   = gem.summary = 'Renoise tracks generation using code'
  gem.homepage      = 'http://thbar.github.io/recode/'
  gem.license       = 'LGPL-3.0'
  gem.files         = `git ls-files | grep -Ev '^(examples)'`.split("\n")
  gem.test_files    = `git ls-files -- test/*`.split("\n")
  gem.name          = 'recode'
  gem.require_paths = ['lib']
  gem.version       = Recode::VERSION
  gem.executables   = []

  gem.add_dependency 'nokogiri', '~> 1.6'
  gem.add_development_dependency 'rake', '~> 10.4'
  gem.add_development_dependency 'minitest', '~> 5.6'
  gem.add_development_dependency 'awesome_print', '~> 1.6'
  gem.add_development_dependency 'guard'
  gem.add_development_dependency 'guard-minitest'
end
