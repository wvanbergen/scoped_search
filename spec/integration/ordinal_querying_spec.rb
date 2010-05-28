require 'spec_helper'

# These specs will run on all databases that are defined in the spec/database.yml file.
# Comment out any databases that you do not have available for testing purposes if needed.
ScopedSearch::Spec::Database.test_databases.each do |db|
  
  describe ScopedSearch, "using a #{db} database" do

    before(:all) do
      ScopedSearch::Spec::Database.establish_named_connection(db)

      @class = ScopedSearch::Spec::Database.create_model(:int => :integer, :timestamp => :datetime, :date => :date, :unindexed => :integer) do |klass|
        klass.scoped_search :on => [:int, :timestamp]
        klass.scoped_search :on => :date, :only_explicit => true
      end
    end

    after(:all) do
      ScopedSearch::Spec::Database.drop_model(@class)
      ScopedSearch::Spec::Database.close_connection
    end

    context 'quering numerical fields' do

      before(:all) do
        @record = @class.create!(:int =>  9)
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

    context 'querying unindexed fields' do

      before(:all) do
        @record = @class.create!(:int =>  9, :unindexed => 10)
      end

      after(:all) do
        @record.destroy
      end

      it "should raise an error when explicitly searching in the non-indexed column" do
        lambda { @class.search_for('unindexed = 10') }.should raise_error(ScopedSearch::Exception)
      end

      it "should not return records for which the query matches unindex records" do
        @class.search_for('= 10').should have(0).item
      end
    end

    context 'querying date and time fields' do

      before(:all) do
        @record = @class.create!(:timestamp => Time.parse('2009-01-02 14:51:44'), :date => Date.parse('2009-01-02'))
        @nil_record = @class.create!(:timestamp => nil, :date => nil)
      end

      after(:all) do
        @record.destroy
        @nil_record.destroy
      end

      it "should accept YYYY-MM-DD as date format" do
        @class.search_for('date = 2009-01-02').should have(1).item
      end

      it "should accept YY-MM-DD as date format" do
        @class.search_for('date = 09-01-02').should have(1).item
      end

      it "should accept MM/DD/YY as date format" do
        @class.search_for('date = 01/02/09').should have(1).item
      end

      it "should accept YYYY/MM/DD as date format" do
        @class.search_for('date = 2009/01/02').should have(1).item
      end

      it "should accept MM/DD/YYYY as date format" do
        @class.search_for('date = 01/02/2009').should have(1).item
      end

      it "should ignore an invalid date and thus return all records" do
        @class.search_for('>= 2009-14-57').should have(2).items
      end

      it "should find the records with a timestamp set some point on the provided date" do
        @class.search_for('>= 2009-01-02').should have(1).item
      end

      it "should support full timestamps" do
        @class.search_for('> "2009-01-02 02:02:02"').should have(1).item
      end

      it "should find no record with a timestamp in the past" do
        @class.search_for('< 2009-01-02').should have(0).item
      end

      it "should find all timestamps on a date if no time is given using the = operator" do
        @class.search_for('= 2009-01-02').should have(1).item
      end

      it "should find all timestamps on a date if no time is when no operator is given" do
        @class.search_for('2009-01-02').should have(1).item
      end

      it "should find all timestamps not on a date if no time is given using the != operator" do
        @class.search_for('!= 2009-01-02').should have(0).item
      end

      it "should find the records when the date part of a timestamp matches a date" do
        @class.search_for('>= 2009-01-02').should have(1).item
      end

      it "should find the record with the timestamp today or in the past" do
        @class.search_for('<= 2009-01-02').should have(1).item
      end

      it "should find no record with a timestamp later than today" do
        @class.search_for('> 2009-01-02').should have(0).item
      end
    end
  end
end
