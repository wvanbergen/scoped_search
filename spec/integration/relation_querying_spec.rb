require "#{File.dirname(__FILE__)}/../spec_helper"

# These specs will run on all databases that are defined in the spec/database.yml file.
# Comment out any databases that you do not have available for testing purposes if needed.
ScopedSearch::RSpec::Database.test_databases.each do |db|

  describe ScopedSearch, "using a #{db} database" do

    before(:all) do
      ScopedSearch::RSpec::Database.establish_named_connection(db)
    end

    after(:all) do
      ScopedSearch::RSpec::Database.close_connection
    end

    context 'querying a :belongs_to relation' do

      before do
        
        # The related class
        ActiveRecord::Migration.create_table(:hars) { |t| t.string :related }
        class Har < ActiveRecord::Base; has_many :loos; end

        # The class on which to call search_for
        ActiveRecord::Migration.create_table(:loos) { |t| t.string :foo; t.integer :har_id }
        class Loo < ActiveRecord::Base
          belongs_to :har
          scoped_search :in => :har, :on => :related
        end

        @har_record = Har.create!(:related => 'bar')

        Loo.create!(:foo => 'foo',       :har => @har_record)
        Loo.create!(:foo => 'foo too',   :har => @har_record)
        Loo.create!(:foo => 'foo three', :har => Har.create!(:related => 'another bar'))
        Loo.create!(:foo => 'foo four')
      end

      after do
        ScopedSearch::RSpec::Database.drop_model(Har)
        ScopedSearch::RSpec::Database.drop_model(Loo)
      end

      it "should find all records with a related bar record containing bar" do
        Loo.search_for('bar').should have(3).items
      end

      it "should find all records with a related bar record having an exact value of bar with an explicit field" do
        Loo.search_for('related = bar').should have(2).items
      end

      it "should find records for which the bar relation is not set using null?" do
        Loo.search_for('null? related').should have(1).items
      end

      it "should find records for which the bar relation is not set using null?" do
        Loo.search_for('',:order => 'related asc').first.foo.should eql('foo four')
      end

    end

    context 'querying a :has_many relation' do

      before do

        # The related class
        ActiveRecord::Migration.create_table(:jars) { |t| t.string :related; t.integer :goo_id }
        class Jar < ActiveRecord::Base; belongs_to :goo; end

        # The class on which to call search_for
        ActiveRecord::Migration.create_table(:goos) { |t| t.string :foo }
        class Goo < ActiveRecord::Base
          has_many :jars
          scoped_search :in => :jars, :on => :related
        end

        @foo_1 = Goo.create!(:foo => 'foo')
        @foo_2 = Goo.create!(:foo => 'foo too')
        @foo_3 = Goo.create!(:foo => 'foo three')

        Jar.create!(:related => 'bar',         :goo => @foo_1)
        Jar.create!(:related => 'another bar', :goo => @foo_1)
        Jar.create!(:related => 'other bar',   :goo => @foo_2)
      end

      after do
        ScopedSearch::RSpec::Database.drop_model(Jar)
        ScopedSearch::RSpec::Database.drop_model(Goo)
      end

      it "should find all records with at least one bar record containing 'bar'" do
        ::Goo.search_for('bar').should have(2).items
      end

      it "should find the only record with at least one bar record having the exact value 'bar'" do
        ::Goo.search_for('= bar').should have(1).item
      end

      it "should find all records for which at least one related bar record exists" do
        ::Goo.search_for('set? related').should have(2).items
      end

      it "should find all records for which none related bar records exist" do
        ::Goo.search_for('null? related').should have(1).items
      end

    end

    context 'querying a :has_one relation' do

      before do

        # The related class
        ActiveRecord::Migration.drop_table(:cars) rescue nil
        ActiveRecord::Migration.create_table(:cars) { |t| t.string :related; t.integer :hoo_id }
        class Car < ActiveRecord::Base; belongs_to :hoo; end

        # The class on which to call search_for
        ActiveRecord::Migration.create_table(:hoos) { |t| t.string :foo }
        class Hoo < ActiveRecord::Base
          has_one :car
          scoped_search :on => :foo
          scoped_search :in => :car, :on => :related
        end

        @hoo_1 = Hoo.create!(:foo => 'foo')
        @hoo_2 = Hoo.create!(:foo => 'foo too')
        @hoo_3 = Hoo.create!(:foo => 'foo three')

        Car.create!(:related => 'bar',         :hoo => @hoo_1)
        Car.create!(:related => 'other bar',   :hoo => @hoo_2)
      end

      after do
        ScopedSearch::RSpec::Database.drop_model(Car)
        ScopedSearch::RSpec::Database.drop_model(Hoo)
      end

      it "should find all records with a car record containing 'bar" do
        Hoo.search_for('bar').should have(2).items
      end

      it "should find the only record with the bar record has the exact value 'bar" do
        Hoo.search_for('= bar').should have(1).item
      end

      it "should find all records for which the related bar record exists" do
        Hoo.search_for('set? related').should have(2).items
      end

      it "should find all records for which the related bar record does not exist" do
        Hoo.search_for('null? related').should have(1).items
      end
    end

    context 'querying a :has_and_belongs_to_many relation' do

      before do

        # Create some tables
        ActiveRecord::Migration.create_table(:dars) { |t| t.string :related }
        ActiveRecord::Migration.create_table(:dars_joos, :id => false) { |t| t.integer :joo_id; t.integer :dar_id }
        ActiveRecord::Migration.create_table(:joos) { |t| t.string :foo }

        # The related class
        class Dar < ActiveRecord::Base; end

        # The class on which to call search_for
        class Joo < ActiveRecord::Base
          has_and_belongs_to_many :dars
          scoped_search :in => :dars, :on => :related
        end

        @joo_1 = Joo.create!(:foo => 'foo')
        @joo_2 = Joo.create!(:foo => 'foo too')
        @joo_3 = Joo.create!(:foo => 'foo three')

        @dar_1 = Dar.create!(:related => 'bar')
        @dar_2 = Dar.create!(:related => 'other bar')
        @dar_3 = Dar.create!(:related => 'last bar')

        @joo_1.dars << @dar_1 << @dar_2
        @joo_2.dars << @dar_2 << @dar_3
      end

      after do
        ActiveRecord::Migration.drop_table(:dars_joos)
        ActiveRecord::Migration.drop_table(:dars)
        ActiveRecord::Migration.drop_table(:joos)
      end

      it "should find all records with at least one associated bar record containing 'bar'" do
        Joo.search_for('bar').should have(2).items
      end

      it "should find record which is related to @bar_1" do
        Joo.search_for('= bar').should have(1).items
      end

      it "should find the only record related to @bar_3" do
        Joo.search_for('last').should have(1).items
      end

      it "should find all records that are related to @bar_2" do
        Joo.search_for('other').should have(2).items
      end
    end

    context 'querying a :has_many => :through relation' do

      before do

        # Create some tables
        ActiveRecord::Migration.create_table(:mars) { |t| t.integer :koo_id; t.integer :baz_id }
        ActiveRecord::Migration.create_table(:bazs) { |t| t.string :related }
        ActiveRecord::Migration.create_table(:koos) { |t| t.string :foo }

        # The related classes
        class Mar < ActiveRecord::Base; belongs_to :baz; belongs_to :koo; end
        class Baz < ActiveRecord::Base; has_many :mars; end

        # The class on which to call search_for
        class Koo < ActiveRecord::Base
          has_many :mars
          has_many :bazs, :through => :mars

          scoped_search :in => :bazs, :on => :related
        end

        @koo_1 = Koo.create!(:foo => 'foo')
        @koo_2 = Koo.create!(:foo => 'foo too')
        @koo_3 = Koo.create!(:foo => 'foo three')

        @baz_1 = Baz.create(:related => 'baz')
        @baz_2 = Baz.create(:related => 'baz too!')

        @bar_1 = Mar.create!(:koo => @koo_1, :baz => @baz_1)
        @bar_2 = Mar.create!(:koo => @koo_1)
        @bar_3 = Mar.create!(:koo => @koo_2, :baz => @baz_1)
        @bar_3 = Mar.create!(:koo => @koo_2, :baz => @baz_2)
        @bar_3 = Mar.create!(:koo => @koo_2, :baz => @baz_2)
        @bar_4 = Mar.create!(:koo => @koo_3)
      end

      after do
        ActiveRecord::Migration.drop_table(:bazs)
        ActiveRecord::Migration.drop_table(:mars)
        ActiveRecord::Migration.drop_table(:koos)
      end

      it "should find the two records that are related to a baz record" do
        Koo.search_for('baz').should have(2).items
      end
    end
  end
end
