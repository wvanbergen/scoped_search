require File.dirname(__FILE__) + '/../test_helper'

class ScopedSearch::Test::SearchFor < Test::Unit::TestCase

  def self.const_missing(const)
    ScopedSearch::Test::Models.const_get(const)
  end

  def setup
    ScopedSearch::Test.establish_connection
    ScopedSearch::Test::DatabaseSchema.up
    ScopedSearch::Test.create_corpus!
  end

  def teardown
    ScopedSearch::Test::DatabaseSchema.down    
  end
  
  def test_search
    Foo.searchable_on :string_field, :text_field, :date_field
  
    assert_equal Foo.count, Foo.search_for('').count
    assert_equal 0, Foo.search_for('456').count   
    assert_equal 2, Foo.search_for('hays').count 
    assert_equal 1, Foo.search_for('hay ob').count        
    assert_equal 15, Foo.search_for('o').count    
    assert_equal 2, Foo.search_for('-o').count
    assert_equal 15, Foo.search_for('-Jim').count
    assert_equal 1, Foo.search_for('Jim -Bush').count
    assert_equal 1, Foo.search_for('"Hello World" -"Goodnight Moon"').count    
    assert_equal 2, Foo.search_for('Wes OR Bob').count
    assert_equal 3, Foo.search_for('"Happy cow" OR "Sad Frog"').count
    assert_equal 3, Foo.search_for('"Man made" OR Dogs').count
    assert_equal 2, Foo.search_for('Cows OR "Frog Toys"').count   
  
    # ** DATES **   
    #
    # The next two dates are invalid therefore it will be ignored.  
    # Since it is just a date being searched for it will also
    # be searched for in text fields regardless of whether or 
    # not it is a valid date.
    assert_equal 0, Foo.search_for('2/30/1980').count 
    assert_equal 0, Foo.search_for('99/99/9999').count
  
    assert_equal 1, Foo.search_for('9/27/1980').count
    assert_equal 1, Foo.search_for('hays 9/27/1980').count
    assert_equal 0, Foo.search_for('hays 2/30/1980').count 
  
    assert_equal 1, Foo.search_for('< 12/01/1980').count    
    assert_equal 6, Foo.search_for('> 2006/1/1').count
  
    assert_equal 5, Foo.search_for('< 12/26/2002').count 
    assert_equal 6, Foo.search_for('<= 12/26/2002').count   
  
    assert_equal 6, Foo.search_for('> 2/5/2005').count 
    assert_equal 7, Foo.search_for('>= 2/5/2005').count   
  
    assert_equal 3, Foo.search_for('1/1/2005 TO 1/1/2007').count 
  
    assert_equal 2, Foo.search_for('Happy 1/1/2005 TO 1/1/2007').count 
       
    # This should return one with a date of 7/15/2006 found in the text.
    assert_equal 2, Foo.search_for('7/15/2006').count
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
  
  def test_search_with_very_long_query
    User.searchable_on :first_name, :last_name, :address_street, :address_city, :address_state, :address_postal_code
    really_long_string = ''
    10000.times {really_long_string << 'really long string'}
    assert_equal 0, User.search_for(really_long_string).count
  end

end


