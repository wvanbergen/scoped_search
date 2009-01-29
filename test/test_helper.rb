$:.reject! { |e| e.include? 'TextMate' }

require 'test/unit'
require 'rubygems'
require 'active_record'
require 'ruby-debug'

require "#{File.dirname(__FILE__)}/../lib/scoped_search"

module ScopedSearch::Test
  
  def self.establish_connection
    if ENV['DATABASE']
      ScopedSearch::Test.establish_named_connection(ENV['DATABASE'])
    else
      ScopedSearch::Test.establish_default_connection
    end  
  end
  
  def self.establish_named_connection(name)
    @database_connections ||= YAML.load(File.read("#{File.dirname(__FILE__)}/database.yml"))
    raise "#{name} database not configured" if @database_connections[name.to_s].nil?
    ActiveRecord::Base.establish_connection(@database_connections[name.to_s])
  end
  
  def self.establish_default_connection
    ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')
  end
  
  def self.create_corpus!
    ScopedSearch::Test::Models::Foo.create_corpus!
    ScopedSearch::Test::Models::Location.create_corpus!
    ScopedSearch::Test::Models::User.create_corpus!        
    ScopedSearch::Test::Models::Note.create_corpus!
    ScopedSearch::Test::Models::Group.create_corpus!    
    ScopedSearch::Test::Models::Office.create_corpus!    
    ScopedSearch::Test::Models::Client.create_corpus!    
    ScopedSearch::Test::Models::Address.create_corpus!        
  end  
end

# Load helpers
require "#{File.dirname(__FILE__)}/lib/test_schema"
require "#{File.dirname(__FILE__)}/lib/test_models"
