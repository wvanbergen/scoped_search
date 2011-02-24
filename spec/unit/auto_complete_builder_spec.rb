require "#{File.dirname(__FILE__)}/../spec_helper"

describe ScopedSearch::AutoCompleteBuilder do

  before(:each) do
    @definition = mock('ScopedSearch::Definition')
    @definition.stub!(:klass).and_return(Class.new(ActiveRecord::Base))
    @definition.stub!(:profile).and_return(:default)
    @definition.stub!(:profile=).and_return(true)
  end

  it "should return empty suggestions if the search query is nil" do
    ScopedSearch::AutoCompleteBuilder.auto_complete(@definition, nil).should == []
  end

  it "should return empty suggestions if the query is blank" do
    ScopedSearch::AutoCompleteBuilder.auto_complete(@definition, "").should == []
  end

end
