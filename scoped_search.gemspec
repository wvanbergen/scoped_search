Gem::Specification.new do |s|
  s.name    = 'scoped_search'
  s.version = '0.1.0'
  s.date    = '2008-09-03'
  
  s.summary = "A Rails plugin to search your models using a named_scope"
  s.description = "Scoped search makes it easy to search your ActiveRecord-based models. It will create a named scope according to a provided query string. The named_scope can be used like any other named_scope, so it can be cchained or combined with will_paginate."
  
  s.authors  = ['Willem van Bergen']
  s.email    = 'willem@vanbergen.org'
  s.homepage = 'http://github.com/wvanbergen/scoped_search/wikis'
  
  s.files = %w(LICENSE README Rakefile TODO init.rb lib lib/scoped_search lib/scoped_search.rb lib/scoped_search/query_string_parser.rb test test/query_building_test.rb test/query_string_parser_test.rb test/tasks.rake test/test_helper.rb)
  s.test_files = %w(test/query_building_test.rb test/query_string_parser_test.rb)
end