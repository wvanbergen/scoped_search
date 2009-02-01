require 'rubygems'
require 'rake/rdoctask'

Dir['tasks/*.rake'].each { |file| load(file) }
 
desc 'Default: run unit tests.' 
task :default => [:test]

##############################################
# Build RDocs
##############################################
desc 'Generate documentation for the acts_as_callback_logger plugin.'
Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'doc/html'
  rdoc.title    = 'scoped_search'  
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.main = 'README'
  rdoc.rdoc_files.include('LICENSE',
                          'lib/')
end
##############################################


##############################################
# RCov Tasks
##############################################
begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |t|
    t.test_files = Dir[ "test/**/*_test.rb" ]
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
##############################################
