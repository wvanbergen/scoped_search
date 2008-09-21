require File.dirname(__FILE__) + '/test_helper'

class QueryConditionsBuilderTest < Test::Unit::TestCase

  # change this function if you switch to another query language parser
  def build_query(search_conditions, query_fields)    
    ScopedSearch::QueryConditionsBuilder.build_query(search_conditions, query_fields)
  end
  
  # ** Single query search tests **
  def test_like_search_condition
    search_conditions = [["Wes", :like]]
    query_fields = {'some_table.first_name' => :string}    
    conditions = build_query(search_conditions, query_fields) 
    
    assert_equal '(some_table.first_name LIKE :keyword_0)', conditions.first
    assert_equal '%Wes%', conditions.last[:keyword_0]
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
  
  # def test_date_search_condition
  #   search_conditions = [["09/27/1980", :as_of_date]]
  #   query_fields = {'some_table.event_date' => :datetime}    
  #   conditions = build_query(search_conditions, query_fields) 
  #   regExs = build_regex_for_date(['event_date'], 'keyword_0')
  #   assert_match /^#{regExs}$/, conditions.first
  #   assert_equal '09/27/1980', conditions.last[:keyword_0a]
  # end  
  
    
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
                 "[\(]some_table.(#{orFields}) LIKE :#{keyword}a OR some_table.(#{orFields}) LIKE :#{keyword}b[\)]" 
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