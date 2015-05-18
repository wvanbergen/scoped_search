require "spec_helper"

# These specs will run on all databases that are defined in the spec/database.yml file.
# Comment out any databases that you do not have available for testing purposes if needed.
ScopedSearch::RSpec::Database.test_databases.each do |db|

  describe ScopedSearch, "using a #{db} database" do

    before(:all) do
      ScopedSearch::RSpec::Database.establish_named_connection(db)

      @class = ScopedSearch::RSpec::Database.create_model(:int => :integer, :dec => :decimal ,:timestamp => :datetime, :date => :date, :unindexed => :integer) do |klass|
        klass.scoped_search :on => [:int, :dec, :timestamp]
        klass.scoped_search :on => :date, :only_explicit => true
      end
    end

    after(:all) do
      ScopedSearch::RSpec::Database.drop_model(@class)
      ScopedSearch::RSpec::Database.close_connection
    end

    context 'querying numerical fields' do

      before(:all) do
        @record = @class.create!(:int =>  9, :dec => 1.23)
      end

      after(:all) do
        @record.destroy
      end

      it "should find the record with an exact integer match" do
        @class.search_for('9').length.should == 1
      end

      it "should find the record with an exact decimal match" do
        @class.search_for('1.23').length.should == 1
      end

      it "should find the record with an exact integer match with an explicit operator" do
        @class.search_for('= 9').length.should == 1
      end

      it "should find the record with an exact integer match with an explicit field name" do
        @class.search_for('int = 9').length.should == 1
      end

      it "should find the record with an exact integer match with an explicit field name" do
        @class.search_for('int > 8').length.should == 1
      end

      it "should find the record with a grater than operator and explicit field" do
        @class.search_for('int > 9').length.should == 0
      end

      it "should find the record with an >= operator with an implicit field name" do
        @class.search_for('>= 9').length.should == 1
      end

      it "should not return the record if only one predicate is true and AND is used (by default)" do
        @class.search_for('int <= 8, int > 8').length.should == 0
      end

      it "should return the record in only one predicate is true and OR is used as operator" do
        @class.search_for('int <= 8 || int > 8').length.should == 1
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

      # Before Ruby 2.0 if a string had forced encoding and a nil was extracted from it during
      # any implicit type conversions to a string (+ or << operators) a TypeError would be raised.
      # https://github.com/wvanbergen/scoped_search/issues/33 for more details
      it "encoded string should not raise TypeError when querying non-indexed column without a value" do
        query = 'unindexed ='.force_encoding(Encoding::UTF_8).encode
        lambda { @class.search_for(query) }.should_not raise_error
      end

      it "should not return records for which the query matches unindex records" do
        @class.search_for('= 10').length.should == 0
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
        @class.search_for('date = 2009-01-02').length.should == 1
      end

      it "should accept YY-MM-DD as date format" do
        @class.search_for('date = 09-01-02').length.should == 1
      end

      if RUBY_VERSION.to_f == 1.8
        it "should accept MM/DD/YY as date format" do
          @class.search_for('date = 01/02/09').length.should == 1
        end

        it "should accept MM/DD/YYYY as date format" do
          @class.search_for('date = 01/02/2009').length.should == 1
        end
      end

      it "should accept YYYY/MM/DD as date format" do
        @class.search_for('date = 2009/01/02').length.should == 1
      end

      it "should ignore an invalid date and thus return all records" do
        @class.search_for('>= 2009-14-57').count.should == 2
      end

      it "should find the records with a timestamp set some point on the provided date" do
        @class.search_for('>= 2009-01-02').length.should == 1
      end

      it "should find the records with LTE with a timestamp set on the provided date" do
        @class.search_for('<= 2009-01-02').length.should == 1
      end

      it "should support full timestamps" do
        @class.search_for('> "2009-01-02 02:02:02"').length.should == 1
      end

      it "should support full timestamp shortly before the record" do
        @class.search_for('> "2009-01-02 14:51:02"').length.should == 1
      end

      it "should find no record with a timestamp in the past" do
        @class.search_for('< 2009-01-02').length.should == 0
      end

      it "should find all timestamps on a date if no time is given using the = operator" do
        @class.search_for('= 2009-01-02').length.should == 1
      end

      it "should find all timestamps on a date if no time is when no operator is given" do
        @class.search_for('2009-01-02').length.should == 1
      end

      it "should find all timestamps not on a date if no time is given using the != operator" do
        @class.search_for('!= 2009-01-02').length.should == 0
      end

      it "should find the records when the date part of a timestamp matches a date" do
        @class.search_for('>= 2009-01-02').length.should == 1
      end

      it "should find the record with the timestamp today or in the past" do
        @class.search_for('<= 2009-01-02').length.should == 1
      end

      it "should find no record with a timestamp later than today" do
        @class.search_for('> 2009-01-02').length.should == 0
      end

    end

    context 'humanized date and time query' do

      before(:all) do
        @current_record = @class.create!(:timestamp => Time.current, :date => Date.current)
        @min_ago_record = @class.create!(:timestamp => Time.current - 1.minute, :date => Date.current)
        @hour_ago_record = @class.create!(:timestamp => Time.current - 1.hour, :date => Date.current)
        @day_ago_record = @class.create!(:timestamp => Time.current - 1.day, :date => Date.current - 1.day)
        @month_ago_record = @class.create!(:timestamp => Time.current - 1.month, :date => Date.current - 1.month)
        @year_ago_record = @class.create!(:timestamp => Time.current - 1.year, :date => Date.current - 1.year)
      end

      after(:all) do
        @current_record.destroy
        @min_ago_record.destroy
        @hour_ago_record.destroy
        @day_ago_record.destroy
        @month_ago_record.destroy
        @year_ago_record.destroy
      end

      it "should accept Today as date format" do
        @class.search_for('date = Today').length.should == 3
      end

      it "should accept Yesterday as date format" do
        @class.search_for('date = yesterday').length.should == 1
      end

      it "should find all timestamps and date from today using the = operator" do
        @class.search_for('= Today').length.should == 3
      end

      it "should find all timestamps and date from today no operator" do
        @class.search_for('Today').length.should == 3
      end

      it "should accept 2 days ago as date format" do
        @class.search_for('date < "2 days ago"').length.should == 2
      end

      it "should accept 3 minutes ago as date format" do
        @class.search_for('timestamp > "3 minutes ago"').length.should == 2
      end

      it "should accept 3 hours ago as date format" do
        @class.search_for('timestamp > "3 hours ago"').length.should == 3
      end

      it "should accept 1 month ago as date format" do
        @class.search_for('date > "1 month ago"').length.should == 4
      end

      it "should accept 1 year ago as date format" do
        @class.search_for('date > "1 year ago"').length.should == 5
      end

    end

    context 'querying bitwise fields' do

      before(:all) do
        @foo = ScopedSearch::RSpec::Database.create_model(:int => :integer) do |klass|
          klass.scoped_search :on => :int, :offset => 0, :word_size => 8, :rename => :first
          klass.scoped_search :on => :int, :offset => 1, :word_size => 8, :rename => :sec
        end
        # 1026 => is first = 2 and sec = 4
        @record = @foo.create!(:int =>  1026)
      end

      after(:all) do
        ScopedSearch::RSpec::Database.drop_model(@foo)
      end

      it "should not find any record because first equal = 2" do
        @foo.search_for('first = 4').length.should == 0
      end

      it "should find the record" do
        @foo.search_for('first = 2').length.should == 1
      end

      it "should not find any record with a grater than operator" do
        @foo.search_for('first > 9').length.should == 0
      end

      it "should find the record with an >= operator" do
        @foo.search_for('sec >= 4').length.should == 1
      end

      it "should find the record with AND operator is used" do
        @foo.search_for('sec <= 8 and first = 2').length.should == 1
      end

      it "should return the record in if one predicate is true and OR is used as operator" do
        @foo.search_for('sec <= 8 || first > 8').length.should == 1
      end
    end
  end
end
