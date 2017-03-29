require "spec_helper"

describe ScopedSearch, "API" do

  # This spec requires the API to be stable, so that projects using
  # scoped_search do not have to update their code if a new (minor)
  # version is released.
  #
  # API compatibility is only guaranteed for minor version changes;
  # New major versions may change the API and require code changes
  # in projects using this plugin.
  #
  # Because of the API stability guarantee, these spec's may only
  # be changed for new major releases.

  before(:all) do
    ScopedSearch::RSpec::Database.establish_connection
  end

  after(:all) do
    ScopedSearch::RSpec::Database.close_connection
  end

  context 'for a prepared ActiveRecord model' do

    before(:all) do
      @class = ScopedSearch::RSpec::Database.create_model(:field => :string) do |klass|
        klass.scoped_search :on => :field
      end
    end

    after(:all) do
      ScopedSearch::RSpec::Database.drop_model(@class)
    end

    it "should respond to :search_for to perform searches" do
      @class.should respond_to(:search_for)
    end

    it "should return a ActiveRecord::Relation instance with no arguments" do
      @class.search_for.should be_a(ActiveRecord::Relation)
    end

    it "should return a ActiveRecord::Relation instance with one argument" do
      @class.search_for('query').should be_a(ActiveRecord::Relation)
    end

    it "should return a ActiveRecord::Relation instance with two arguments" do
      @class.search_for('query', {}).should be_a(ActiveRecord::Relation)
    end

    it "should respect existing scope" do
      @class.create! field: 'a'
      record = @class.create! field: 'ab'
      @class.where(field: 'ab').search_for('field ~ a').should eq([record])
    end
  end
end
