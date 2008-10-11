require 'rake/testtask'
 
desc 'Test the scoped_search plugin.'
Rake::TestTask.new(:test) do |t|
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
  t.libs << 'test'
  
  # options are sqlite3, mysql or postgresql.  The default
  # is sqlite3 if not specified or if the parameter is invalid.
  # If DATABASE is mysql then the MYSQLSOCKET can also be set if needed.
  ENV['DATABASE'] = ENV['DATABASE'].nil? ? 'sqlite3' : ENV['DATABASE'].downcase
end