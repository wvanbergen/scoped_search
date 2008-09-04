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
    
    assert_equal ActiveRecord::NamedScope::Scope, SearchTestModel.search_for.class
    
  end
  
  def test_search
    SearchTestModel.searchable_on :string_field, :text_field
    
    assert_equal 3, SearchTestModel.search_for('123').count
    assert_equal 3, SearchTestModel.search_for('haLL').count
    assert_equal 1, SearchTestModel.search_for('456').count    
    assert_equal 2, SearchTestModel.search_for('ha 23').count        
    assert_equal 0, SearchTestModel.search_for('wi').count 
    
    assert_equal 1, SearchTestModel.search_for('-hallo').count
    assert_equal 4, SearchTestModel.search_for('-wi').count
    assert_equal 3, SearchTestModel.search_for('-789').count    
    assert_equal 2, SearchTestModel.search_for('123 -456').count
  end

end


