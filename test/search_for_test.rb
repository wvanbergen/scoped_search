require File.dirname(__FILE__) + '/test_helper'

class ScopedSearchTest < Test::Unit::TestCase

  def setup
    case ENV['DATABASE']
      when 'mysql'
        create_mysql_connection
      when 'postgresql' 
        create_postgresql_connection
      else 'sqlite3'     
        create_sqlite3_connection
    end
    InitialSchema.up
    SearchTestModel.create_corpus!
    Group.create_corpus!
    Location.create_corpus!
    Address.create_corpus!
    User.create_corpus!
    Client.create_corpus!
    Office.create_corpus!
    Note.create_corpus!
  end

  def teardown
    InitialSchema.down
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
  
    assert_equal SearchTestModel.count, SearchTestModel.search_for('').count
    assert_equal 0, SearchTestModel.search_for('456').count   
    assert_equal 2, SearchTestModel.search_for('hays').count 
    assert_equal 1, SearchTestModel.search_for('hay ob').count        
    assert_equal 15, SearchTestModel.search_for('o').count    
    assert_equal 2, SearchTestModel.search_for('-o').count
    assert_equal 15, SearchTestModel.search_for('-Jim').count
    assert_equal 1, SearchTestModel.search_for('Jim -Bush').count
    assert_equal 1, SearchTestModel.search_for('"Hello World" -"Goodnight Moon"').count    
    assert_equal 2, SearchTestModel.search_for('Wes OR Bob').count
    assert_equal 3, SearchTestModel.search_for('"Happy cow" OR "Sad Frog"').count
    assert_equal 3, SearchTestModel.search_for('"Man made" OR Dogs').count
    assert_equal 2, SearchTestModel.search_for('Cows OR "Frog Toys"').count   
  
    # ** DATES **   
    #
    # The next two dates are invalid therefore it will be ignored.  
    # Since it is just a date being searched for it will also
    # be searched for in text fields regardless of whether or 
    # not it is a valid date.
    assert_equal 0, SearchTestModel.search_for('2/30/1980').count 
    assert_equal 0, SearchTestModel.search_for('99/99/9999').count
  
    assert_equal 1, SearchTestModel.search_for('9/27/1980').count
    assert_equal 1, SearchTestModel.search_for('hays 9/27/1980').count
    assert_equal 0, SearchTestModel.search_for('hays 2/30/1980').count 
  
    assert_equal 1, SearchTestModel.search_for('< 12/01/1980').count    
    assert_equal 6, SearchTestModel.search_for('> 2006/1/1').count
  
    assert_equal 5, SearchTestModel.search_for('< 12/26/2002').count 
    assert_equal 6, SearchTestModel.search_for('<= 12/26/2002').count   
  
    assert_equal 6, SearchTestModel.search_for('> 2/5/2005').count 
    assert_equal 7, SearchTestModel.search_for('>= 2/5/2005').count   
  
    assert_equal 3, SearchTestModel.search_for('1/1/2005 TO 1/1/2007').count 
  
    assert_equal 2, SearchTestModel.search_for('Happy 1/1/2005 TO 1/1/2007').count 
       
    # This should return one with a date of 7/15/2006 found in the text.
    assert_equal 2, SearchTestModel.search_for('7/15/2006').count
  end
  
  def test_search_belongs_to_association
    User.searchable_on :first_name, :last_name, :group_name
      
    assert_equal User.count, User.search_for('').count        
    assert_equal 1, User.search_for('Wes').count     
    assert_equal 2, User.search_for('System Administrator').count
    assert_equal 2, User.search_for('Managers').count
  end
  
  def test_search_has_many_association
    User.searchable_on :first_name, :last_name, :notes_title, :notes_content
  
    assert_equal User.count, User.search_for('').count        
    assert_equal 2, User.search_for('Router').count     
    assert_equal 1, User.search_for('milk').count
    assert_equal 1, User.search_for('"Spec Tests"').count
    assert_equal 0, User.search_for('Wes "Spec Tests"').count
  end  
  
  def test_search_has_many_through_association
    User.searchable_on :first_name, :last_name, :clients_first_name, :clients_last_name
      
    assert_equal User.count, User.search_for('').count        
    assert_equal 2, User.search_for('Smith').count     
    assert_equal 1, User.search_for('Sam').count
    assert_equal 1, User.search_for('Johnson').count
  end  
  
  def test_search_has_one_association
    User.searchable_on :first_name, :last_name, :address_street, :address_city, :address_state, :address_postal_code
          
    assert_equal User.count, User.search_for('').count        
    assert_equal 1, User.search_for('Fernley').count     
    assert_equal 4, User.search_for('NV').count
    assert_equal 1, User.search_for('Haskell').count  
    assert_equal 2, User.search_for('89434').count        
  end  
  
  def test_search_has_and_belongs_to_many_association
    User.searchable_on :first_name, :last_name, :locations_name
  
    assert_equal User.count, User.search_for('').count        
    assert_equal 2, User.search_for('Office').count     
    assert_equal 1, User.search_for('Store').count
    assert_equal 1, User.search_for('John Office').count
  end  

end


