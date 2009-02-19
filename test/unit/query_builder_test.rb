require File.dirname(__FILE__) + '/../test_helper'

require 'scoped_search/query_language'
require 'scoped_search/query_builder'

class ScopedSearch::Test::QueryBuilder < Test::Unit::TestCase
  
  def test_simple_and_condition
     ast = ScopedSearch::QueryLanguage::Compiler.parse('some simple keywords')
     p sql = ScopedSearch::QueryBuilder.new(ast, [:name, :description]).build_query
  end

  def test_simple_or_and_parens
     ast = ScopedSearch::QueryLanguage::Compiler.parse('(some simple) OR keywords')
     p sql = ScopedSearch::QueryBuilder.new(ast, [:name, :description]).build_query
  end
  
end
