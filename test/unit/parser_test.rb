require File.dirname(__FILE__) + '/../test_helper'
require 'scoped_search/query_language'

class ScopedSearch::Test::Parser < Test::Unit::TestCase

  def test_default_sequence
    ast = ScopedSearch::QueryLanguage::Compiler.parse('some simple keywords')
    assert_equal [:and, 'some', 'simple', 'keywords'], ast.to_a
  end
  
  def test_or_sequence
    ast = ScopedSearch::QueryLanguage::Compiler.parse('some simple OR keywords')
    assert_equal [:and, 'some', [:or, 'simple', 'keywords']], ast.to_a
  end
  
  def test_or_sequence_simplification
    ast = ScopedSearch::QueryLanguage::Compiler.parse('some OR simple OR keywords')
    assert_equal [:or, 'some', 'simple', 'keywords'], ast.to_a
  end

  def test_parentheses
    ast = ScopedSearch::QueryLanguage::Compiler.parse('some OR (simple keywords)')
    assert_equal [:or, 'some', [:and, 'simple', 'keywords']], ast.to_a
   
    ast = ScopedSearch::QueryLanguage::Compiler.parse('(some OR simple) keywords)')
    assert_equal [:and, [:or, 'some', 'simple'], 'keywords'], ast.to_a
  end
  
  def test_not
    ast = ScopedSearch::QueryLanguage::Compiler.parse('(hard !simple)')
    assert_equal [:and, 'hard', [:not, 'simple']], ast.to_a    
  end
  
  def test_not_with_or
    ast = ScopedSearch::QueryLanguage::Compiler.parse('(hard |!simple)')
    assert_equal [:or, 'hard', [:not, 'simple']], ast.to_a    
  end  
  
  def test_not_with_parentheses
    ast = ScopedSearch::QueryLanguage::Compiler.parse('!(simple || !hard)')
    assert_equal [:not, [:or, 'simple', [:not, 'hard']]], ast.to_a    
  end  
  
  def test_or_parentheses
    ast = ScopedSearch::QueryLanguage::Compiler.parse('(a|b)(b|c)')
    assert_equal [:and, [:or, 'a', 'b'], [:or, 'b', 'c']], ast.to_a    
  end  
  
  def test_and_or_parentheses
    ast = ScopedSearch::QueryLanguage::Compiler.parse('(a|b) & (b|c)')
    assert_equal [:and, [:or, 'a', 'b'], [:or, 'b', 'c']], ast.to_a    
  end  
  
  def test_comma
    ast = ScopedSearch::QueryLanguage::Compiler.parse('a, b')
    assert_equal [:and, 'a', 'b'], ast.to_a    
  end  
  
  def test_infix_operator
    ast = ScopedSearch::QueryLanguage::Compiler.parse('a > b')
    assert_equal [:gt, 'a', 'b'], ast.to_a    
  end
    
  def test_prefix_operator
    ast = ScopedSearch::QueryLanguage::Compiler.parse('> b')
    assert_equal [:gt, 'b'], ast.to_a    
  end  
  
  def test_comma_and_prefix_operator
    ast = ScopedSearch::QueryLanguage::Compiler.parse('a, > b')
    assert_equal [:and, 'a', [:gt, 'b']], ast.to_a    
  end  
  
  def test_expression_and_prefix_operator
    ast = ScopedSearch::QueryLanguage::Compiler.parse('(a = b) >c')
    assert_equal [:and, [:eq, 'a', 'b'], [:gt, 'c']], ast.to_a    
  end  
end
