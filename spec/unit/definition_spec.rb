require "spec_helper"

describe ScopedSearch::Definition do

  before(:each) do
    @klass      = mock_activerecord_class
    @definition = ScopedSearch::Definition.new(@klass)
    @definition.stub(:setup_adapter)
    @klass.stub(:scoped_search_definition).and_return(@definition)
  end

  describe ScopedSearch::Definition::Field do
    describe '#initialize' do
      it "should raise an exception with missing field or 'on' keyword" do
        lambda {
          @definition.define
        }.should raise_error(ArgumentError, "Missing field or 'on' keyword argument")
      end

      it "should raise an exception with unknown keyword arguments" do
        lambda {
          @definition.define(:field, :nonexisting => 'foo')
        }.should raise_error(ArgumentError, "Unknown arguments to scoped_search: nonexisting")
      end

      it "should alias :in to :relation" do
        ActiveSupport::Deprecation.should_receive(:warn).with("'in' argument deprecated, prefer 'relation' since scoped_search 4.0.0", anything)
        @definition.define(:field, :in => 'foo').relation.should eq('foo')
      end

      it "should accept :relation" do
        ActiveSupport::Deprecation.should_not_receive(:warn)
        @definition.define(:field, :relation => 'foo').relation.should eq('foo')
      end

      it "should alias :alias to :aliases" do
        ActiveSupport::Deprecation.should_receive(:warn).with("'alias' argument deprecated, prefer aliases: [..] since scoped_search 4.0.0", anything)
        @definition.define(:field, :alias => 'foo')
        @definition.fields.keys.should eq([:field, :foo])
      end

      it "should accept :relation" do
        ActiveSupport::Deprecation.should_not_receive(:warn)
        @definition.define(:field, :aliases => ['foo'])
        @definition.fields.keys.should eq([:field, :foo])
      end
    end

    describe '#column' do
      it "should raise an exception when using an unknown field" do
        lambda {
          @definition.define(:on => 'nonexisting').column
        }.should raise_error(ActiveRecord::UnknownAttributeError)
      end

      it "should not raise an exception when using an unknown field" do
        lambda {
          @definition.define(:on => 'existing').column
        }.should_not raise_error
      end
    end
  end

  describe '#initialize' do
    it "should create the named scope when" do
      ScopedSearch::Definition.new(@klass)
      @klass.should respond_to(:search_for)
    end

    it "should not create the named scope if it already exists" do
      @klass.stub(:search_for)
      @klass.should_not_receive(:define_singleton_method)
      ScopedSearch::Definition.new(@klass)
    end
  end

  describe '#define_field' do
    it "should add to fields" do
      field = instance_double('ScopedSearch::Definition::Field')
      @definition.define_field('test', field)
      @definition.fields.should eq(test: field)
      @definition.unique_fields.should eq([field])
    end

    it "should add aliases" do
      field = instance_double('ScopedSearch::Definition::Field')
      @definition.define_field('test', field)
      @definition.define_field('alias', field)
      @definition.fields.should eq(test: field, alias: field)
      @definition.unique_fields.should eq([field])
    end

    it "should ignore duplicate field names" do
      field1 = instance_double('ScopedSearch::Definition::Field')
      field2 = instance_double('ScopedSearch::Definition::Field')
      @definition.define_field('test', field1)
      @definition.define_field('test', field2)
      @definition.fields.should eq(test: field1)
      @definition.unique_fields.should eq([field1, field2])
    end
  end

  describe '#fields' do
    before(:each) do
      @subklass      = mock_activerecord_subclass(@klass)
      @subdefinition = ScopedSearch::Definition.new(@subklass)
      @subdefinition.stub(:setup_adapter)
    end

    it "should return fields from class" do
      field = @definition.define(on: 'foo')
      @definition.fields.should eq(foo: field)
    end

    it "should return fields from parent class" do
      field = @definition.define(on: 'foo')
      @subdefinition.fields.should eq(foo: field)
    end

    it "should combine fields from class and parent class" do
      field1 = @definition.define(on: 'foo')
      field2 = @subdefinition.define(on: 'foo', only_explicit: true)
      field3 = @subdefinition.define(on: 'bar')
      @subdefinition.fields.should eq(foo: field2, bar: field3)
    end
  end
end
