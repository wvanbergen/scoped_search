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

  context 'for unprepared ActiveRecord model' do

    it "should respond to :scoped_search to setup scoped_search for the model" do
      Class.new(ActiveRecord::Base).should respond_to(:scoped_search)
    end
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

    if ActiveRecord::VERSION::MAJOR == 3
      it "should return a ActiveRecord::Relation instance" do
        @class.search_for('query').class.should eql(ActiveRecord::Relation)
      end

    elsif ActiveRecord::VERSION::MAJOR == 4
      it "should return a ActiveRecord::Relation instance" do
        @class.search_for('query').class.superclass.should eql(ActiveRecord::Relation)
      end
    end
  end
end
