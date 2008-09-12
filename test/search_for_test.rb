require File.dirname(__FILE__) + '/test_helper'

class ScopedSearchTest < Test::Unit::TestCase

  def setup
    setup_db
    SearchTestModel.create_corpus!
  end

  def teardown
    teardown_db
  end
  
  def test_enabling
    assert !SearchTestModel.respond_to?(:search_for)
    SearchTestModel.searchable_on :string_field, :text_field
    assert SearchTestModel.respond_to?(:search_for)
    
    assert_equal ActiveRecord::NamedScope::Scope, SearchTestModel.search_for('test').class
    
  end
  
  def test_search
    SearchTestModel.searchable_on :string_field, :text_field
    
    assert_equal 15, SearchTestModel.search_for('').count
    assert_equal 0, SearchTestModel.search_for('456').count   
    assert_equal 2, SearchTestModel.search_for('hays').count 
    assert_equal 1, SearchTestModel.search_for('hay ob').count        
    assert_equal 13, SearchTestModel.search_for('o').count    
    assert_equal 2, SearchTestModel.search_for('-o').count
    assert_equal 13, SearchTestModel.search_for('-Jim').count
    assert_equal 1, SearchTestModel.search_for('Jim -Bush').count
    assert_equal 1, SearchTestModel.search_for('"Hello World" -"Goodnight Moon"').count    
    assert_equal 2, SearchTestModel.search_for('Wes OR Bob').count
    assert_equal 3, SearchTestModel.search_for('"Happy cow" OR "Sad Frog"').count
    assert_equal 3, SearchTestModel.search_for('"Man made" OR Dogs').count
    assert_equal 2, SearchTestModel.search_for('Cows OR "Frog Toys"').count   
  end

end


