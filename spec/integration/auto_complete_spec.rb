require 'spec_helper'

# These specs will run on all databases that are defined in the spec/database.yml file.
# Comment out any databases that you do not have available for testing purposes if needed.
ScopedSearch::RSpec::Database.test_databases.each do |db|

  describe ScopedSearch, "using a #{db} database" do

    before(:all) do
      ScopedSearch::RSpec::Database.establish_named_connection(db)
    
      @class = ScopedSearch::RSpec::Database.create_model(:string => :string, :another => :string, :explicit => :string, :int => :integer, :date => :date, :unindexed => :integer) do |klass|
        klass.scoped_search :on => [:string, :int]
        klass.scoped_search :on => :another,  :default_operator => :eq, :alias => :alias
        klass.scoped_search :on => :explicit, :only_explicit => true
        klass.scoped_search :on => :date, :only_explicit => true

      end

      @class.create!(:string => 'foo', :another => 'temp 1', :explicit => 'baz', :int => 9  , :date => 'February 8, 20011' , :unindexed => 10)
      @class.create!(:string => 'bar', :another => 'temp 2', :explicit => 'baz', :int => 9  , :date => 'February 10, 20011', :unindexed => 10)
      @class.create!(:string => 'baz', :another => nil,      :explicit => nil  , :int => nil, :date => nil                 , :unindexed => nil)

    end

    after(:all) do
      ScopedSearch::RSpec::Database.drop_model(@class)
      ScopedSearch::RSpec::Database.close_connection
    end

    context 'basic auto completer' do
      it "should complete the field name" do
        @class.complete_for('str').should eql([' string'])
      end

       it "should not complete the logical operators at the beginning" do
        @class.complete_for('a').should_not contain([' and'])
      end

      it "should complete the string comparators" do
        @class.complete_for('string ').should =~ (["string !=", "string !~", "string =", "string ~"])
      end

      it "should complete the numerical comparators" do
        @class.complete_for('int ').should =~ (["int !=", "int <", "int <=", "int =", "int >", "int >="])
      end

      it "should complete the temporal (date) comparators" do
        @class.complete_for('date ').should =~ (["date =", "date <", "date >"])
      end

      it "should raise error for unindexed field" do
        lambda { @class.complete_for('unindexed = 10 ')}.should raise_error(ScopedSearch::QueryNotSupported)
      end

      it "should raise error for unknown field" do
        lambda {@class.complete_for('unknown = 10 ')}.should raise_error(ScopedSearch::QueryNotSupported)
      end

      it "should complete logical comparators" do
        @class.complete_for('string ~ fo ').should contain("string ~ fo and", "string ~ fo or", "string ~ fo not")
      end

      it "should complete prefix operators" do
        @class.complete_for(' ').should contain(" has", " not")
      end

      it "should not complete logical infix operators" do
        @class.complete_for(' ').should_not contain(" and", " or")
      end

      it "should not repeat logical operators" do
        @class.complete_for('string = foo and ').should_not contain("string = foo and and", "string = foo and or")
      end
    end

    context 'using an aliased field' do
      it "should complete an explicit match using its alias" do
        @class.complete_for('al').should contain(' alias')
      end
    end

    context 'using null prefix operators queries' do

      it "should complete has operator" do
        @class.complete_for('has strin').should eql(['has string'])
      end

      it "should complete null? operator" do
        @class.complete_for('null? st').should eql(['null? string'])
      end

      it "should complete set? operator" do
        @class.complete_for('set? exp').should eql(['set? explicit'])
      end

      it "should complete null? operator for explicit field" do
        @class.complete_for('null? explici').should eql(['null? explicit'])
      end

       it "should not complete comparators after prefix statement" do
        @class.complete_for('has string ').should_not contain(['has string ='])
      end
    end
  end
end
