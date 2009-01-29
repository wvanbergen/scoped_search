Gem::Specification.new do |s|
  s.name    = 'scoped_search'
  s.version = '1.0.1'
  s.date    = '2009-01-29'
  
  s.summary = "A Rails plugin to search your models using a named_scope"
  s.description = "Scoped search makes it easy to search your ActiveRecord-based models. It will create a named scope according to a provided query string. The named_scope can be used like any other named_scope, so it can be cchained or combined with will_paginate."
  
  s.authors  = ['Willem van Bergen', 'Wes Hays']
  s.email    = ['willem@vanbergen.org', 'weshays@gbdev.com']
  s.homepage = 'http://wiki.github.com/wvanbergen/scoped_search'
  
  s.has_rdoc = true
  s.rdoc_options << '--title' << s.name << '--main' << 'README.rdoc' << '--line-numbers' << '--inline-source'
  s.extra_rdoc_files = ['README.rdoc']
  
  s.files = %w(LICENSE README.rdoc Rakefile init.rb lib lib/scoped_search lib/scoped_search.rb lib/scoped_search/query_conditions_builder.rb lib/scoped_search/query_language_parser.rb lib/scoped_search/reg_tokens.rb tasks tasks/github-gem.rake test test/database.yml test/integration test/integration/api_test.rb test/lib test/lib/test_models.rb test/lib/test_schema.rb test/test_helper.rb test/unit test/unit/query_conditions_builder_test.rb test/unit/query_language_test.rb test/unit/search_for_test.rb)
  s.test_files = %w(test/integration/api_test.rb test/unit/query_conditions_builder_test.rb test/unit/query_language_test.rb test/unit/search_for_test.rb)
end