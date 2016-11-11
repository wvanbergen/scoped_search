require "spec_helper"

describe ScopedSearch::QueryBuilder do

  before(:each) do
    @definition = double('ScopedSearch::Definition')
    @definition.stub(:klass).and_return(Class.new(ActiveRecord::Base))
    @definition.stub(:profile).and_return(:default)
    @definition.stub(:default_order).and_return(nil)
    @definition.stub(:profile=).and_return(true)
    @definition.klass.stub(:connection).and_return(double())
  end

  it "should raise an ArgumentError if the query is not set" do
    lambda { ScopedSearch::QueryBuilder.build_query(@definition, nil) }.should raise_error(ArgumentError)
  end

  it "should return empty conditions if the query is blank" do
    ScopedSearch::QueryBuilder.build_query(@definition, "").should == { }
  end

  it "should return empty conditions if the query is whitespace only" do
    ScopedSearch::QueryBuilder.build_query(@definition, "\t ").should == {  }
  end

  it "should use default adapter when connection type is unknown" do
    ScopedSearch::QueryBuilder.class_for(@definition).should == ScopedSearch::QueryBuilder
  end

  it "should use postgres adapter for postgres-like connection" do
    connection = double()
    connection.stub("name").and_return("SomePostgreSQLAdapter")
    @definition.klass.connection.stub("class").and_return(connection)
    ScopedSearch::QueryBuilder.class_for(@definition).should == ScopedSearch::QueryBuilder::PostgreSQLAdapter
  end

  it "should validate value if validator selected" do
    field = double('field')
    field.stub(:only_explicit).and_return(true)
    field.stub(:field).and_return(:test_field)
    field.stub(:validator).and_return(->(_value) { false })

    @definition.stub(:field_by_name).and_return(field)

    lambda { ScopedSearch::QueryBuilder.build_query(@definition, 'test_field = test_val') }.should raise_error(ScopedSearch::QueryNotSupported)
  end

  it "should display custom error from validator" do
    field = double('field')
    field.stub(:only_explicit).and_return(true)
    field.stub(:field).and_return(:test_field)
    field.stub(:validator).and_return(->(_value) { raise ScopedSearch::QueryNotSupported, 'my custom message' })

    @definition.stub(:field_by_name).and_return(field)

    lambda { ScopedSearch::QueryBuilder.build_query(@definition, 'test_field = test_val') }.should raise_error('my custom message')
  end
end
