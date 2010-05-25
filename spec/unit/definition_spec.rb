require "#{File.dirname(__FILE__)}/../spec_helper"

describe ScopedSearch::Definition do

  before(:each) do
    @klass      = mock_activerecord_class
    @definition = ScopedSearch::Definition.new(@klass)
    @definition.stub!(:setup_adapter)
  end


  describe '#initialize' do

    if ActiveRecord::VERSION::MAJOR == 2
      
      it "should create the named scope when" do
        @klass.should_receive(:named_scope).with(:search_for, instance_of(Proc))
        ScopedSearch::Definition.new(@klass)
      end

      it "should not create the named scope if it already exists" do
        @klass.stub!(:search_for)
        @klass.should_not_receive(:named_scope)
        ScopedSearch::Definition.new(@klass)
      end
      
    elsif ActiveRecord::VERSION::MAJOR == 3
      
      it "should create the named scope when" do
        @klass.should_receive(:scope).with(:search_for, instance_of(Proc))
        ScopedSearch::Definition.new(@klass)
      end

      it "should not create the named scope if it already exists" do
        @klass.stub!(:search_for)
        @klass.should_not_receive(:scope)
        ScopedSearch::Definition.new(@klass)
      end
      
    end
  end
end
