require "#{File.dirname(__FILE__)}/../spec_helper"

describe ScopedSearch, :search_for do

  before(:all) do
    ScopedSearch::Spec::Database.establish_connection
    @class = ScopedSearch::Spec::Database.create_model(:string => :string, :another => :string, :explicit => :string) do |klass|
      klass.scoped_search.on :string
      klass.scoped_search.on :another,  :default_operator => :eq, :alias => :alias      
      klass.scoped_search.on :explicit, :only_explicit => true
    end
    
    @class.create!(:string => 'foo', :another => 'temp 1', :explicit => 'baz')
    @class.create!(:string => 'bar', :another => 'temp 2', :explicit => 'baz')      
    @class.create!(:string => 'baz', :another => 'temp 3', :explicit => 'baz')      
  end
    
  after(:all) do
    ScopedSearch::Spec::Database.drop_model(@class)
    ScopedSearch::Spec::Database.close_connection 
  end
  
  context 'in an implicit string field' do
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

    it "should find the record with an explicit LIKE operator and a partial match" do
      @class.search_for('~ fo').should have(1).items
    end
    
    it "should find the all other record with an explicit NOT LIKE operator and a partial match" do
      @class.search_for('string !~ fo').should have(@class.count - 1).items
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
  
  context 'in a field with a different default operator' do
    it "should find an exact match" do
      @class.search_for('"temp 1"').should have(1).item
    end

    it "should find an explicit match" do
      @class.search_for('another = "temp 1"').should have(1).item
    end
    
    it "should not find a partial match" do
      @class.search_for('temp').should have(0).item
    end    

    it "should find a partial match when the like operator is given" do
      @class.search_for('~ temp').should have(3).item
    end
    
    it "should find a partial match when the like operator and the field name is given" do
      @class.search_for('another ~ temp').should have(3).item
    end
  end
  
  context 'using an aliased field' do
    it "should find an explicit match using its alias" do
      @class.search_for('alias = "temp 1"').should have(1).item
    end   
  end

  context 'in an explicit string field' do

    it "should not find the records if the explicit field is not given in the query" do
      @class.search_for('= baz').should have(1).item
    end

    it "should find all records when searching on the explicit field" do
      @class.search_for('explicit = baz').should have(3).item
    end

    it "should find no records if the value in the explicit field is not an exact match" do
      @class.search_for('explicit = ba').should have(0).item
    end

    it "should find all records when searching on the explicit field" do
      @class.search_for('explicit ~ ba').should have(3).item
    end
    
    it "should only find the record with string = foo and explicit = baz" do
      @class.search_for('foo, explicit = baz').should have(1).item
    end
    

  end
end
