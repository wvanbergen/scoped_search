require 'rubygems'
require 'rake/rdoctask'

Dir['tasks/*.rake'].each { |file| load(file) }
 
desc 'Default: run unit tests.'
task :default => :test

##############################################
# Build RDocs
##############################################
desc 'Generate documentation for the acts_as_callback_logger plugin.'
Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'doc/html'
  rdoc.title    = 'scoped_search'  
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.main = 'README'
  rdoc.rdoc_files.include('README',
                          'CHANGELOG',
                          'LICENSE',
                          'TODO',
                          'lib/')
end
##############################################