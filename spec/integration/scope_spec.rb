require "spec_helper"

# These specs will run on all databases that are defined in the spec/database.yml file.
# Comment out any databases that you do not have available for testing purposes if needed.
ScopedSearch::RSpec::Database.test_databases.each do |db|

  describe ScopedSearch, "using a #{db} database" do

    before(:all) do
      ScopedSearch::RSpec::Database.establish_named_connection(db)

      @class = ScopedSearch::RSpec::Database.create_model(:field => :string) do |klass|
        klass.scoped_search :on => :field
      end
    end

    after(:all) do
      ScopedSearch::RSpec::Database.drop_model(@class)
      ScopedSearch::RSpec::Database.close_connection
    end

    context '.search_for' do
      it "should respect existing scope" do
        @class.create! field: 'a'
        record = @class.create! field: 'ab'
        @class.where(field: 'ab').search_for('field ~ a').should eq([record])
      end
    end
  end
end
