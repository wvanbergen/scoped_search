require "#{File.dirname(__FILE__)}/../test_helper.rb"

class ScopedSearch::Test::API < Test::Unit::TestCase

  def self.const_missing(const)
    ScopedSearch::Test::Models.const_get(const)
  end

  def setup
    ScopedSearch::Test::establish_connection
    ScopedSearch::Test::DatabaseSchema.up
  end

  def teardown
      ScopedSearch::Test::DatabaseSchema.down    
  end
  
  def test_enabling
    assert !Foo.respond_to?(:search_for)
    Foo.searchable_on :string_field, :text_field, :date_field
    assert Foo.respond_to?(:search_for)
      
    assert_equal ActiveRecord::NamedScope::Scope, Foo.search_for('test').class
  end  
  
  def test_search_only_fields
    Foo.searchable_on :only => [:string_field, :text_field, :date_field]
    assert Foo.respond_to?(:search_for)
    assert_equal Foo.scoped_search_fields.size, 3
    assert Foo.scoped_search_fields.include?(:string_field)
    assert Foo.scoped_search_fields.include?(:text_field)
    assert Foo.scoped_search_fields.include?(:date_field)
  end
  
  def test_search_except_fields
    Foo.searchable_on :except => [:id, :ignored_field, :created_at, :updated_at]
    assert Foo.respond_to?(:search_for)
    assert_equal Foo.scoped_search_fields.size, 4
    assert Foo.scoped_search_fields.include?(:string_field)
    assert Foo.scoped_search_fields.include?(:text_field)
    assert Foo.scoped_search_fields.include?(:date_field)
    assert Foo.scoped_search_fields.include?(:some_int_field)
  end  
  
  def test_search_with_only_and_except
    # :except should be ignored if :only is specified.
    Foo.searchable_on({:only => [:text_field], :except => [:text_field]})
    assert Foo.respond_to?(:search_for)
    assert_equal Foo.scoped_search_fields.size, 1
    assert Foo.scoped_search_fields.include?(:text_field), ':except should be ignored if :only is specified'
  end  
  
end