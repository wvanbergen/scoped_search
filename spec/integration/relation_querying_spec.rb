require "spec_helper"

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

    context 'querying a subclass' do
      before do
        ActiveRecord::Migration.create_table(:supers) { |t| t.string :name }
        class Super < ActiveRecord::Base
          scoped_search :on => :name
        end
        class Sub < Super; end

        @super_record = Super.create!(:name => 'test')
      end

      after do
        ScopedSearch::RSpec::Database.drop_model(Super)
      end

      it "should find records when searching the subclass" do
        Sub.search_for('test').should have(1).item
      end
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
          scoped_search :on => :foo
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
      
      it "should find all records which has relation with both related values" do
        ::Goo.search_for('related=bar AND related="another bar"').should have(1).items
      end

      it "should find all records searching with both parent and child fields" do
        ::Goo.search_for('foo bar').should have(2).items
      end

      it "should find the only record with two Jars" do
        ::Goo.search_for('foo bar "another bar"').should have(1).item
      end

      it "shouldn't find any records as there isn't an intersect" do
        ::Goo.search_for('too another').should have(0).items
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
          # having the source option here is not needed for the statement correctness.
          # It is here to fail the code introduced in 2.6.2 that wrongly detected source instead of source_type
          # as an indication for a polymorphic relation.
          has_many :bazs, :through => :mars, :source => :baz

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

      it "should find the two records that are related to a baz record" do
        Koo.search_for('related=baz AND related="baz too!"').should have(1).items
      end
    end

    context 'querying a :has_many => :through many relation' do

      before do

        # Create some tables
        ActiveRecord::Migration.create_table(:zars) { |t| t.integer :baz_id }
        ActiveRecord::Migration.create_table(:bazs) { |t| t.string :related }
        ActiveRecord::Migration.create_table(:zoos) { |t| t.integer :zar_id; t.string :foo }

        # The related classes
        class Zar < ActiveRecord::Base; belongs_to :baz; has_many :zoos; end
        class Baz < ActiveRecord::Base; has_many :zars; end

        # The class on which to call search_for
        class Zoo < ActiveRecord::Base
          belongs_to :zar
          has_many :bazs, :through => :zar

          scoped_search :in => :bazs, :on => :related
        end

        baz_1 = Baz.create(:related => 'baz')
        baz_2 = Baz.create(:related => 'baz too!')

        zar_1 = Zar.create!( :baz => baz_1)
        zar_2 = Zar.create!( :baz => baz_2)

        Zoo.create!(:zar => zar_1, :foo => 'foo')
        Zoo.create!(:zar => zar_1, :foo => 'foo too')
        Zoo.create!(:zar => zar_2, :foo => 'foo three')
      end

      after do
        ActiveRecord::Migration.drop_table(:bazs)
        ActiveRecord::Migration.drop_table(:zars)
        ActiveRecord::Migration.drop_table(:zoos)
      end

      # This table schema is not supported in activerecord 2, skip the tests
      if ActiveRecord::VERSION::MAJOR > 2
        it "should find the three records that are related to a baz record" do
          Zoo.search_for('baz').should have(3).items
        end

        it "should find no records that are related to a baz record" do
          Zoo.search_for('related=baz AND related="baz too!"').should have(0).items
        end
      end
    end

    context 'querying a :has_many => :through :polymorphic relation' do

      before do

        # Create some tables
        ActiveRecord::Migration.create_table(:taggables) { |t| t.integer :taggable_id; t.string :taggable_type; t.integer :tag_id }
        ActiveRecord::Migration.create_table(:dogs) { |t| t.string :related }
        ActiveRecord::Migration.create_table(:cats) { |t| t.string :related }
        ActiveRecord::Migration.create_table(:tags) { |t| t.string :foo }

        # The related classes
        class Taggable < ActiveRecord::Base; belongs_to :tag; belongs_to :taggable, :polymorphic => true; end

        class Tag < ActiveRecord::Base
          has_many :taggables
          has_many :dogs, :through => :taggables, :source => :taggable, :source_type => 'Dog'

          scoped_search :in => :dogs, :on => :related, :rename => :dog
        end

        # The class on which to call search_for
        class Dog < ActiveRecord::Base
          has_many :taggables, :as => :taggable
          has_many :tags, :through => :taggables

          scoped_search :in => :tags, :on => :foo
        end

        class Cat < ActiveRecord::Base
          has_many :taggables, :as => :taggable
          has_many :tags, :through => :taggables
        end

        @tag_1 = Tag.create!(:foo => 'foo')
        @tag_2 = Tag.create!(:foo => 'foo too')
        @tag_3 = Tag.create!(:foo => 'foo three')

        @dog_1 = Dog.create(:related => 'baz')
        @dog_2 = Dog.create(:related => 'baz too!')
        @cat_1 = Cat.create(:related => 'mitzi')

        Taggable.create!(:tag => @tag_1, :taggable => @dog_1, :taggable_type => 'Dog' )
        Taggable.create!(:tag => @tag_1)
        Taggable.create!(:tag => @tag_2, :taggable => @dog_1 , :taggable_type => 'Dog')
        Taggable.create!(:tag => @tag_2, :taggable => @dog_2 , :taggable_type => 'Dog')
        Taggable.create!(:tag => @tag_3, :taggable => @dog_2 , :taggable_type => 'Dog')
        Taggable.create!(:tag => @tag_2, :taggable => @cat_1 , :taggable_type => 'Cat')
        Taggable.create!(:tag => @tag_3)
      end

      after do
        ActiveRecord::Migration.drop_table(:dogs)
        ActiveRecord::Migration.drop_table(:taggables)
        ActiveRecord::Migration.drop_table(:tags)
        ActiveRecord::Migration.drop_table(:cats)
      end

      it "should find the two records that are related to a tag that contains foo record" do
        Dog.search_for('foo').should have(2).items
      end

      it "should find one records that is related to both tags" do
        Dog.search_for('foo=foo AND foo="foo too"').should have(1).items
      end

      it "should find the two tags that are related to a dog record" do
        Tag.search_for('dog=baz').should have(2).items
      end

      it "should find the 3 tags that are related to dogs record" do
        Tag.search_for('baz').should have(3).items
      end

    end
  end
end
