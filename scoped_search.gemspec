Gem::Specification.new do |s|
  s.name    = 'scoped_search'
  
  # Do not change the version and date fields by hand. This will be done
  # automatically by the gem release script.
  s.version = "2.2.0"
  s.date    = "2010-05-26"

  s.summary = "Easily search you ActiveRecord models with a simple query language using a named scope."
  s.description = <<-EOS
    Scoped search makes it easy to search your ActiveRecord-based models.
    
    It will create a named scope :search_for that can be called with a query string. It will build an SQL query using
    the provided query string and a definition that specifies on what fields to search. Because the functionality is
    built on named_scope, the result of the search_for call can be used like any other named_scope, so it can be
    chained with another scope or combined with will_paginate.
    
    Because it uses standard SQL, it does not require any setup, indexers or daemons. This makes scoped_search
    suitable to quickly add basic search functionality to your application with little hassle. On the other hand,
    it may not be the best choice if it is going to be used on very large datasets or by a large user base.
  EOS

  s.authors  = ['Willem van Bergen', 'Wes Hays']
  s.email    = ['willem@railsdoctors.com', 'weshays@gbdev.com']
  s.homepage = 'http://wiki.github.com/wvanbergen/scoped_search'

  s.add_runtime_dependency('activerecord', '>= 2.1.0')
  s.add_development_dependency('rspec', '>= 1.1.4')

  s.rdoc_options << '--title' << s.name << '--main' << 'README.rdoc' << '--line-numbers' << '--inline-source'
  s.extra_rdoc_files = ['README.rdoc']

  # Do not change the files and test_files fields by hand. This will be done
  # automatically by the gem release script.
  s.files      = %w(spec/spec_helper.rb spec/integration/string_querying_spec.rb lib/scoped_search/definition.rb spec/lib/mocks.rb scoped_search.gemspec lib/scoped_search/query_language/parser.rb spec/lib/matchers.rb .gitignore LICENSE spec/unit/ast_spec.rb spec/database.yml init.rb Rakefile spec/unit/tokenizer_spec.rb spec/unit/parser_spec.rb spec/integration/api_spec.rb lib/scoped_search/query_language/ast.rb lib/scoped_search/query_language.rb lib/scoped_search/query_builder.rb README.rdoc spec/unit/definition_spec.rb spec/lib/database.rb spec/integration/profile_querying_spec.rb tasks/github-gem.rake spec/unit/query_builder_spec.rb lib/scoped_search.rb spec/integration/relation_querying_spec.rb spec/integration/ordinal_querying_spec.rb lib/scoped_search/query_language/tokenizer.rb)
  s.test_files = %w(spec/integration/string_querying_spec.rb spec/unit/ast_spec.rb spec/unit/tokenizer_spec.rb spec/unit/parser_spec.rb spec/integration/api_spec.rb spec/unit/definition_spec.rb spec/integration/profile_querying_spec.rb spec/unit/query_builder_spec.rb spec/integration/relation_querying_spec.rb spec/integration/ordinal_querying_spec.rb)
end