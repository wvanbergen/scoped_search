require "#{File.dirname(__FILE__)}/../spec_helper"

# These specs will run on all databases that are defined in the spec/database.yml file.
# Comment out any databases that you do not have available for testing purposes if needed.
ScopedSearch::RSpec::Database.test_databases.each do |db|

  describe ScopedSearch, "using a #{db} database" do

    before(:all) do
      ScopedSearch::RSpec::Database.establish_named_connection(db)
    
      @class = ScopedSearch::RSpec::Database.create_model(:public => :string, :private => :string, :useless => :string) do |klass|
        klass.scoped_search :on => :public
        klass.scoped_search :on => :private, :profile => :private_profile
        klass.scoped_search :on => :useless, :profile => :another_profile
      end

      @item1 = @class.create!(:public => 'foo', :private => 'bar', :useless => 'boo')
      @item2 = @class.create!(:public => 'qwerty', :private => 'foo', :useless => 'cool')
      @item3 = @class.create!(:public => 'asdf', :private => 'blargh', :useless => 'foo')
    end

    after(:all) do
      ScopedSearch::RSpec::Database.drop_model(@class)
      ScopedSearch::RSpec::Database.close_connection
    end

    context "searching without profile specified" do
      before(:each) do
        @results = @class.search_for('foo')
      end
      
      it "should find results on column specified" do
        @results.should include(@item1)
      end
        
      it "should not find results on columns only specified with a given profile" do
        @results.should_not include(@item2)
      end
    end

    context "searching with profile specified" do
      before(:each) do
        @results = @class.search_for('foo', :profile => :private_profile)
      end
      
      # it "should find results on columns indexed w/o profile" do
      #   @results.should include(@item1)
      # end
      
      it "should find results on column indexed with specified profile" do
        @results.should include(@item2)
      end
      
      it "should not find results on a column indexed with a different profile" do
        @results.should_not include(@item3)
      end
    end

  end
end
