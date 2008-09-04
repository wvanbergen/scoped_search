require File.dirname(__FILE__) + '/test_helper'

class String
  include ScopedSearch::QueryStringParser
end

class QueryStringParserTest < Test::Unit::TestCase

  def test_empty_search_query
    parsed = ''.lex_for_query_string_parsing
    assert_equal 0, parsed.length    
    
    parsed = "\t  \n".lex_for_query_string_parsing
    assert_equal 0, parsed.length    
  end
  
  def test_single_keyword
    
    parsed = 'hallo'.lex_for_query_string_parsing
    assert_equal 1, parsed.length
    assert_equal 'hallo', parsed.first

    parsed = '  hallo  '.lex_for_query_string_parsing
    assert_equal 1, parsed.length
    assert_equal 'hallo', parsed.first
  end
   
  def test_multiple_keywords
    parsed = '  hallo   willem'.lex_for_query_string_parsing
    assert_equal 2, parsed.length
    assert_equal 'willem', parsed.last
  end
  
  def test_quoted_keywords
    parsed = '  "hallo"'.lex_for_query_string_parsing
    assert_equal 1, parsed.length
    assert_equal 'hallo', parsed.first
    
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
  end
  
  def test_quote_escaping
    parsed = '  "hallo   wi\\"llem"'.lex_for_query_string_parsing
    assert_equal 1, parsed.length
    assert_equal 'hallo   wi"llem', parsed.first
  
    parsed = '"\\"hallo willem\\""'.lex_for_query_string_parsing
    assert_equal 1, parsed.length
    assert_equal '"hallo willem"', parsed.first
  end
  
  def test_negation
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