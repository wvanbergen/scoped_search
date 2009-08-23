require "#{File.dirname(__FILE__)}/../spec_helper"

describe ScopedSearch, :search_for do

  before(:all) do
    ScopedSearch::Spec::Database.establish_connection
  end

  after(:all) do
    ScopedSearch::Spec::Database.close_connection
  end

  context 'ordinal' do

    before(:all) do
      @class = ScopedSearch::Spec::Database.create_model(:int => :integer, :timestamp => :datetime, :unindexed => :integer) do |klass|
        klass.scoped_search do |search|
          search.on :int
          search.on :timestamp
        end
      end
    end

    after(:all) do
      ScopedSearch::Spec::Database.drop_model(@class)
    end

    context 'integer field' do

      before(:all) do
        @record = @class.create!(:int =>  9, :timestamp => Time.now, :unindexed => 10)
      end

      after(:all) do
        @record.destroy
      end

      it "should find the record with an exact integer match" do
        @class.search_for('9').should have(1).item
      end

      it "should find the record with an exact integer match with an explicit operator" do
        @class.search_for('= 9').should have(1).item
      end

      it "should find the record with an exact integer match with an explicit field name" do
        @class.search_for('int = 9').should have(1).item
      end

      it "should find the record with an exact integer match with an explicit field name" do
        @class.search_for('int > 8').should have(1).item
      end

      it "should find the record with a grater than operator and explicit field" do
        @class.search_for('int > 9').should have(0).item
      end

      it "should find the record with an >= operator with an implicit field name" do
        @class.search_for('>= 9').should have(1).item
      end

      it "should not return the record if only one predicate is true and AND is used (by default)" do
        @class.search_for('int <= 8, int > 8').should have(0).item
      end

      it "should return the record in only one predicate is true and OR is used as operator" do
        @class.search_for('int <= 8 || int > 8').should have(1).item
      end
    end

    context 'unindexed field' do

      before(:all) do
        @record = @class.create!(:int =>  9, :timestamp => Time.now, :unindexed => 10)     
      end

      after(:all) do
        @record.destroy
      end

      it "searching in the non-index column should raise an error" do
        lambda { @class.search_for('unindexed = 10') }.should raise_error(ScopedSearch::Exception)
      end

      it "searching for the value of the unindexed field should return nothing" do
        @class.search_for('= 10').should have(0).item
      end
    end

    context 'datetime field' do

      before(:all) do
        @record = @class.create!(:int =>  9, :timestamp => Time.now, :unindexed => 10)
        @record = @class.create!(:int =>  9, :timestamp => nil,      :unindexed => 10)
      end

      after(:all) do
        @record.destroy
      end

      it "should find the records with a timestamp set today" do
        @class.search_for('>= %s' % Date.today.strftime('%Y-%m-%d')).should have(1).item
      end

      it "should find no record with a timestamp in the past" do
        @class.search_for('< %s' % Date.today.strftime('%Y-%m-%d')).should have(0).item
      end

      it "should find the record with the timestamp today or in the past" do
        pending do
          @class.search_for('<= %s' % Date.today.strftime('%Y-%m-%d')).should have(1).item
        end
      end

      it "should find no record with a timestamp later than today" do
        pending do
          @class.search_for('> %s' % Date.today.strftime('%Y-%m-%d')).should have(0).item
        end
      end

    end
  end
end
