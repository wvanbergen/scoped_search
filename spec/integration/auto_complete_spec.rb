require "spec_helper"

# These specs will run on all databases that are defined in the spec/database.yml file.
# Comment out any databases that you do not have available for testing purposes if needed.
ScopedSearch::RSpec::Database.test_databases.each do |db|

  describe ScopedSearch, "using a #{db} database" do

    before(:all) do
      ScopedSearch::RSpec::Database.establish_named_connection(db)

      ActiveRecord::Migration.create_table(:bars, :force => true) do |t|
        t.integer :foo_id
        t.string :related
        t.string :other_a
        t.string :other_b
        t.string :other_c
      end

      ActiveRecord::Migration.create_table(:quxes, :force => true) do |t|
        t.string :related
        t.string :other_a
        t.string :other_b
        t.string :other_c
      end

      ActiveRecord::Migration.create_table(:foos, :force => true) do |t|
        t.string  :string
        t.string  :another
        t.string  :explicit
        t.string  :deprecated
        t.integer :int
        t.date    :date
        t.integer :unindexed
        t.integer :qux_id

        if on_postgresql?
          t.uuid :uuid
        else
          t.string :uuid
        end
      end

      class ::Bar < ActiveRecord::Base
        belongs_to :foo
      end

      class ::Qux < ActiveRecord::Base
        has_many :foos
      end

      class ::Foo < ActiveRecord::Base
        has_many :bars
        belongs_to :qux
        default_scope { order(:string) }

        scoped_search :on => [:string, :date, :uuid]
        scoped_search :on => [:int], :complete_value => true
        scoped_search :on => :another,  :default_operator => :eq, :aliases => [:alias], :complete_value => true
        scoped_search :on => :explicit, :only_explicit => true, :complete_value => true
        scoped_search :on => :deprecated, :complete_enabled => false
        scoped_search :on => :related, :relation => :bars, :rename => 'bars.related'.to_sym
        scoped_search :on => :other_a, :relation => :bars, :rename => 'bars.other_a'.to_sym
        scoped_search :on => :other_b, :relation => :bars, :rename => 'bars.other_b'.to_sym
        scoped_search :on => :other_c, :relation => :bars, :rename => 'bars.other_c'.to_sym
      end

      class ::Infoo < ::Foo
      end

      @qux_1 = Qux.create!()
      @qux_2 = Qux.create!()
      @foo_1 = Foo.create!(:string => 'foo', :another => 'temp 1', :explicit => 'baz', :int => 9  , :date => 'February 8, 2011' , :unindexed => 10, :qux => @qux_1)
      @foo_2 = Foo.create!(:string => 'foo', :another => 'temp 2', :explicit => 'baz', :int => 10  , :date => 'February 8, 2011' , :unindexed => 10, :qux => @qux_2)
      Foo.create!(:string => 'bar', :another => 'temp "2"', :explicit => 'baz', :int => 22  , :date => 'February 10, 2011', :unindexed => 10)
      Foo.create!(:string => 'baz', :another => nil,      :explicit => nil  , :int => nil, :date => nil                 , :unindexed => nil)
      20.times { Foo.create!(:explicit => "aaa") }

      Bar.create!(:related => 'lala',         :foo => @foo_1)
      Bar.create!(:related => 'another lala', :foo => @foo_1)
    end

    after(:all) do
      ActiveRecord::Migration.drop_table(:foos)
      ActiveRecord::Migration.drop_table(:bars)

      Object.send :remove_const, :Foo
      Object.send :remove_const, :Bar
      Object.send :remove_const, :Infoo

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
        Foo.complete_for('string ').should =~ (["string  != ", "string  !^ ", "string  !~ ", "string  = ", "string  ^ ", "string  ~ "])
      end

      it "should complete the numerical comparators" do
        Foo.complete_for('int ').should =~ (["int  != ", "int  !^ ", "int  < ", "int  <= ", "int  = ", "int  > ", "int  >= ", "int  ^ "])
      end

      it "should complete the temporal (date) comparators" do
        Foo.complete_for('date ').should =~ (["date  = ", "date  < ", "date  > "])
      end

      it "should complete the uuid comparators" do
        if on_postgresql?
          Foo.complete_for('uuid ').should =~ (["uuid  = ", "uuid  != "])
        end
      end

      it "should complete when query is already distinct" do
        Foo.distinct.complete_for('int =').length.should > 0
      end

      it "should raise error for unindexed field" do
        lambda { Foo.complete_for('unindexed = 10 ')}.should raise_error(ScopedSearch::QueryNotSupported)
      end

      it "should raise error for unknown field" do
        lambda {Foo.complete_for('unknown = 10 ')}.should raise_error(ScopedSearch::QueryNotSupported)
      end

      it "should complete logical comparators" do
        Foo.complete_for('string ~ fo ').should contain("string ~ fo  and", "string ~ fo  or")
      end

      it "should complete prefix operators" do
        Foo.complete_for(' ').should contain("  has", "  not")
      end

      it "should not complete logical infix operators" do
        Foo.complete_for(' ').should_not contain(" and", " or")
      end

      it "should not repeat logical operators" do
        Foo.complete_for('string = foo and ').should_not contain("string = foo and and", "string = foo and or")
      end

      it "should not contain deprecated field in autocompleter" do
        Foo.complete_for(' ').should_not contain("  deprecated")
      end
    end

    context 'inherited auto completer' do
      it "should complete the field name" do
        Infoo.complete_for('str').should =~ ([' string '])
      end
    end

    context 'using an aliased field' do
      it "should complete an explicit match using its alias" do
        Foo.complete_for('al').should contain(' alias ')
      end
    end

    context 'value auto complete' do
      it "should complete values list of values " do
        Foo.complete_for('explicit = ').length.should == 2
      end

      it "should complete values should contain baz" do
        Foo.complete_for('explicit = ').should contain('explicit =  "baz"')
      end

      it "should complete values with quotes where value is a string" do
        Foo.complete_for('alias = ').should contain('alias =  "temp \"2\""')
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
        Foo.complete_for('has strin').should eql(['has  string '])
      end

      it "should complete null? operator" do
        Foo.complete_for('null? st').should eql(['null?  string '])
      end

      it "should complete set? operator" do
        Foo.complete_for('set? exp').should eql(['set?  explicit '])
      end

      it "should complete null? operator for explicit field" do
        Foo.complete_for('null? explici').should eql(['null?  explicit '])
      end

      it "should not complete comparators after prefix statement" do
        Foo.complete_for('has string ').should_not contain(['has string = '])
      end

      it "should not complete infix operator" do
        Foo.complete_for('has string ').should_not contain('has string = ')
      end
    end


    context 'exceptional search strings' do

      it "query that starts with 'or'" do
        Foo.complete_for('or ').length.should == 10
      end

      it "value completion with quotes" do
        Foo.complete_for('string = "').should eql([])
      end

      it "value completion with single quote" do
        Foo.complete_for("string = this is a 'valid' query").should eql([])
      end

      it "value auto completer for related tables" do
        Foo.complete_for('bars.related = ').should eql([])
      end
    end

    # When options list is long (>10) and some of the options are in the format 'common.detail'
    # the list should be shorten to include only 'common', the details part should be unfolded
    # when the 'common.' part is typed or the options list size is reduced by typing part of
    # the string.
    context 'dotted options in the completion list' do
      it "query that starts with space should not include the dotted options" do
        Foo.complete_for(' ').length.should == 10
      end

      it "query that starts with the dotted string should include the dotted options" do
        Foo.complete_for('bars.').length.should == 4
      end

      it "query that starts with part of the dotted string should include the dotted options" do
        Foo.complete_for('b').length.should == 4
      end

    end

    context 'autocompleting integer comparisons' do
      it 'should autocomplete numerical fields' do
        Foo.complete_for('int > 2').first.should match(/22/)
      end
    end

    context 'autocompleting with value_filter' do
      it 'should return filtered values' do
        Foo.complete_for('int =', value_filter: { qux_id: @qux_1.id }).should == ['int = 9']
      end
      it 'should return filtered for invalid value' do
        Foo.complete_for('int =', value_filter: { qux_id: 99 }).should == []
      end
    end
  end
end
