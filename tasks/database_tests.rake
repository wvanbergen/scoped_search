require 'yaml' unless Object::const_defined?('YAML')

namespace :test do
  
  databases = YAML.load(File.read(File.dirname(__FILE__) + '/../test/database.yml'))  
  
  desc "Run tests for all configured databases in test/database.yml"
  task(:all => databases.keys.map { |db| db.to_sym }) do
    puts "\nFinished testing for all configured databases!"
    puts "(Configure databases by adjusting test/database.yml)"
  end
  
  databases.each do |database, config|
    desc "Run testsuite on #{database} database."
    task database.to_sym do
      puts "Running testsuite on #{database} database...\n\n"
      sh "rake test DATABASE=#{database}"
    end
  end  
end