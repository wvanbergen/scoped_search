require "spec_helper"

describe ScopedSearch::QueryBuilder do

  let(:klass) { Class.new(ActiveRecord::Base) }

  before(:each) do
    @definition = double('ScopedSearch::Definition')
    @definition.stub(:klass).and_return(klass)
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
    field.stub(:virtual?).and_return(false)
    field.stub(:only_explicit).and_return(true)
    field.stub(:field).and_return(:test_field)
    field.stub(:validator).and_return(->(_value) { false })
    field.stub(:special_values).and_return([])

    @definition.stub(:field_by_name).and_return(field)

    lambda { ScopedSearch::QueryBuilder.build_query(@definition, 'test_field = test_val') }.should raise_error(ScopedSearch::QueryNotSupported)
  end

  it "should validate value if validator selected" do
    field = double('field')
    field.stub(:virtual?).and_return(false)
    field.stub(:temporal?).and_return(false)
    field.stub(:relation).and_return(nil)
    field.stub(:only_explicit).and_return(true)
    field.stub(:field).and_return(:test_field)
    field.stub(:ext_method).and_return(nil)
    field.stub(:key_field).and_return(nil)
    field.stub(:set?).and_return(false)
    field.stub(:to_sql).and_return('')
    field.stub(:validator).and_return(->(value) { value =~ /^\d+$/ })
    field.stub(:value_translation).and_return(nil)
    field.stub(:special_values).and_return([])

    @definition.stub(:field_by_name).and_return(field)

    lambda { ScopedSearch::QueryBuilder.build_query(@definition, 'test_field ^ (1,2)') }.should_not raise_error
    lambda { ScopedSearch::QueryBuilder.build_query(@definition, 'test_field ^ (1,a)') }.should raise_error(ScopedSearch::QueryNotSupported)
    lambda { ScopedSearch::QueryBuilder.build_query(@definition, 'test_field !^ (1,2)') }.should_not raise_error
    lambda { ScopedSearch::QueryBuilder.build_query(@definition, 'test_field !^ (1,a)') }.should raise_error(ScopedSearch::QueryNotSupported)
  end

  it "should display custom error from validator" do
    field = double('field')
    field.stub(:virtual?).and_return(false)
    field.stub(:only_explicit).and_return(true)
    field.stub(:field).and_return(:test_field)
    field.stub(:validator).and_return(->(_value) { raise ScopedSearch::QueryNotSupported, 'my custom message' })
    field.stub(:special_values).and_return([])

    @definition.stub(:field_by_name).and_return(field)

    lambda { ScopedSearch::QueryBuilder.build_query(@definition, 'test_field = test_val') }.should raise_error('my custom message')
  end

  context 'with value_translation' do
    let(:translator) do
      ->(value) do
        if %w(a b c).include?(value)
          'good'
        end
      end
    end
    let(:special_values) { %w(a b c) }
    before do
      field = double('field')
      field.stub(:field).and_return(:test_field)
      field.stub(:key_field).and_return(nil)
      field.stub(:to_sql).and_return('test_field')
      [:virtual?, :set?, :temporal?, :relation, :offset].each { |key| field.stub(key).and_return(false) }
      field.stub(:validator).and_return(->(value) { value == 'x' }) # Nothing except for special_values and x is valid
      field.stub(:special_values).and_return(special_values)
      field.stub(:value_translation).and_return(translator)
      @definition.stub(:field_by_name).and_return(field)
    end

    it 'should translate the value' do
      ScopedSearch::QueryBuilder.build_query(@definition, 'test_field = a').should eq(conditions: ['(test_field = ?)', 'good'])
      ScopedSearch::QueryBuilder.build_query(@definition, 'test_field ^ (a, b, c)').should eq(conditions: ['(test_field IN (?,?,?))', 'good', 'good', 'good'])
    end

    it 'should validate before translation' do
      proc { ScopedSearch::QueryBuilder.build_query(@definition, 'test_field = d') }.should raise_error(ScopedSearch::QueryNotSupported, /Value 'd' is not valid for field/)
    end

    it 'should raise an error if translated value is nil' do
      proc { ScopedSearch::QueryBuilder.build_query(@definition, 'test_field = x') }.should raise_error(ScopedSearch::QueryNotSupported, /Translation from any value to nil is not allowed/)
    end
  end

  context "with ext_method" do
    before do
      @definition = ScopedSearch::Definition.new(klass)
      @definition.define(:test_field, ext_method: :ext_test)
    end

    it "should return combined :conditions and :parameter" do
      klass.should_receive(:ext_test).with('test_field', '=', 'test_val').and_return(conditions: 'field = ?', parameter: ['test_val'])
      ScopedSearch::QueryBuilder.build_query(@definition, 'test_field = test_val').should eq(conditions: ['(field = ?)', 'test_val'])
    end

    it "should return :joins and :include" do
      klass.should_receive(:ext_test).with('test_field', '=', 'test_val').and_return(include: 'test1', joins: 'test2')
      ScopedSearch::QueryBuilder.build_query(@definition, 'test_field = test_val').should eq(include: ['test1'], joins: ['test2'])
    end

    it "should support LIKE query on a virtual field" do
      klass.should_receive(:ext_test).with('test_field', 'LIKE', 'test_val').and_return(conditions: 'field LIKE ?', parameter: ['%test_val%'])
      ScopedSearch::QueryBuilder.build_query(@definition, 'test_field ~ test_val').should eq(conditions: ['(field LIKE ?)', '%test_val%'])
    end

    it "should raise error when non-hash returned" do
      klass.should_receive(:ext_test).and_return('test')
      lambda { ScopedSearch::QueryBuilder.build_query(@definition, 'test_field = test_val') }.should raise_error(ScopedSearch::QueryNotSupported, /should return hash/)
    end

    it "should raise error when ext_method doesn't exist" do
      lambda { ScopedSearch::QueryBuilder.build_query(@definition, 'test_field = test_val') }.should raise_error(ScopedSearch::QueryNotSupported, /doesn't respond to 'ext_test'/)
    end

    it "should raise error when method raises exception" do
      klass.should_receive(:ext_test).and_raise('test')
      lambda { ScopedSearch::QueryBuilder.build_query(@definition, 'test_field = test_val') }.should raise_error(ScopedSearch::QueryNotSupported, /failed with error: test/)
    end
  end
end
