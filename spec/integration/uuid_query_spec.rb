require "spec_helper"
require 'securerandom'

# These specs will run on all databases that are defined in the spec/database.yml file.
# Comment out any databases that you do not have available for testing purposes if needed.
ScopedSearch::RSpec::Database.test_databases.each do |db|
  describe ScopedSearch, "using a #{db} database" do
    before(:all) do
      ScopedSearch::RSpec::Database.establish_named_connection(db)

      columns = on_postgresql? ? { :uuid => :uuid } : { :uuid => :string }

      @class = ScopedSearch::RSpec::Database.create_model(columns.merge(:string => :string)) do |klass|
        klass.scoped_search :on => :uuid
        klass.scoped_search :on => :string
      end
    end

    after(:all) do
      ScopedSearch::RSpec::Database.drop_model(@class)
      ScopedSearch::RSpec::Database.close_connection
    end

    context 'querying boolean fields' do

      before(:all) do
        @record1 = @class.create!(:uuid => SecureRandom.uuid)
        @record2 = @class.create!(:uuid => SecureRandom.uuid)
        @record3 = @class.create!(:uuid => SecureRandom.uuid)
      end

      after(:all) do
        @record1.destroy
        @record2.destroy
        @record3.destroy
      end

      it "should find the first record" do
        @class.search_for("uuid = #{@record1.uuid}").length.should == 1
      end

      it "should find two records with negative match" do
        @class.search_for("uuid != #{@record3.uuid}").length.should == 2
      end

      it "should find a record by just specifying the uuid" do
        @class.search_for(@record1.uuid).first.uuid.should == @record1.uuid
      end

      it "should not find a record if the uuid is not a valid uuid" do
        if on_postgresql?
          @class.search_for(@record1.uuid[0..-2]).length.should == 0
        end
      end
    end
  end
end
