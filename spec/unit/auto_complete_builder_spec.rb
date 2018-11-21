require "spec_helper"

describe ScopedSearch::AutoCompleteBuilder do

  let(:klass) { Class.new(ActiveRecord::Base) }

  before(:each) do
    @definition = double('ScopedSearch::Definition')
    @definition.stub(:klass).and_return(klass)
    @definition.stub(:profile).and_return(:default)
    @definition.stub(:profile=).and_return(true)
    @definition.klass.stub(:connection).and_return(double())
    @definition.stub(:default_order).and_return(nil)
  end

  it "should return empty suggestions if the search query is nil" do
    ScopedSearch::AutoCompleteBuilder.auto_complete(@definition, nil).should == []
  end

  it "should return empty suggestions if the query is blank" do
    ScopedSearch::AutoCompleteBuilder.auto_complete(@definition, "").should == []
  end

  it 'should suggest special values' do
    field = double('field')
    [:temporal?, :set?, :key_field, :validator, :virtual?, :relation, :offset, :value_translation, :to_sql].each { |key| field.stub(key) }
    field.stub(:special_values).and_return %w(foo bar baz)
    field.stub(:complete_value).and_return(true)
    @definition.stub(:default_fields_for).and_return([])
    @definition.stub(:field_by_name).and_return(field)
    @definition.stub(:fields).and_return [field]
    ScopedSearch::AutoCompleteBuilder.any_instance.stub(:complete_value_from_db).and_return([])
    ScopedSearch::AutoCompleteBuilder.auto_complete(@definition, "custom_field =").should eq(['custom_field = foo', 'custom_field = bar', 'custom_field = baz'])
    ScopedSearch::AutoCompleteBuilder.auto_complete(@definition, "custom_field = f").should eq(['custom_field =  foo'])
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
