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
    SearchTestModel.searchable_on :string_field, :text_field, :date_field
    assert SearchTestModel.respond_to?(:search_for)
  
    assert_equal ActiveRecord::NamedScope::Scope, SearchTestModel.search_for('test').class
  end  
  
  def test_search_only_fields
    SearchTestModel.searchable_on :only => [:string_field, :text_field, :date_field]
    assert SearchTestModel.respond_to?(:search_for)
    assert_equal SearchTestModel.scoped_search_fields.size, 3
    assert SearchTestModel.scoped_search_fields.include?(:string_field)
    assert SearchTestModel.scoped_search_fields.include?(:text_field)
    assert SearchTestModel.scoped_search_fields.include?(:date_field)
  end
  
  def test_search_except_fields
    SearchTestModel.searchable_on :except => [:id, :ignored_field, :created_at, :updated_at]
    assert SearchTestModel.respond_to?(:search_for)
    assert_equal SearchTestModel.scoped_search_fields.size, 3
    assert SearchTestModel.scoped_search_fields.include?(:string_field)
    assert SearchTestModel.scoped_search_fields.include?(:text_field)
    assert SearchTestModel.scoped_search_fields.include?(:date_field)
  end  
  
  def test_search_with_only_and_except
    # :except should be ignored if :only is specified.
    SearchTestModel.searchable_on({:only => [:text_field], :except => [:text_field]})
    assert SearchTestModel.respond_to?(:search_for)
    assert_equal SearchTestModel.scoped_search_fields.size, 1
    assert SearchTestModel.scoped_search_fields.include?(:text_field), ':except should be ignored if :only is specified'
  end  
  
  def test_search
    SearchTestModel.searchable_on :string_field, :text_field, :date_field
  
    assert_equal 16, SearchTestModel.search_for('').count
    assert_equal 0, SearchTestModel.search_for('456').count   
    assert_equal 2, SearchTestModel.search_for('hays').count 
    assert_equal 1, SearchTestModel.search_for('hay ob').count        
    assert_equal 14, SearchTestModel.search_for('o').count    
    assert_equal 2, SearchTestModel.search_for('-o').count
    assert_equal 14, SearchTestModel.search_for('-Jim').count
    assert_equal 1, SearchTestModel.search_for('Jim -Bush').count
    assert_equal 1, SearchTestModel.search_for('"Hello World" -"Goodnight Moon"').count    
    assert_equal 2, SearchTestModel.search_for('Wes OR Bob').count
    assert_equal 3, SearchTestModel.search_for('"Happy cow" OR "Sad Frog"').count
    assert_equal 3, SearchTestModel.search_for('"Man made" OR Dogs').count
    assert_equal 2, SearchTestModel.search_for('Cows OR "Frog Toys"').count   
  
    # ** DATES **   
    #
    # The next two dates are invalid therefore it will be ignored.  
    # Thus it would be the same as searching for an empty string
    assert_equal 16, SearchTestModel.search_for('2/30/1980').count 
    assert_equal 16, SearchTestModel.search_for('99/99/9999').count
  
    assert_equal 1, SearchTestModel.search_for('9/27/1980').count
    assert_equal 1, SearchTestModel.search_for('hays 9/27/1980').count
    assert_equal 2, SearchTestModel.search_for('hays 2/30/1980').count    
    assert_equal 1, SearchTestModel.search_for('2006/07/15').count
  
    assert_equal 1, SearchTestModel.search_for('< 12/01/1980').count    
    assert_equal 5, SearchTestModel.search_for('> 1/1/2006').count
  
    assert_equal 5, SearchTestModel.search_for('< 12/26/2002').count 
    assert_equal 6, SearchTestModel.search_for('<= 12/26/2002').count   
  
    assert_equal 5, SearchTestModel.search_for('> 2/5/2005').count 
    assert_equal 6, SearchTestModel.search_for('>= 2/5/2005').count   
  
    assert_equal 3, SearchTestModel.search_for('1/1/2005 TO 1/1/2007').count 
  
    assert_equal 2, SearchTestModel.search_for('Happy 1/1/2005 TO 1/1/2007').count 
  end

end


