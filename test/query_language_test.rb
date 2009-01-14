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

    parsed = parse_query('hallo-world')
    assert_equal 1, parsed.length
    assert_equal 'hallo-world', parsed.first.first

    parsed = parse_query('hallo -world')
    assert_equal 2, parsed.length
    assert_equal 'hallo', parsed.first.first
    assert_equal 'world', parsed.last.first
    assert_equal :not,     parsed.last.last

    parsed = parse_query('123 -"456 789"')
    assert_equal 2, parsed.length
    assert_equal '123', parsed[0].first
    assert_equal :like, parsed[0].last    
    
    assert_equal '456 789', parsed[1].first
    assert_equal :not,      parsed[1].last
  end
  
  def test_or
    parsed = parse_query('Wes OR Hays')
    assert_equal 1, parsed.length
    assert_equal 'Wes OR Hays', parsed[0][0]
    assert_equal :or, parsed[0][1]
    
    parsed = parse_query('"Man made" OR Dogs')
    assert_equal 1, parsed.length
    assert_equal 'Man made OR Dogs', parsed[0][0]
    assert_equal :or, parsed[0][1]    
    
    parsed = parse_query('Cows OR "Frog Toys"')
    assert_equal 1, parsed.length
    assert_equal 'Cows OR Frog Toys', parsed[0][0]
    assert_equal :or, parsed[0][1]
    
    parsed = parse_query('"Happy cow" OR "Sad Frog"')
    assert_equal 1, parsed.length
    assert_equal 'Happy cow OR Sad Frog', parsed[0][0]
    assert_equal :or, parsed[0][1]        
  end 
  
  def test_long_string
    str = 'Wes -Hays "Hello World" -"Goodnight Moon" Bob OR Wes "Happy cow" OR "Sad Frog" "Man made" OR Dogs Cows OR "Frog Toys"'
    parsed = parse_query(str)
    assert_equal 8, parsed.length
    
    assert_equal 'Wes', parsed[0].first
    assert_equal :like,   parsed[0].last
    
    assert_equal 'Hays', parsed[1].first
    assert_equal :not,   parsed[1].last
    
    assert_equal 'Hello World', parsed[2].first
    assert_equal :like, parsed[2].last
    
    assert_equal 'Goodnight Moon', parsed[3].first
    assert_equal :not, parsed[3].last      
    
    assert_equal 'Bob OR Wes', parsed[4].first
    assert_equal :or,   parsed[4].last    
    
    assert_equal 'Happy cow OR Sad Frog', parsed[5].first
    assert_equal :or,   parsed[5].last
    
    assert_equal 'Man made OR Dogs', parsed[6].first
    assert_equal :or,   parsed[6].last
    
    assert_equal 'Cows OR Frog Toys', parsed[7].first
    assert_equal :or,   parsed[7].last                  
  end
end