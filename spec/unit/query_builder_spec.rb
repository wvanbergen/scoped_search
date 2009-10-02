require "#{File.dirname(__FILE__)}/../spec_helper"

describe ScopedSearch::QueryBuilder do

  before(:each) do
    @definition = mock('ScopedSearch::Definition')
    @definition.stub!(:klass).and_return(Class.new(ActiveRecord::Base))
  end

  it "should return empty conditions if the search query is nil" do
    ScopedSearch::QueryBuilder.build_query(@definition, nil).should == { }
  end

  it "should return empty conditions if the query is blank" do
    ScopedSearch::QueryBuilder.build_query(@definition, "").should == { }
  end

  it "should return empty conditions if the query is whitespace only" do
    ScopedSearch::QueryBuilder.build_query(@definition, "\t ").should == {  }
  end

end
