# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'scoped_search/version'

Gem::Specification.new do |gem|
  gem.name          = "scoped_search"
  gem.version       = ScopedSearch::VERSION
  gem.authors       = ['Amos Benari', 'Willem van Bergen', 'Wes Hays']
  gem.email         = ['abenari@redhat.com', 'willem@railsdoctors.com', 'weshays@gbdev.com']
  gem.homepage      = "https://github.com/wvanbergen/scoped_search/wiki"
  gem.summary       = %q{Easily search you ActiveRecord models with a simple query language using a named scope}
  gem.description   = <<-EOS
    Scoped search makes it easy to search your ActiveRecord-based models.

    It will create a named scope :search_for that can be called with a query string. It will build an SQL query using
    the provided query string and a definition that specifies on what fields to search. Because the functionality is
    built on named_scope, the result of the search_for call can be used like any other named_scope, so it can be
    chained with another scope or combined with will_paginate.

    Because it uses standard SQL, it does not require any setup, indexers or daemons. This makes scoped_search
    suitable to quickly add basic search functionality to your application with little hassle. On the other hand,
    it may not be the best choice if it is going to be used on very large datasets or by a large user base.
  EOS

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.required_ruby_version = '>= 1.9.3'
  gem.add_runtime_dependency('activerecord', '>= 3.0.0')
  gem.add_development_dependency('rspec', '~> 3.0')
  gem.add_development_dependency('rake')

  gem.rdoc_options << '--title' << gem.name << '--main' << 'README.rdoc' << '--line-numbers' << '--inline-source'
  gem.extra_rdoc_files = ['README.rdoc']
end
