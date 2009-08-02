require "#{File.dirname(__FILE__)}/../spec_helper"

describe ScopedSearch, :search_for do
  
  
  before(:all) do
    ScopedSearch::Spec::Database.establish_connection
  end

  after(:all) do
    ScopedSearch::Spec::Database.close_connection    
  end
  
  context 'string fields' do
    
    before(:all) do
      @class = ScopedSearch::Spec::Database.create_model(:string => :string, 
        :another => :string, :unindexed => :unindexed_string)
      
      @class.create!(:string => 'foo', :another => 'temp 1', :unindexed =>'baz')
      @class.create!(:string => 'bar', :another => 'temp 2', :unindexed =>'baz')      
      @class.create!(:string => 'baz', :another => 'temp 3', :unindexed =>'baz')      
    end
    
    after(:all) do
      ScopedSearch::Spec::Database.drop_model(@class)
    end
  
    it "should find the record with an exact string match" do
      @class.search_for('foo').should have(1).item
    end

    it "should find the record with an exact string match and an explicit field operator" do
      @class.search_for('string = foo').should have(1).item
    end

    it "should find the record with an exact string match and an explicit field operator" do
      @class.search_for('another = foo').should have(0).items
    end
    
    it "should find the record with an partial string match" do
      @class.search_for('fo').should have(1).item
    end

    it "should not find the record with an explicit equals operator and a partial match" do
      @class.search_for('= fo').should have(0).items
    end

    it "should not find a record with a non-match" do
      @class.search_for('nonsense').should have(0).items
    end        

    it "should find two records if it partially matches them" do
      @class.search_for('ba').should have(2).item
    end  
    
    it "should find the record if one of the query words match using OR" do
      @class.search_for('foo OR nonsense').should have(1).item
    end  
    
    it "should find no records in one of the AND conditions isn't met" do
      @class.search_for('foo AND nonsense').should have(0).item
    end  

    it "should find two records every single OR conditions matches one single record" do
      @class.search_for('foo OR baz').should have(2).item
    end  

    it "should find two records every single AND conditions matches one single record" do
      @class.search_for('foo AND baz').should have(0).item
    end  
  end
end
