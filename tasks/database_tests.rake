require 'yaml' unless Object::const_defined?('YAML')

namespace :spec do

  databases = YAML.load(File.read(File.dirname(__FILE__) + '/../spec/database.yml'))

  desc "Run testsuite on all configured databases in spec/database.yml"
  task(:all => databases.keys.map { |db| db.to_sym }) do
    puts "\nFinished testing on all configured databases!"
    puts "(Configure databases by adjusting test/database.yml)"
  end

  databases.each do |database, config|
    desc "Run testsuite on #{database} database."
    task database.to_sym do
      puts "Running specs for #{database} database...\n\n"
      sh "rake spec DATABASE=#{database}"
    end
  end
end