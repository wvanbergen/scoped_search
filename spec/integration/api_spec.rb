require "#{File.dirname(__FILE__)}/../spec_helper"

describe ScopedSearch, "API - " do
  
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
    ScopedSearch::Spec::Database.establish_connection
  end

  after(:all) do
    ScopedSearch::Spec::Database.close_connection    
  end  
  
  context 'An unprepared ActiveRecord model' do
    
    it "should respond to :searchable_on to setup scoped_search for the model" do
      Class.new(ActiveRecord::Base).should respond_to(:searchable_on)
    end
  end
  
  context 'A prepared ActiveRecord model' do
    
    before(:all) do
      @class = ScopedSearch::Spec::Database.create_model(:field => :string)    
    end
    
    after(:all) do
      ScopedSearch::Spec::Database.drop_model(@class)    
    end
    
    it "should respond to :search_for to perform searches" do
      @class.should respond_to(:search_for)
    end
    
    it "should return an ActiveRecord::NamedScope::Scope when :search_for is called" do
      @class.search_for('query').class.should eql(ActiveRecord::NamedScope::Scope)
    end
  end
  
end
