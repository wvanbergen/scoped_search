Gem::Specification.new do |s|
  s.name    = 'scoped_search'
  s.version = '2.0.0'
  s.date    = '2009-08-26'
  
  s.summary = "A Rails plugin to search your models using a named_scope"
  s.description = "Scoped search makes it easy to search your ActiveRecord-based models. It will create a named scope according to a provided query string. The named_scope can be used like any other named_scope, so it can be cchained or combined with will_paginate."
  
  s.authors  = ['Willem van Bergen', 'Wes Hays']
  s.email    = ['willem@vanbergen.org', 'weshays@gbdev.com']
  s.homepage = 'http://wiki.github.com/wvanbergen/scoped_search'
  
  s.has_rdoc = true
  s.rdoc_options << '--title' << s.name << '--main' << 'README.rdoc' << '--line-numbers' << '--inline-source'
  s.extra_rdoc_files = ['README.rdoc']
  
  s.files = %w(LICENSE README.rdoc Rakefile init.rb lib lib/scoped_search lib/scoped_search.rb lib/scoped_search/adapters.rb lib/scoped_search/definition.rb lib/scoped_search/query_builder.rb lib/scoped_search/query_language lib/scoped_search/query_language.rb lib/scoped_search/query_language/ast.rb lib/scoped_search/query_language/parser.rb lib/scoped_search/query_language/tokenizer.rb spec spec/database.yml spec/integration spec/integration/api_spec.rb spec/integration/ordinal_querying_spec.rb spec/integration/relation_querying_spec.rb spec/integration/string_querying_spec.rb spec/lib spec/lib/database.rb spec/lib/matchers.rb spec/lib/mocks.rb spec/spec_helper.rb spec/unit spec/unit/ast_spec.rb spec/unit/definition_spec.rb spec/unit/parser_spec.rb spec/unit/query_builder_spec.rb spec/unit/tokenizer_spec.rb tasks tasks/database_tests.rake tasks/github-gem.rake)
  s.test_files = %w(spec/integration/api_spec.rb spec/integration/ordinal_querying_spec.rb spec/integration/relation_querying_spec.rb spec/integration/string_querying_spec.rb spec/unit/ast_spec.rb spec/unit/definition_spec.rb spec/unit/parser_spec.rb spec/unit/query_builder_spec.rb spec/unit/tokenizer_spec.rb)
end