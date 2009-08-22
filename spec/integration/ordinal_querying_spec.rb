require "#{File.dirname(__FILE__)}/../spec_helper"

describe ScopedSearch, :search_for do
  
  
  before(:all) do
    ScopedSearch::Spec::Database.establish_connection
  end

  after(:all) do
    ScopedSearch::Spec::Database.close_connection    
  end
  
  context 'ordinal fields' do
    
    before(:all) do
      @class = ScopedSearch::Spec::Database.create_model(:int => :integer, 
        :timestamp => :datetime, :unindexed => :unindexed_integer)
      
      @class.create!(:int =>  9, :timestamp => Time.now, :unindexed => 10)
      @class.create!(:int => 10, :timestamp => Time.now, :unindexed => 10)      
      @class.create!(:int => 11, :timestamp => nil,      :unindexed => 10)      
    end
    
    after(:all) do
      ScopedSearch::Spec::Database.drop_model(@class)
    end
  
    it "should find the record with an exact integer match" do
      @class.search_for('9').should have(1).item
    end
    
    it "should find the record with an exact integer match with an explicit operator" do
      @class.search_for('= 9').should have(1).item
    end    
    
    it "should find the record with an exact integer match with an explicit field name" do
      @class.search_for('int = 9').should have(1).item
    end    
    
    it "should only find the record with an exact integer match in the indexed column" do
      @class.search_for('10').should have(1).item
    end
    
    it "should only find the only record with int == 11" do
      @class.search_for('> 10').should have(1).item
    end
    
    it "should only find the two record with int == [10, 11]" do
      @class.search_for('>= 10').should have(2).item
    end
    
    it "should find only two records with a timestamp set" do
      @class.search_for('>= %s' % Date.today.strftime('%Y-%m-%d')).should have(2).item
    end   
    
    it "should find no record with a timestamp in the past" do
      @class.search_for('< %s' % Date.today.strftime('%Y-%m-%d')).should have(0).item
    end     
    
    it "searching in the non-index column should raise an error" do
      lambda { @class.search_for('unindexed = 10') }.should raise_error
    end    

  end
end
