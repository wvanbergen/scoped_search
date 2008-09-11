require File.dirname(__FILE__) + '/test_helper'

class QueryLanguageTest < Test::Unit::TestCase

  # change this function if you switch to another query language parser
  def parse_query(query)
    ScopedSearch::QueryLanguageParser.parse(query)
  end
  
  def test_empty_search_query
    parsed = parse_query('')
    assert_equal 0, parsed.length    
    
    parsed = parse_query("\t  \n")
    assert_equal 0, parsed.length    
  end
  
  def test_single_keyword
    parsed = parse_query('hallo')
    assert_equal 1, parsed.length
    assert_equal 'hallo', parsed.first.first
  
    parsed = parse_query('  hallo  ')
    assert_equal 1, parsed.length
    assert_equal 'hallo', parsed.first.first
  end
   
  def test_multiple_keywords
    parsed = parse_query('  hallo  willem')
    assert_equal 2, parsed.length
    assert_equal 'willem', parsed.last.first
    
    parsed = parse_query("  hallo  willem   van\tbergen ")
    assert_equal 4, parsed.length    
    assert_equal 'hallo',  parsed[0].first
    assert_equal 'willem', parsed[1].first
    assert_equal 'van',    parsed[2].first
    assert_equal 'bergen', parsed[3].first      
  end
  
  def test_quoted_keywords
    parsed = parse_query('  "hallo"')    
    assert_equal 1, parsed.length
    assert_equal 'hallo', parsed.first.first
    
    parsed = parse_query('  "hallo   willem"')
    assert_equal 1, parsed.length
    assert_equal 'hallo willem', parsed.first.first
     
    parsed = parse_query('  "hallo   willem')
    assert_equal 2, parsed.length
    assert_equal 'hallo',  parsed[0].first
    assert_equal 'willem', parsed[1].first

    parsed = parse_query('  "hallo   wi"llem"')
    assert_equal 2, parsed.length
    assert_equal 'hallo wi', parsed[0].first
    assert_equal 'llem',       parsed[1].first
  end
  
  def test_quote_escaping
    parsed = parse_query('  "hallo   wi\\"llem"')
    assert_equal 3, parsed.length  
    assert_equal 'hallo', parsed[0].first
    assert_equal 'wi',    parsed[1].first
    assert_equal 'llem',  parsed[2].first
  
    parsed = parse_query('"\\"hallo willem\\""')
    assert_equal 2, parsed.length
    assert_equal 'hallo',  parsed[0].first
    assert_equal 'willem', parsed[1].first
  end
  
  def test_negation
    parsed = parse_query('-willem')
    assert_equal 1, parsed.length
    assert_equal 'willem', parsed[0].first
    assert_equal :not,     parsed[0].last
  
    parsed = parse_query('123 -"456 789"')
    assert_equal 2, parsed.length
    assert_equal '123', parsed[0].first
    assert_equal :like, parsed[0].last    
    
    assert_equal '456 789', parsed[1].first
    assert_equal :not,      parsed[1].last
  end
end