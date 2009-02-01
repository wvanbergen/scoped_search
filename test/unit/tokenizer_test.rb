require File.dirname(__FILE__) + '/../test_helper'
require 'scoped_search/query_language'

class ScopedSearch::Test::Tokenizer < Test::Unit::TestCase
  
  def test_simple_words
    tokens = ScopedSearch::QueryLanguage::Compiler.tokenize('some simple keywords')
    assert_equal ['some', 'simple', 'keywords'], tokens
  end
  
  def test_whitespace_handling
    tokens = ScopedSearch::QueryLanguage::Compiler.tokenize("  with\twhitespace   \n")
    assert_equal ['with', 'whitespace'], tokens
  end
  
  def test_quoted_strings
    tokens = ScopedSearch::QueryLanguage::Compiler.tokenize('"quoted string"')
    assert_equal ['quoted string'], tokens
  end  
  
  def test_quoted_strings_with_escaping
    tokens = ScopedSearch::QueryLanguage::Compiler.tokenize('"quoted \"string"')
    assert_equal ['quoted "string'], tokens
  end  
  
  def test_quoted_strings_with_escaped_backslash
    tokens = ScopedSearch::QueryLanguage::Compiler.tokenize('"quoted \\\\string"')
    assert_equal ['quoted \\string'], tokens
  end  
  
  def test_unclosed_quoted_strings
    tokens = ScopedSearch::QueryLanguage::Compiler.tokenize('"quoted string')
    assert_equal ['quoted string'], tokens
  end  
  
  def test_multiple_quoted_strings
    tokens = ScopedSearch::QueryLanguage::Compiler.tokenize('"quoted string"   "another"  ')
    assert_equal ['quoted string', 'another'], tokens
  end  
  
  def test_multiple_quoted_strings_without_whitespace
    tokens = ScopedSearch::QueryLanguage::Compiler.tokenize('"quoted string""another"')
    assert_equal ['quoted string', 'another'], tokens
  end  
  
  def test_multiple_quoted_string_and_unquoted_string
    tokens = ScopedSearch::QueryLanguage::Compiler.tokenize('"quoted string" another')
    assert_equal ['quoted string', 'another'], tokens
  end  
  
  def test_multiple_quoted_string_and_unquoted_without_whitespace
    tokens = ScopedSearch::QueryLanguage::Compiler.tokenize('"quoted string" another')
    assert_equal ['quoted string', 'another'], tokens
  end  
  
  def test_simple_keyword_characters
    tokens = ScopedSearch::QueryLanguage::Compiler.tokenize('great | -("cruel""world") & goodbye')
    assert_equal ['great', :or, :not, :lparen, 'cruel', 'world', :rparen, :and, 'goodbye'], tokens
  end

  def test_double_and_operator
    tokens = ScopedSearch::QueryLanguage::Compiler.tokenize('hello && goodbye')
    assert_equal ['hello', :and, 'goodbye'], tokens    
  end
  
  def test_double_and_operator_with_whitespace
    tokens = ScopedSearch::QueryLanguage::Compiler.tokenize('hello & & goodbye')
    assert_equal ['hello', :and, :and, 'goodbye'], tokens    
  end  
  
  def test_keyword_strings
    tokens = ScopedSearch::QueryLanguage::Compiler.tokenize('hello and goodbye')
    assert_equal ['hello', :and, 'goodbye'], tokens
  end  
  
  def test_keyword_strings_with_mixed_case
    tokens = ScopedSearch::QueryLanguage::Compiler.tokenize('hello AnD goodbye')
    assert_equal ['hello', :and, 'goodbye'], tokens
  end  
  
  def test_quoted_keywords
    tokens = ScopedSearch::QueryLanguage::Compiler.tokenize('hello "and" goodbye')
    assert_equal ['hello', 'and', 'goodbye'], tokens
  end  
  
  
  def test_negation_operator_in_string
    tokens = ScopedSearch::QueryLanguage::Compiler.tokenize('world-greater')
    assert_equal ['world-greater'], tokens
  end  
  
  def test_and_operator_in_string
    tokens = ScopedSearch::QueryLanguage::Compiler.tokenize('world&greater')
    assert_equal ['world', :and, 'greater'], tokens
  end
  
  def test_or_operator_in_string
    tokens = ScopedSearch::QueryLanguage::Compiler.tokenize('world|greater')
    assert_equal ['world', :or, 'greater'], tokens
  end  
  
  def test_equals_operator
    tokens = ScopedSearch::QueryLanguage::Compiler.tokenize('world=greater')
    assert_equal ['world', :eq, 'greater'], tokens
  end  
end
