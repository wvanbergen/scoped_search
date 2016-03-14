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
end
