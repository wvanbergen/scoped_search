require "spec_helper"

describe ScopedSearch::AutoCompleteBuilder do

  let(:klass) { Class.new(ActiveRecord::Base) }

  before(:each) do
    @definition = double('ScopedSearch::Definition')
    @definition.stub(:klass).and_return(klass)
    @definition.stub(:profile).and_return(:default)
    @definition.stub(:profile=).and_return(true)
  end

  it "should return empty suggestions if the search query is nil" do
    ScopedSearch::AutoCompleteBuilder.auto_complete(@definition, nil).should == []
  end

  it "should return empty suggestions if the query is blank" do
    ScopedSearch::AutoCompleteBuilder.auto_complete(@definition, "").should == []
  end

  context "with ext_method" do
    before do
      @definition = ScopedSearch::Definition.new(klass)
      @definition.define(:test_field, ext_method: :ext_test)
      @definition.klass.stub(:connection).and_return(double())
      @definition.klass.stub(:columns_hash).and_return({})
    end

    it "should support operator auto-completion on a virtual field" do
      klass.should_receive(:ext_test).with('', '=', 'test_field').and_return(conditions: '')
      ScopedSearch::AutoCompleteBuilder.auto_complete(@definition, 'test_field ').should eq(["test_field  = ", "test_field  != ", "test_field  > ", "test_field  < ", "test_field  <= ", "test_field  >= ", "test_field  ~ ", "test_field  !~ ", "test_field  ^ ", "test_field  !^ "])
    end
  end

end
