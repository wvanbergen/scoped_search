require "#{File.dirname(__FILE__)}/../spec_helper"

# These specs will run on all databases that are defined in the spec/database.yml file.
# Comment out any databases that you do not have available for testing purposes if needed.
ScopedSearch::RSpec::Database.test_databases.each do |db|

  describe ScopedSearch, "using a #{db} database" do

    before(:all) do
      ScopedSearch::RSpec::Database.establish_named_connection(db)

      ## The related class
      ActiveRecord::Migration.drop_table(:bars) rescue nil
      ActiveRecord::Migration.create_table(:bars) { |t| t.string :related; t.integer :foo_id }
      class ::Bar < ActiveRecord::Base; belongs_to :foo; end

      ::Foo = ScopedSearch::RSpec::Database.create_model(:string => :string, :another => :string, :explicit => :string, :int => :integer, :date => :date, :unindexed => :integer) do |klass|
        klass.has_many :bars
        
        klass.scoped_search :on => [:string, :int, :date]
        klass.scoped_search :on => :another,  :default_operator => :eq, :alias => :alias
        klass.scoped_search :on => :explicit, :only_explicit => true, :complete_value => true
        klass.scoped_search :on => :related, :in => :bars, :rename => 'bars.related'.to_sym
        
      end

      @foo_1 = Foo.create!(:string => 'foo', :another => 'temp 1', :explicit => 'baz', :int => 9  , :date => 'February 8, 20011' , :unindexed => 10)
      Foo.create!(:string => 'bar', :another => 'temp 2', :explicit => 'baz', :int => 9  , :date => 'February 10, 20011', :unindexed => 10)
      Foo.create!(:string => 'baz', :another => nil,      :explicit => nil  , :int => nil, :date => nil                 , :unindexed => nil)

      Bar.create!(:related => 'lala',         :foo => @foo_1)
      Bar.create!(:related => 'another lala', :foo => @foo_1)
    end

    after(:all) do
      ScopedSearch::RSpec::Database.drop_model(Foo)
      ScopedSearch::RSpec::Database.close_connection
    end

    context 'basic auto completer' do
      it "should complete the field name" do
        Foo.complete_for('str').should =~ ([' string '])
      end

       it "should not complete the logical operators at the beginning" do
        Foo.complete_for('a').should_not contain(['and'])
      end

      it "should complete the string comparators" do
        Foo.complete_for('string ').should =~ (["string != ", "string !~ ", "string = ", "string ~ "])
      end

      it "should complete the numerical comparators" do
        Foo.complete_for('int ').should =~ (["int != ", "int < ", "int <= ", "int = ", "int > ", "int >= "])
      end

      it "should complete the temporal (date) comparators" do
        Foo.complete_for('date ').should =~ (["date = ", "date < ", "date > "])
      end

      it "should raise error for unindexed field" do
        lambda { Foo.complete_for('unindexed = 10 ')}.should raise_error(ScopedSearch::QueryNotSupported)
      end

      it "should raise error for unknown field" do
        lambda {Foo.complete_for('unknown = 10 ')}.should raise_error(ScopedSearch::QueryNotSupported)
      end

      it "should complete logical comparators" do
        Foo.complete_for('string ~ fo ').should contain("string ~ fo and", "string ~ fo or")
      end

      it "should complete prefix operators" do
        Foo.complete_for(' ').should contain(" has", " not")
      end

      it "should not complete logical infix operators" do
        Foo.complete_for(' ').should_not contain(" and", " or")
      end

      it "should not repeat logical operators" do
        Foo.complete_for('string = foo and ').should_not contain("string = foo and and", "string = foo and or")
      end
    end

    context 'using an aliased field' do
      it "should complete an explicit match using its alias" do
        Foo.complete_for('al').should contain(' alias ')
      end
    end

    context 'value auto complete' do
      it "should complete values list of values " do
        Foo.complete_for('explicit = ').should have(1).item
      end

      it "should complete values should contain baz" do
        Foo.complete_for('explicit = ').should contain('explicit = baz')
      end
    end

    context 'auto complete relations' do
      it "should complete related object name" do
        Foo.complete_for('ba').should contain(' bars.related ')
      end

      it "should complete related object name with field name" do
        Foo.complete_for('bars.').should contain(' bars.related ')
      end
    end

    context 'using null prefix operators queries' do

      it "should complete has operator" do
        Foo.complete_for('has strin').should eql(['has string '])
      end

      it "should complete null? operator" do
        Foo.complete_for('null? st').should eql(['null? string '])
      end

      it "should complete set? operator" do
        Foo.complete_for('set? exp').should eql(['set? explicit '])
      end

      it "should complete null? operator for explicit field" do
        Foo.complete_for('null? explici').should eql(['null? explicit '])
      end

      it "should not complete comparators after prefix statement" do
        Foo.complete_for('has string ').should_not contain(['has string = '])
      end

      it "should not complete infix operator" do
        Foo.complete_for('has string ').should_not contain('has string = ')
      end
    end
  end
end
