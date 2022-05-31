require "spec_helper"

# These specs will run on all databases that are defined in the spec/database.yml file.
# Comment out any databases that you do not have available for testing purposes if needed.
ScopedSearch::RSpec::Database.test_databases.each do |db|

  describe ScopedSearch, "using a #{db} database" do

    before(:all) do
      ScopedSearch::RSpec::Database.establish_named_connection(db)

      @class = ScopedSearch::RSpec::Database.create_model(:bool => :boolean, :status => :integer) do |klass|
        klass.scoped_search :on => :bool, :complete_value => {:yes => true, :no => false}
        klass.scoped_search :on => :status, :complete_value => {:unknown => 0, :up => 1, :down => 2}
        klass.scoped_search :on => :bool, :rename => :bool2, :complete_value => {:true => true, :false => false}
      end
    end

    after(:all) do
      ScopedSearch::RSpec::Database.drop_model(@class)
      ScopedSearch::RSpec::Database.close_connection
    end

    context 'querying boolean fields' do

      before(:all) do
        @record1 = @class.create!(:status => 0)
        @record2 = @class.create!(:status => 1)
        @record3 = @class.create!(:status => 2)
      end

      after(:all) do
        @record1.destroy
        @record2.destroy
        @record3.destroy
      end

      it "should find the record status = 1" do
        @class.search_for('status = up').length.should == 1
      end

      it "should find the record with status = 0" do
        @class.search_for('status = unknown').length.should == 1
      end

      it "should find two record with status != 1" do
        @class.search_for('status != up').length.should == 2
      end
    end
    context 'querying boolean fields' do

      before(:all) do
        @record1 = @class.create!(:bool => true)
        @record2 = @class.create!(:bool => false)
        @record3 = @class.create!(:bool => false)
      end

      after(:all) do
        @record1.destroy
        @record2.destroy
        @record3.destroy
      end

      it "should find the record bool = true" do
        @class.search_for('bool = yes').length.should == 1
      end

      it "should find two record with bool = false" do
        @class.search_for('bool = no').length.should == 2
      end

      it "should find two record with bool = false" do
        @class.search_for('bool != yes').length.should == 2
      end

      it "should be able to search without value" do
        @class.search_for('bool').length.should == 1
        @class.search_for('bool2').length.should == 1
      end
    end
  end
end
