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

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |t|
    t.test_files = Dir[ "test/*_test.rb" ]
  end
rescue LoadError
  nil
end

begin
  require 'rcov/rcovtask'
  desc 'Runs spec:rcov and then displays the coverage/index.html file in the browswer.' 
  task :rcov_display => [:clobber_rcov, :rcov] do 
    system("open coverage/index.html")
  end
rescue LoadError
  nil
end



# namespace :test do
#   desc "Generate code coverage with rcov"
#   task :coverage do
#     rm_f "doc/coverage/coverage.data"
#     rm_f "doc/coverage"
#     mkdir "doc/coverage"
#     rcov = %(rcov --rails --aggregate doc/coverage/coverage.data --text-summary -Ilib --html -o doc/coverage test/**/*_test.rb)
#     system rcov
#     system "open doc/coverage/index.html" if PLATFORM['darwin']
#   end
# end
