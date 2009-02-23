require File.dirname(__FILE__) + '/../test_helper'

class ScopedSearch::Test::QueryConditionsBuilder < Test::Unit::TestCase

  # change this function if you switch to another query language parser
  def build_query(search_conditions, query_fields)    
    ScopedSearch::QueryConditionsBuilder.build_query(search_conditions, query_fields)
  end
  
  # ** Invalid search conditions **
  def test_search_with_invalid_search_conditions
    search_conditions = ''
    query_fields = {'some_table.first_name' => :string}   
    assert_raise(RuntimeError, 'search_conditions must be a hash') {
      build_query(search_conditions, query_fields) 
    }
  end  
  
  def test_search_with_invalid_query_fields
    search_conditions = [["Wes", :like]]
    query_fields = ''    
    assert_raise(RuntimeError, 'query_fields must be a hash') {
      build_query(search_conditions, query_fields) 
    }
  end
    
  
  # ** Single query search tests **
  def test_like_search_condition
    search_conditions = [["Wes", :like]]
    query_fields = {'some_table.first_name' => :string}    
    conditions = build_query(search_conditions, query_fields) 
  
    assert_equal '(some_table.first_name LIKE :keyword_0)', conditions.first
    assert_equal '%Wes%', conditions.last[:keyword_0]
  end
  
  def test_like_search_condition_with_integer
    search_conditions = [["26", :like]]
    query_fields = {'some_table.age' => :integer}    
    conditions = build_query(search_conditions, query_fields) 
  
    assert_equal '(some_table.age = :keyword_0_26)', conditions.first
    assert_equal 26, conditions.last[:keyword_0_26]
  end  
  
  def test_not_like_search_condition
    search_conditions = [["Wes", :not]]
    query_fields = {'some_table.first_name' => :string}    
    conditions = build_query(search_conditions, query_fields) 
  
    assert_equal '((some_table.first_name NOT LIKE :keyword_0 OR some_table.first_name IS NULL))', conditions.first
    assert_equal '%Wes%', conditions.last[:keyword_0]
  end  
  
  def test_or_search_condition
    search_conditions = [["Wes OR Hays", :or]]
    query_fields = {'some_table.first_name' => :string}    
    conditions = build_query(search_conditions, query_fields) 
    regExs = build_regex_for_or(['first_name'], 'keyword_0')
    assert_match /^#{regExs}$/, conditions.first
    assert_equal '%Wes%', conditions.last[:keyword_0a]
    assert_equal '%Hays%', conditions.last[:keyword_0b]
  end
  
  def test_or_search_condition_with_integer
    search_conditions = [["Wes OR 26", :or]]
    query_fields = {'some_table.first_name' => :string, 'some_table.age' => :integer}    
    conditions = build_query(search_conditions, query_fields) 
    regExs = build_regex_for_or(['first_name', 'age'], 'keyword_0')
    assert_match /^#{regExs}$/, conditions.first
    assert_equal '%Wes%', conditions.last[:keyword_0a]
    assert_equal 26, conditions.last[:keyword_0_26]       
  end  
  
  # ** less_than_date **
  def test_less_than_date_search_condition_with_only_a_date_field_to_search 
    search_conditions = [['< 09/27/1980', :less_than_date]]
    query_fields = {'some_table.event_date' => :datetime}    
    conditions = build_query(search_conditions, query_fields) 
  
    assert_equal '(some_table.event_date < :keyword_0)', conditions.first
    assert_equal '1980-09-27', conditions.last[:keyword_0]
  end  
  
  def test_less_than_date_search_condition_with_invalid_date 
    search_conditions = [['< 2/30/1980', :less_than_date]]
    query_fields = {'some_table.event_date' => :datetime}    
    conditions = build_query(search_conditions, query_fields) 
  
    assert conditions.first.empty?
    assert conditions.last.empty?
  end  
  
  def test_less_than_date_search_condition_with_a_date_field_and_a_text_field
    search_conditions = [['< 09/27/1980', :less_than_date]]
    query_fields = {'some_table.event_date' => :datetime, 'some_table.first_name' => :string}    
    conditions = build_query(search_conditions, query_fields) 
  
    assert_equal '(some_table.event_date < :keyword_0)', conditions.first
    assert_equal '1980-09-27', conditions.last[:keyword_0]  
  end  
  
  def test_less_than_date_search_condition_with_a_date_field_and_a_text_field
    search_conditions = [['< 2/30/1980', :less_than_date]]
    query_fields = {'some_table.event_date' => :datetime, 'some_table.first_name' => :string}    
    conditions = build_query(search_conditions, query_fields) 
  
    assert conditions.first.empty?
    assert conditions.last.empty?   
  end  
  
  
  # ** less_than_or_equal_to_date **
  def test_less_than_or_equal_to_date_search_condition_with_only_a_date_field_to_search 
    search_conditions = [['<= 09/27/1980', :less_than_or_equal_to_date]]
    query_fields = {'some_table.event_date' => :datetime}    
    conditions = build_query(search_conditions, query_fields) 
  
    assert_equal '(some_table.event_date <= :keyword_0)', conditions.first
    assert_equal '1980-09-27', conditions.last[:keyword_0]
  end  
  
  def test_less_than_or_equal_to_date_search_condition_with_invalid_date 
    search_conditions = [['<= 2/30/1980', :less_than_or_equal_to_date]]
    query_fields = {'some_table.event_date' => :datetime}    
    conditions = build_query(search_conditions, query_fields) 
  
    assert conditions.first.empty?
    assert conditions.last.empty?
  end  
  
  def test_less_than_or_equal_to_date_search_condition_with_a_date_field_and_a_text_field
    search_conditions = [['<= 09/27/1980', :less_than_or_equal_to_date]]
    query_fields = {'some_table.event_date' => :datetime, 'some_table.first_name' => :string}    
    conditions = build_query(search_conditions, query_fields) 
  
    assert_equal '(some_table.event_date <= :keyword_0)', conditions.first
    assert_equal '1980-09-27', conditions.last[:keyword_0]  
  end  
  
  def test_less_than_or_equal_to_date_search_condition_with_a_date_field_and_a_text_field
    search_conditions = [['<= 2/30/1980', :less_than_or_equal_to_date]]
    query_fields = {'some_table.event_date' => :datetime, 'some_table.first_name' => :string}    
    conditions = build_query(search_conditions, query_fields) 
  
    assert conditions.first.empty?
    assert conditions.last.empty?   
  end
  
  
  # ** as_of_date **
  def test_as_of_date_search_condition_with_only_a_date_field_to_search 
    search_conditions = [['09/27/1980', :as_of_date]]
    query_fields = {'some_table.event_date' => :datetime}    
    conditions = build_query(search_conditions, query_fields) 
   
    assert_equal '(some_table.event_date = :keyword_0)', conditions.first
    assert_equal '1980-09-27', conditions.last[:keyword_0]
  end  
  
  def test_as_of_date_search_condition_with_invalid_date 
    search_conditions = [['2/30/1980', :as_of_date]]
    query_fields = {'some_table.event_date' => :datetime}    
    conditions = build_query(search_conditions, query_fields) 
  
    assert conditions.first.empty?
    assert conditions.last.empty?
  end  
  
  def test_as_of_date_search_condition_with_a_date_field_and_a_text_field
    search_conditions = [['09/27/1980', :as_of_date]]
    query_fields = {'some_table.event_date' => :datetime, 'some_table.first_name' => :string}    
    conditions = build_query(search_conditions, query_fields) 
  
    assert_equal '(some_table.event_date = :keyword_0 OR some_table.first_name LIKE :keyword_0b)', conditions.first
    assert_equal '1980-09-27', conditions.last[:keyword_0]
    assert_equal '%09/27/1980%', conditions.last[:keyword_0b]    
  end  
  
  def test_as_of_date_search_condition_with_a_date_field_and_a_text_field
    search_conditions = [['2/30/1980', :as_of_date]]
    query_fields = {'some_table.event_date' => :datetime, 'some_table.first_name' => :string}    
    conditions = build_query(search_conditions, query_fields) 
  
    assert_equal '(some_table.first_name LIKE :keyword_0b)', conditions.first
    assert_equal '%2/30/1980%', conditions.last[:keyword_0b]    
  end
  
  
  # ** greater_than_date **
  def test_less_than_or_equal_to_date_search_condition_with_only_a_date_field_to_search 
    search_conditions = [['> 09/27/1980', :greater_than_date]]
    query_fields = {'some_table.event_date' => :datetime}    
    conditions = build_query(search_conditions, query_fields) 
  
    assert_equal '(some_table.event_date > :keyword_0)', conditions.first
    assert_equal '1980-09-27', conditions.last[:keyword_0]
  end  
  
  def test_less_than_or_equal_to_date_search_condition_with_invalid_date 
    search_conditions = [['> 2/30/1980', :greater_than_date]]
    query_fields = {'some_table.event_date' => :datetime}    
    conditions = build_query(search_conditions, query_fields) 
  
    assert conditions.first.empty?
    assert conditions.last.empty?
  end  
  
  def test_less_than_or_equal_to_date_search_condition_with_a_date_field_and_a_text_field
    search_conditions = [['> 09/27/1980', :greater_than_date]]
    query_fields = {'some_table.event_date' => :datetime, 'some_table.first_name' => :string}    
    conditions = build_query(search_conditions, query_fields) 
  
    assert_equal '(some_table.event_date > :keyword_0)', conditions.first
    assert_equal '1980-09-27', conditions.last[:keyword_0]  
  end  
  
  def test_less_than_or_equal_to_date_search_condition_with_a_date_field_and_a_text_field
    search_conditions = [['> 2/30/1980', :greater_than_date]]
    query_fields = {'some_table.event_date' => :datetime, 'some_table.first_name' => :string}    
    conditions = build_query(search_conditions, query_fields) 
  
    assert conditions.first.empty?
    assert conditions.last.empty?   
  end
  
  
  # ** greater_than_or_equal_to_date **
  def test_less_than_or_equal_to_date_search_condition_with_only_a_date_field_to_search 
    search_conditions = [['>= 09/27/1980', :greater_than_or_equal_to_date]]
    query_fields = {'some_table.event_date' => :datetime}    
    conditions = build_query(search_conditions, query_fields) 
  
    assert_equal '(some_table.event_date >= :keyword_0)', conditions.first
    assert_equal '1980-09-27', conditions.last[:keyword_0]
  end  
  
  def test_less_than_or_equal_to_date_search_condition_with_invalid_date 
    search_conditions = [['>= 2/30/1980', :greater_than_or_equal_to_date]]
    query_fields = {'some_table.event_date' => :datetime}    
    conditions = build_query(search_conditions, query_fields) 
  
    assert conditions.first.empty?
    assert conditions.last.empty?
  end  
  
  def test_less_than_or_equal_to_date_search_condition_with_a_date_field_and_a_text_field
    search_conditions = [['>= 09/27/1980', :greater_than_or_equal_to_date]]
    query_fields = {'some_table.event_date' => :datetime, 'some_table.first_name' => :string}    
    conditions = build_query(search_conditions, query_fields) 
  
    assert_equal '(some_table.event_date >= :keyword_0)', conditions.first
    assert_equal '1980-09-27', conditions.last[:keyword_0]  
  end  
  
  def test_less_than_or_equal_to_date_search_condition_with_a_date_field_and_a_text_field
    search_conditions = [['>= 2/30/1980', :greater_than_or_equal_to_date]]
    query_fields = {'some_table.event_date' => :datetime, 'some_table.first_name' => :string}    
    conditions = build_query(search_conditions, query_fields) 
  
    assert conditions.first.empty?
    assert conditions.last.empty?   
  end    
  
  
  
  # ** between_dates **
  def test_between_dates_search_condition_two_valid_dates 
    search_conditions = [['09/27/1980 TO 10/15/1980', :between_dates]]
    query_fields = {'some_table.event_date' => :datetime}    
    conditions = build_query(search_conditions, query_fields) 

    assert_equal '((some_table.event_date BETWEEN :keyword_0a AND :keyword_0b))', conditions.first
    assert_equal '1980-09-27', conditions.last[:keyword_0a]
    assert_equal '1980-10-15', conditions.last[:keyword_0b]
  end  
  
  def test_between_dates_search_condition_with_a_valid_date_first_and_an_invalid_date_second
    search_conditions = [['09/27/1980 TO 2/30/1981', :between_dates]]
    query_fields = {'some_table.event_date' => :datetime}    
    conditions = build_query(search_conditions, query_fields) 

    assert conditions.first.empty?
    assert conditions.last.empty?
  end  
  
  def test_between_dates_search_condition_with_an_invalid_date_first_and_a_valid_date_second
    search_conditions = [['02/30/1980 TO 09/27/1980', :between_dates]]
    query_fields = {'some_table.event_date' => :datetime}    
    conditions = build_query(search_conditions, query_fields) 

    assert conditions.first.empty?
    assert conditions.last.empty?
  end  
  
  def test_between_dates_search_condition_with_two_invalid_dates
    search_conditions = [['02/30/1980 TO 02/30/1981', :between_dates]]
    query_fields = {'some_table.event_date' => :datetime}    
    conditions = build_query(search_conditions, query_fields) 

    assert conditions.first.empty?
    assert conditions.last.empty?
  end  
  
  
  def test_between_dates_search_condition_two_valid_dates_and_a_text_field
    search_conditions = [['09/27/1980 TO 10/15/1980', :between_dates]]
    query_fields = {'some_table.event_date' => :datetime, 'some_table.first_name' => :string}    
    conditions = build_query(search_conditions, query_fields) 

    assert_equal '((some_table.event_date BETWEEN :keyword_0a AND :keyword_0b))', conditions.first
    assert_equal '1980-09-27', conditions.last[:keyword_0a]
    assert_equal '1980-10-15', conditions.last[:keyword_0b]
  end  
  
  def test_between_dates_search_condition_with_a_valid_date_first_and_an_invalid_date_second_and_a_text_field
    search_conditions = [['09/27/1980 TO 2/30/1981', :between_dates]]
    query_fields = {'some_table.event_date' => :datetime, 'some_table.first_name' => :string}    
    conditions = build_query(search_conditions, query_fields) 

    assert conditions.first.empty?
    assert conditions.last.empty?
  end  
  
  def test_between_dates_search_condition_with_an_invalid_date_first_and_a_valid_date_second_and_a_text_field
    search_conditions = [['02/30/1980 TO 09/27/1980', :between_dates]]
    query_fields = {'some_table.event_date' => :datetime, 'some_table.first_name' => :string}    
    conditions = build_query(search_conditions, query_fields) 

    assert conditions.first.empty?
    assert conditions.last.empty?
  end  
  
  def test_between_dates_search_condition_with_two_invalid_dates_and_a_text_field
    search_conditions = [['02/30/1980 TO 02/30/1981', :between_dates]]
    query_fields = {'some_table.event_date' => :datetime, 'some_table.first_name' => :string}    
    conditions = build_query(search_conditions, query_fields) 

    assert conditions.first.empty?
    assert conditions.last.empty?
  end  
  
    
  # ** Multi query search tests **
  def test_like_two_search_condition
    search_conditions = [["Wes", :like],["Hays", :like]]
    query_fields = {'some_table.first_name' => :string,'some_table.last_name' => :string}    
    conditions = build_query(search_conditions, query_fields) 
  
    fields = ['first_name','last_name']
    regExs = [build_regex_for_like(fields,'keyword_0'), 
              build_regex_for_like(fields,'keyword_1')].join('[ ]AND[ ]')
  
    assert_match /^#{regExs}$/, conditions.first
    assert_equal '%Wes%', conditions.last[:keyword_0]
    assert_equal '%Hays%', conditions.last[:keyword_1]
  end  
  
  def test_like_two_search_conditions_with_one_not
    search_conditions = [["Wes", :like],["Hays", :not]]
    query_fields = {'some_table.first_name' => :string,'some_table.last_name' => :string}    
    conditions = build_query(search_conditions, query_fields) 
  
    fields = ['first_name','last_name']
    regExs = [build_regex_for_like(fields,'keyword_0'), 
              build_regex_for_not_like(fields,'keyword_1')].join('[ ]AND[ ]')
  
    assert_match /^#{regExs}$/, conditions.first
    assert_equal '%Wes%', conditions.last[:keyword_0]
    assert_equal '%Hays%', conditions.last[:keyword_1]
  end  
  
  
  # ** Helper methods **
  def build_regex_for_like(fields,keyword)
    orFields = fields.join('|')
    regParts = fields.collect { |field| 
                 "some_table.(#{orFields}) LIKE :#{keyword}" 
               }.join('[ ]OR[ ]')  
    "[\(]#{regParts}[\)]"  
  end
  
  def build_regex_for_not_like(fields,keyword)
    orFields = fields.join('|')
    regParts = fields.collect { |field| 
                 "[\(]some_table.(#{orFields}) NOT LIKE :#{keyword} OR some_table.(#{orFields}) IS NULL[\)]" 
               }.join('[ ]AND[ ]')
    
    "[\(]#{regParts}[\)]"
  end  
  
  def build_regex_for_or(fields,keyword)
    orFields = fields.join('|')
    regParts = fields.collect { |field| 
                 "([(](some_table.(first_name|age) (LIKE|=) :keyword_0[a-zA-Z0-9_]+ OR )?some_table.(first_name|age) (LIKE|=) :keyword_0[a-zA-Z0-9_]+)[)]" 
               }.join('[ ]OR[ ]')
    
    "[\(]#{regParts}[\)]"
  end  
  
  
  def build_regex_for_date(fields,keyword)
    orFields = fields.join('|')
    regParts = fields.collect { |field| 
                 "some_table.(#{orFields}) = :#{keyword}" 
               }.join('[ ]OR[ ]')  
    "[\(]#{regParts}[\)]"  
  end  
end