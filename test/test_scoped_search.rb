
ENV['RAILS_ENV'] = 'test'
ENV['RAILS_ROOT'] ||= File.dirname(__FILE__) + '/../../../..'

require 'test/unit'
require File.expand_path(File.join(ENV['RAILS_ROOT'], 'config/environment.rb'))

require 'active_record'
require 'action_controller/test_process'

require "#{File.dirname(__FILE__)}/../init"


ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :dbfile => ":memory:")

def setup_db
  ActiveRecord::Schema.define(:version => 1) do
    create_table :search_tests do |t|
      t.string :string_field
      t.text :text_field
      t.string :ignored_field
      t.timestamps
    end
  end
end


def teardown_db
  ActiveRecord::Base.connection.tables.each do |table|
    ActiveRecord::Base.connection.drop_table(table)
  end
end

class String
  include ActiveRecord::ScopedSearch::QueryStringParser
end

class SearchTest < ActiveRecord::Base
  searchable_on :string_field, :text_field
end


class ScopedSearchTest < Test::Unit::TestCase

  def setup
    setup_db
    SearchTest.create!(:string_field => "123", :text_field => "Hallo",     :ignored_field => "123 willem")
    SearchTest.create!(:string_field => "456", :text_field => "Hallo 123", :ignored_field => "123")
    SearchTest.create!(:string_field => "789", :text_field => "HALLO",     :ignored_field => "123456");
  end

  def teardown
    teardown_db
  end
  
  def test_search
    assert_equal 2, SearchTest.search_for('123').count
    assert_equal 3, SearchTest.search_for('haLL').count
    assert_equal 1, SearchTest.search_for('456').count    
    assert_equal 2, SearchTest.search_for('ha 23').count        
    assert_equal 0, SearchTest.search_for('wi').count 
    
    assert_equal 0, SearchTest.search_for('-hallo').count
    assert_equal 3, SearchTest.search_for('-wi').count
    assert_equal 1, SearchTest.search_for('123 -456').count    
  end

end

class QueryStringParserTest < Test::Unit::TestCase

  def test_query_string_lexer
    parsed = ''.lex_for_query_string_parsing
    assert_equal 0, parsed.length

    parsed = "\t  \n".lex_for_query_string_parsing
    assert_equal 0, parsed.length
    
    parsed = 'hallo'.lex_for_query_string_parsing
    assert_equal 1, parsed.length
    assert_equal 'hallo', parsed.first

    parsed = '  hallo  '.lex_for_query_string_parsing
    assert_equal 1, parsed.length
    assert_equal 'hallo', parsed.first    
    
    parsed = '  "hallo"'.lex_for_query_string_parsing
    assert_equal 1, parsed.length
    assert_equal 'hallo', parsed.first  
    
    parsed = '  hallo   willem'.lex_for_query_string_parsing
    assert_equal 2, parsed.length
    assert_equal 'willem', parsed.last
    
    parsed = '  "hallo   willem"'.lex_for_query_string_parsing
    assert_equal 1, parsed.length
    assert_equal 'hallo   willem', parsed.first
    
    parsed = '  "hallo   willem'.lex_for_query_string_parsing
    assert_equal 1, parsed.length
    assert_equal 'hallo   willem', parsed.first
    
    parsed = '  "hallo   wi"llem"'.lex_for_query_string_parsing
    assert_equal 2, parsed.length
    assert_equal 'hallo   wi', parsed.first
    assert_equal 'llem', parsed.last

    parsed = '  "hallo   wi\\"llem"'.lex_for_query_string_parsing
    assert_equal 1, parsed.length
    assert_equal 'hallo   wi"llem', parsed.first
  
    parsed = '"\\"hallo willem\\""'.lex_for_query_string_parsing
    assert_equal 1, parsed.length
    assert_equal '"hallo willem"', parsed.first
    
    parsed = '-willem'.lex_for_query_string_parsing
    assert_equal 2, parsed.length
    assert_equal :not, parsed.first

    parsed = '123 -"456 789"'.lex_for_query_string_parsing
    assert_equal 3, parsed.length
    assert_equal '123', parsed[0] 
    assert_equal :not, parsed[1] 
    assert_equal '456 789', parsed[2] 
  end
end
