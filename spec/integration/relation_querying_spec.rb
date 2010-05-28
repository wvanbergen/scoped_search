require 'spec_helper'

# These specs will run on all databases that are defined in the spec/database.yml file.
# Comment out any databases that you do not have available for testing purposes if needed.
ScopedSearch::Spec::Database.test_databases.each do |db|

  describe ScopedSearch, "using a #{db} database" do

    before(:all) do
      ScopedSearch::Spec::Database.establish_named_connection(db)
    end

    after(:all) do
      ScopedSearch::Spec::Database.close_connection
    end

    context 'querying a :belongs_to relation' do

      before(:all) do

        # The related class
        ActiveRecord::Migration.create_table(:bars) { |t| t.string :related }
        class ::Bar < ActiveRecord::Base; has_many :foos; end

        # The class on which to call search_for
        ::Foo = ScopedSearch::Spec::Database.create_model(:foo => :string, :bar_id => :integer) do |klass|
          klass.belongs_to :bar
          klass.scoped_search :in => :bar, :on => :related
        end

        @bar_record = Bar.create!(:related => 'bar')

        Foo.create!(:foo => 'foo',       :bar => @bar_record)
        Foo.create!(:foo => 'foo too',   :bar => @bar_record)
        Foo.create!(:foo => 'foo three', :bar => Bar.create!(:related => 'another bar'))
        Foo.create!(:foo => 'foo four')
      end

      after(:all) do
        ScopedSearch::Spec::Database.drop_model(Bar)
        ScopedSearch::Spec::Database.drop_model(Foo)
        Object.send :remove_const, :Foo
        Object.send :remove_const, :Bar
      end

      it "should find all records with a related bar record containing bar" do
        Foo.search_for('bar').should have(3).items
      end

      it "should find all records with a related bar record having an exact value of bar" do
        Foo.search_for('= bar').should have(2).items
      end

      it "should find all records with a related bar record having an exact value of bar with an explicit field" do
         Foo.search_for('related = bar').should have(2).items
       end

      it "should find records for which the bar relation is not set using null?" do
        Foo.search_for('null? related').should have(1).items
      end
    end

    context 'querying a :has_many relation' do

      before(:all) do

        # The related class
        ActiveRecord::Migration.create_table(:bars) { |t| t.string :related; t.integer :foo_id }
        class ::Bar < ActiveRecord::Base; belongs_to :foo; end

        # The class on which to call search_for
        ::Foo = ScopedSearch::Spec::Database.create_model(:foo => :string, :bar_id => :integer) do |klass|
          klass.has_many :bars
          klass.scoped_search :in => :bars, :on => :related
        end

        @foo_1 = Foo.create!(:foo => 'foo')
        @foo_2 = Foo.create!(:foo => 'foo too')
        @foo_3 = Foo.create!(:foo => 'foo three')

        Bar.create!(:related => 'bar',         :foo => @foo_1)
        Bar.create!(:related => 'another bar', :foo => @foo_1)
        Bar.create!(:related => 'other bar',   :foo => @foo_2)
      end

      after(:all) do
        ScopedSearch::Spec::Database.drop_model(Bar)
        ScopedSearch::Spec::Database.drop_model(Foo)
        Object.send :remove_const, :Foo
        Object.send :remove_const, :Bar
      end

      it "should find all records with at least one bar record containing 'bar'" do
        Foo.search_for('bar').should have(2).items
      end

      it "should find the only record with at least one bar record having the exact value 'bar'" do
        Foo.search_for('= bar').should have(1).item
      end

      it "should find all records for which at least one related bar record exists" do
        Foo.search_for('set? related').should have(2).items
      end

      it "should find all records for which none related bar records exist" do
        Foo.search_for('null? related').should have(1).items
      end

    end

    context 'querying a :has_one relation' do

      before(:all) do

        # The related class
        ActiveRecord::Migration.create_table(:bars) { |t| t.string :related; t.integer :foo_id }
        class ::Bar < ActiveRecord::Base; belongs_to :foo; end

        # The class on which to call search_for
        ::Foo = ScopedSearch::Spec::Database.create_model(:foo => :string) do |klass|
          klass.has_one :bar
          klass.scoped_search :in => :bar, :on => :related
        end

        @foo_1 = ::Foo.create!(:foo => 'foo')
        @foo_2 = ::Foo.create!(:foo => 'foo too')
        @foo_3 = ::Foo.create!(:foo => 'foo three')

        ::Bar.create!(:related => 'bar',         :foo => @foo_1)
        ::Bar.create!(:related => 'other bar',   :foo => @foo_2)
      end

      after(:all) do
        ScopedSearch::Spec::Database.drop_model(::Bar)
        ScopedSearch::Spec::Database.drop_model(::Foo)
        Object.send :remove_const, :Foo
        Object.send :remove_const, :Bar
      end

      it "should find all records with a bar record containing 'bar" do
        ::Foo.search_for('bar').should have(2).items
      end

      it "should find the only record with the bar record has the exact value 'bar" do
        ::Foo.search_for('= bar').should have(1).item
      end

      it "should find all records for which the related bar record exists" do
        ::Foo.search_for('set? related').should have(2).items
      end

      it "should find all records for which the related bar record does not exist" do
        ::Foo.search_for('null? related').should have(1).items
      end
    end

    context 'querying a :has_and_belongs_to_many relation' do

      before(:all) do

        # Create some tables
        ActiveRecord::Migration.create_table(:bars) { |t| t.string :related }
        ActiveRecord::Migration.create_table(:bars_foos, :id => false) { |t| t.integer :foo_id; t.integer :bar_id }
        ActiveRecord::Migration.create_table(:foos) { |t| t.string :foo }

        # The related class
        class ::Bar < ActiveRecord::Base; end

        # The class on which to call search_for
        class ::Foo < ActiveRecord::Base
          has_and_belongs_to_many :bars
          scoped_search :in => :bars, :on => :related
        end

        @foo_1 = ::Foo.create!(:foo => 'foo')
        @foo_2 = ::Foo.create!(:foo => 'foo too')
        @foo_3 = ::Foo.create!(:foo => 'foo three')

        @bar_1 = ::Bar.create!(:related => 'bar')
        @bar_2 = ::Bar.create!(:related => 'other bar')
        @bar_3 = ::Bar.create!(:related => 'last bar')

        @foo_1.bars << @bar_1 << @bar_2
        @foo_2.bars << @bar_2 << @bar_3
      end

      after(:all) do
        ActiveRecord::Migration.drop_table(:bars_foos)
        ActiveRecord::Migration.drop_table(:bars)
        ActiveRecord::Migration.drop_table(:foos)
        Object.send :remove_const, :Foo
        Object.send :remove_const, :Bar
      end

      it "should find all records with at least one associated bar record containing 'bar'" do
        ::Foo.search_for('bar').should have(2).items
      end

      it "should find record which is related to @bar_1" do
        ::Foo.search_for('= bar').should have(1).items
      end

      it "should find the only record related to @bar_3" do
        ::Foo.search_for('last').should have(1).items
      end

      it "should find all records that are related to @bar_2" do
        ::Foo.search_for('other').should have(2).items
      end
    end

    context 'querying a :has_many => :through relation' do

      before(:all) do

        # Create some tables
        ActiveRecord::Migration.create_table(:bars) { |t| t.integer :foo_id; t.integer :baz_id }
        ActiveRecord::Migration.create_table(:bazs) { |t| t.string :related }
        ActiveRecord::Migration.create_table(:foos) { |t| t.string :foo }

        # The related classes
        class ::Bar < ActiveRecord::Base; belongs_to :baz; belongs_to :foo; end
        class ::Baz < ActiveRecord::Base; has_many :bars; end

        # The class on which to call search_for
        class ::Foo < ActiveRecord::Base
          has_many :bars
          has_many :bazs, :through => :bars

          scoped_search :in => :bazs, :on => :related
        end

        @foo_1 = ::Foo.create!(:foo => 'foo')
        @foo_2 = ::Foo.create!(:foo => 'foo too')
        @foo_3 = ::Foo.create!(:foo => 'foo three')

        @baz_1 = ::Baz.create(:related => 'baz')
        @baz_2 = ::Baz.create(:related => 'baz too!')

        @bar_1 = ::Bar.create!(:foo => @foo_1, :baz => @baz_1)
        @bar_2 = ::Bar.create!(:foo => @foo_1)
        @bar_3 = ::Bar.create!(:foo => @foo_2, :baz => @baz_1)
        @bar_3 = ::Bar.create!(:foo => @foo_2, :baz => @baz_2)
        @bar_3 = ::Bar.create!(:foo => @foo_2, :baz => @baz_2)
        @bar_4 = ::Bar.create!(:foo => @foo_3)
      end

      after(:all) do
        ActiveRecord::Migration.drop_table(:bazs)
        ActiveRecord::Migration.drop_table(:bars)
        ActiveRecord::Migration.drop_table(:foos)
        Object.send :remove_const, :Foo
        Object.send :remove_const, :Bar
        Object.send :remove_const, :Baz
      end

      it "should find the two records that are related to a baz record" do
        ::Foo.search_for('baz').should have(2).items
      end
    end
  end
end
