require "spec_helper"

# These specs will run on all databases that are defined in the spec/database.yml file.
# Comment out any databases that you do not have available for testing purposes if needed.
ScopedSearch::RSpec::Database.test_databases.each do |db|

  describe ScopedSearch, "using a #{db} database" do

    before(:all) do
      ScopedSearch::RSpec::Database.establish_named_connection(db)

      @parent_class = ScopedSearch::RSpec::Database.create_model(int: :integer, type: :string) do |klass|
        klass.scoped_search on: :int
      end
      @subclass1 = ScopedSearch::RSpec::Database.create_sti_model(@parent_class)
      @subclass2 = ScopedSearch::RSpec::Database.create_sti_model(@parent_class)
    end

    after(:all) do
      ScopedSearch::RSpec::Database.drop_model(@parent_class)
      ScopedSearch::RSpec::Database.close_connection
    end

    context 'querying STI parent and subclasses' do
      before(:all) do
        @record1 = @subclass1.create!(int: 7)
        @record2 = @subclass2.create!(int: 9)
      end

      after(:all) do
        @record1.destroy
        @record2.destroy
      end

      it "should find a record using the parent class" do
        @parent_class.search_for('int = 7').should eq([@record1])
      end

      it "should find a record using the subclass" do
        @subclass1.search_for('int = 7').should eq([@record1])
      end

      it "should not find a record using the wrong subclass" do
        @subclass2.search_for('int = 7').should eq([])
      end
    end
  end
end
