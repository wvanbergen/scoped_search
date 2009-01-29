Dir['tasks/*.rake'].each { |file| load(file) }
 
task :default => [:test]

namespace :test do
  
  desc "Run tests for all configured databases in test/database.yml"
  task :all do
    
    databases = YAML.load(File.read(File.dirname(__FILE__) + '/test/database.yml'))
    databases.each do |database, config|
      puts "\nRunning testsuite on #{database} database...\n\n"
      sh "rake test DATABASE=#{database}"
    end
    puts "\nFinished testing for all configured databases!"
    puts "(Configure databases by adjusting test/database.yml)"
  end
  
  task :single do
    database = ENV['DATABASE'] || 'sqlite3'
    puts "Running testsuite on #{database} database...\n"
    sh "rake test DATABASE=#{database}"
  end
  
  desc "Run tests on SQLite3 database"
  task :sqlite3 do
    puts "Running testsuite on SQLite3 database...\n"
    sh 'rake test DATABASE=sqlite3'
  end

  desc "Run tests on MySQL database"  
  task :mysql do
    puts "Running testsuite on MySQL database...\n"
    sh 'rake test DATABASE=mysql'    
  end
  
  desc "Run tests on PostgrSQL database"
  task :postgresql do
    puts "Running testsuite on PostgreSQL database...\n"
    sh 'rake test DATABASE=postgresql'    
  end

end