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
        Sub.search_for('test').length.should == 1
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
          scoped_search :relation => :har, :on => :related
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
        Loo.search_for('bar').length.should == 3
      end

      it "should find all records with a related bar record having an exact value of bar with an explicit field" do
        Loo.search_for('related = bar').length.should == 2
      end

      it "should find records for which the bar relation is not set using null?" do
        Loo.search_for('null? related').length.should == 1
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
          scoped_search :relation => :jars, :on => :related
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
        ::Goo.search_for('bar').length.should == 2
      end

      it "should find the only record with at least one bar record having the exact value 'bar'" do
        ::Goo.search_for('= bar').length.should == 1
      end

      it "should find all records for which at least one related bar record exists" do
        ::Goo.search_for('set? related').length.should == 2
      end

      it "should find all records for which none related bar records exist" do
        ::Goo.search_for('null? related').length.should == 1
      end

      it "should find all records which has relation with both related values" do
        ::Goo.search_for('related=bar AND related="another bar"').length.should == 1
      end

      it "should find all records searching with both parent and child fields" do
        ::Goo.search_for('foo bar').length.should == 2
      end

      it "should find the only record with two Jars" do
        ::Goo.search_for('foo bar "another bar"').length.should == 1
      end

      it "shouldn't find any records as there isn't an intersect" do
        ::Goo.search_for('too another').length.should == 0
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
          scoped_search :relation => :car, :on => :related
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
        Hoo.search_for('bar').length.should == 2
      end

      it "should find the only record with the bar record has the exact value 'bar" do
        Hoo.search_for('= bar').length.should == 1
      end

      it "should find all records for which the related bar record exists" do
        Hoo.search_for('set? related').length.should == 2
      end

      it "should find all records for which the related bar record does not exist" do
        Hoo.search_for('null? related').length.should == 1
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
          scoped_search :relation => :dars, :on => :related
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
        ScopedSearch::RSpec::Database.drop_model(Joo)
        ScopedSearch::RSpec::Database.drop_model(Dar)
        ActiveRecord::Migration.drop_table(:dars_joos) if ActiveRecord::Migration.table_exists?(:dars_joos)
      end

      it "should find all records with at least one associated bar record containing 'bar'" do
        Joo.search_for('bar').length.should == 2
      end

      it "should find record which is related to @bar_1" do
        Joo.search_for('= bar').length.should == 1
      end

      it "should find the only record related to @bar_3" do
        Joo.search_for('last').length.should == 1
      end

      it "should find all records that are related to @bar_2" do
        Joo.search_for('other').length.should == 2
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

          scoped_search :relation => :bazs, :on => :related
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
        Koo.search_for('baz').length.should == 2
      end

      it "should find the two records that are related to a baz record" do
        Koo.search_for('related=baz AND related="baz too!"').length.should == 1
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

          scoped_search :relation => :bazs, :on => :related
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

      it "should find the three records that are related to a baz record" do
        Zoo.search_for('baz').length.should == 3
      end

      it "should find no records that are related to a baz record" do
        Zoo.search_for('related=baz AND related="baz too!"').length.should == 0
      end
    end

    context 'querying a :has_many => :through :polymorphic relation' do

      before do

        # Create some tables
        ActiveRecord::Migration.create_table(:taggables) { |t| t.integer :taggable_id; t.string :taggable_type; t.integer :tag_id }
        ActiveRecord::Migration.create_table(:dogs) { |t| t.string :related; t.integer :owner_id }
        ActiveRecord::Migration.create_table(:cats) { |t| t.string :related }
        ActiveRecord::Migration.create_table(:tags) { |t| t.string :foo }
        ActiveRecord::Migration.create_table(:owners) { |t| t.string :name }

        # The related classes
        class Taggable < ActiveRecord::Base; belongs_to :tag; belongs_to :taggable, :polymorphic => true; end

        class Tag < ActiveRecord::Base
          has_many :taggables
          has_many :dogs, :through => :taggables, :source => :taggable, :source_type => 'Dog'

          scoped_search :relation => :dogs, :on => :related, :rename => :dog
        end

        # The class on which to call search_for
        class Dog < ActiveRecord::Base
          has_many :taggables, :as => :taggable
          has_many :tags, :through => :taggables
          belongs_to :owner

          scoped_search :relation => :tags, :on => :foo
        end

        class Cat < ActiveRecord::Base
          has_many :taggables, :as => :taggable
          has_many :tags, :through => :taggables
        end

        class Owner < ActiveRecord::Base
          has_many :dogs
          has_many :taggables, :as => :taggable, :through => :dogs
          has_many :tags, :through => :taggables

          scoped_search :relation => :tags, :on => :foo
        end

        @tag_1 = Tag.create!(:foo => 'foo')
        @tag_2 = Tag.create!(:foo => 'foo too')
        @tag_3 = Tag.create!(:foo => 'foo three')

        @dog_1 = Dog.create(:related => 'baz')
        @dog_2 = Dog.create(:related => 'baz too!')
        @cat_1 = Cat.create(:related => 'mitzi')

        @owner_1 = Owner.create(:name => 'Fred', :dogs => [@dog_1])

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
        ActiveRecord::Migration.drop_table(:owners)
      end

      it "should find the two records that are related to a tag that contains foo record" do
        Dog.search_for('foo').length.should == 2
      end

      it "should find the only record that is related to a tag" do
        Owner.search_for('foo').length.should == 1
        Owner.search_for('foo').to_sql.should =~ /taggable_type = 'Dog'/
      end

      it "should find one records that is related to both tags" do
        Dog.search_for('foo=foo AND foo="foo too"').length.should == 1
      end

      it "should find the two tags that are related to a dog record" do
        Tag.search_for('dog=baz').length.should == 2
      end

      it "should find the 3 tags that are related to dogs record" do
        Tag.search_for('baz').length.should == 3
      end
    end


    context 'querying a :has_many => :through relation with alternate name' do

      before do

        # Create some tables
        ActiveRecord::Migration.create_table(:zaps) { |t| t.integer :moo_id; t.integer :paz_id }
        ActiveRecord::Migration.create_table(:pazs) { |t| t.string :related }
        ActiveRecord::Migration.create_table(:moos) { |t| t.string :foo }   

        # The related classes
        class Zap < ActiveRecord::Base; belongs_to :paz; belongs_to :moo; end
        class Paz < ActiveRecord::Base; has_many :other_zaps, :class_name => "Zap", :foreign_key => :paz_id; end

        # The class on which to call search_for
        class Moo < ActiveRecord::Base
          has_many :zaps
          has_many :pazs, :through => :zaps

          scoped_search :relation => :pazs, :on => :related
        end

        @moo_1 = Moo.create!(:foo => 'foo')
        @moo_2 = Moo.create!(:foo => 'foo too')
        @moo_3 = Moo.create!(:foo => 'foo three')

        @paz_1 = Paz.create(:related => 'paz')
        @paz_2 = Paz.create(:related => 'paz too!')

        @bar_1 = Zap.create!(:moo => @moo_1, :paz => @paz_1)
        @bar_2 = Zap.create!(:moo => @moo_1)
        @bar_3 = Zap.create!(:moo => @moo_2, :paz => @paz_1)
        @bar_3 = Zap.create!(:moo => @moo_2, :paz => @paz_2)
        @bar_3 = Zap.create!(:moo => @moo_2, :paz => @paz_2)
        @bar_4 = Zap.create!(:moo => @moo_3)
      end

      after do
        ActiveRecord::Migration.drop_table(:pazs)
        ActiveRecord::Migration.drop_table(:zaps)
        ActiveRecord::Migration.drop_table(:moos)
      end

      it "should find the two records that are related to a paz record" do
        Moo.search_for('paz').length.should == 2
      end

      it "should find the one record that is related to two paz records" do
        Moo.search_for('related=paz AND related="paz too!"').length.should == 1
      end
    end

    context 'querying a :has_many => :through relation with same name on target class with custom condition' do

      before do

        # Create some tables
        ActiveRecord::Migration.create_table(:user_groups) { |t| t.integer :user_id; t.integer :group_id }
        ActiveRecord::Migration.create_table(:conflicts) { |t| t.integer :group_id; t.integer :user_id }
        ActiveRecord::Migration.create_table(:groups) { |t| t.string :related; t.integer :user_id }
        ActiveRecord::Migration.create_table(:users) { |t| t.string :foo }

        # The related classes
        class UserGroup < ActiveRecord::Base; belongs_to :user; belongs_to :group; end
        class Conflict < ActiveRecord::Base; belongs_to :user; belongs_to :group; end
        class Group < ActiveRecord::Base
          has_many :user_groups
          has_many :users, :through => :conflicts, :source_type => 'User', :source => :user
        end

        # The class on which to call search_for
        class User < ActiveRecord::Base
          has_many :user_groups
          has_many :groups, :through => :user_groups

          scoped_search :relation => :groups, :on => :related
        end

        @user_1 = User.create!(:foo => 'foo')
        @user_2 = User.create!(:foo => 'foo too')
        @user_3 = User.create!(:foo => 'foo three')

        @group_1 = Group.create(:related => 'value')
        @group_2 = Group.create(:related => 'value too!')

        @bar_1 = UserGroup.create!(:user => @user_1, :group => @group_1)
        @bar_2 = UserGroup.create!(:user => @user_1)
        @bar_3 = UserGroup.create!(:user => @user_2, :group => @group_1)
        @bar_3 = UserGroup.create!(:user => @user_2, :group => @group_2)
        @bar_3 = UserGroup.create!(:user => @user_2, :group => @group_2)
        @bar_4 = UserGroup.create!(:user => @user_3)
      end

      after do
        ActiveRecord::Migration.drop_table(:user_groups)
        ActiveRecord::Migration.drop_table(:users)
        ActiveRecord::Migration.drop_table(:groups)
        ActiveRecord::Migration.drop_table(:conflicts)
      end

      it "should find the one record that is related based on forward groups relation" do
        User.search_for('related=value AND related="value too!"').length.should == 1
      end
    end

    context 'querying a :has_many => :through relation with modules' do

      before do

        # Create some tables with namespaces
        ActiveRecord::Migration.create_table(:zan_mars) { |t| t.integer :koo_id; t.integer :baz_id }
        ActiveRecord::Migration.create_table(:zan_bazs) { |t| t.string :related }
        ActiveRecord::Migration.create_table(:zan_koos) { |t| t.string :foo }   

        # The related classes
        module Zan; class Mar < ActiveRecord::Base; belongs_to :baz; belongs_to :koo; self.table_name = "zan_mars"; end; end
        module Zan; class Baz < ActiveRecord::Base; has_many :mars; self.table_name = "zan_bazs"; end; end

        # The class on which to call search_for
        module Zan
          class Koo < ActiveRecord::Base
            has_many :mars, :class_name => "Zan::Mar"
            has_many :bazs, :through => :mars
            self.table_name = "zan_koos"

            scoped_search :relation => :bazs, :on => :related
          end
        end

        @koo_1 = Zan::Koo.create!(:foo => 'foo')
        @koo_2 = Zan::Koo.create!(:foo => 'foo too')
        @koo_3 = Zan::Koo.create!(:foo => 'foo three')

        @baz_1 = Zan::Baz.create(:related => 'baz')
        @baz_2 = Zan::Baz.create(:related => 'baz too!')

        @bar_1 = Zan::Mar.create!(:koo => @koo_1, :baz => @baz_1)
        @bar_2 = Zan::Mar.create!(:koo => @koo_1)
        @bar_3 = Zan::Mar.create!(:koo => @koo_2, :baz => @baz_1)
        @bar_3 = Zan::Mar.create!(:koo => @koo_2, :baz => @baz_2)
        @bar_3 = Zan::Mar.create!(:koo => @koo_2, :baz => @baz_2)
        @bar_4 = Zan::Mar.create!(:koo => @koo_3)
      end

      after do
        ActiveRecord::Migration.drop_table(:zan_bazs)
        ActiveRecord::Migration.drop_table(:zan_mars)
        ActiveRecord::Migration.drop_table(:zan_koos)
      end

      it "should find the two records that are related to a baz record" do
        Zan::Koo.search_for('baz').length.should == 2
      end

      it "should find the one record that is related to two baz records" do
        Zan::Koo.search_for('related=baz AND related="baz too!"').length.should == 1
      end
    end

    context 'querying a :has_many => :through with polymorphism' do
      before do
        ActiveRecord::Migration.create_table(:subnets) { |t| t.string :name }
        ActiveRecord::Migration.create_table(:domains) { |t| t.string :name }
        ActiveRecord::Migration.create_table(:taxable_taxonomies) { |t| t.integer :taxable_id; t.integer :taxonomy_id; t.string :taxable_type }
        ActiveRecord::Migration.create_table(:taxonomies) { |t| t.string :type; t.string :name }

        module Taxonomix
          def self.included(base)
            base.class_eval do
              has_many :taxable_taxonomies, :as => :taxable
              has_many :locations, -> { where(:type => 'Location') }, :through => :taxable_taxonomies, :source => :taxonomy
              has_many :organizations, -> { where(:type => 'Organization') }, :through => :taxable_taxonomies, :source => :taxonomy

              scoped_search :relation => :locations, :on => :id, :rename => :location_id
              scoped_search :relation => :organizations, :on => :id, :rename => :organization_id
            end
          end
        end

        class Subnet < ActiveRecord::Base
          include Taxonomix
        end

        class Domain < ActiveRecord::Base
          include Taxonomix
        end

        class TaxableTaxonomy < ActiveRecord::Base
          belongs_to :taxonomy
          belongs_to :taxable, :polymorphic => true
        end

        class Taxonomy < ActiveRecord::Base
          has_many :taxable_taxonomies
          has_many :subnets, :through => :taxable_taxonomies, :source => :taxable, :source_type => 'Subnet'
        end

        class Organization < Taxonomy; end
        class Location < Taxonomy; end

        @loc_a = Location.create!(:name => 'Location A')
        @loc_b = Location.create!(:name => 'Location B')
        @org_a = Organization.create!(:name => 'Organization A')
        @org_b = Organization.create!(:name => 'Organization B')

        @subnet_a = Subnet.create!(:name => 'Subnet A')
        @subnet_b = Subnet.create!(:name => 'Subnet B')

        @domain_a = Domain.create!(:name => 'Domain A')
        @domain_b = Domain.create!(:name => 'Domain B')

        TaxableTaxonomy.create!(:taxable_id => @subnet_a.id, :taxonomy_id => @loc_a.id, :taxable_type => 'Subnet')
        TaxableTaxonomy.create!(:taxable_id => @subnet_b.id, :taxonomy_id => @loc_b.id, :taxable_type => 'Subnet')
        TaxableTaxonomy.create!(:taxable_id => @subnet_a.id, :taxonomy_id => @org_a.id, :taxable_type => 'Subnet')
        TaxableTaxonomy.create!(:taxable_id => @subnet_b.id, :taxonomy_id => @org_b.id, :taxable_type => 'Subnet')

        TaxableTaxonomy.create!(:taxable_id => @domain_a.id, :taxonomy_id => @loc_a.id, :taxable_type => 'Domain')
        TaxableTaxonomy.create!(:taxable_id => @domain_b.id, :taxonomy_id => @loc_b.id, :taxable_type => 'Domain')
        TaxableTaxonomy.create!(:taxable_id => @domain_a.id, :taxonomy_id => @org_a.id, :taxable_type => 'Domain')
        TaxableTaxonomy.create!(:taxable_id => @domain_b.id, :taxonomy_id => @org_b.id, :taxable_type => 'Domain')
      end

      after do
        ActiveRecord::Migration.drop_table :subnets
        ActiveRecord::Migration.drop_table :domains
        ActiveRecord::Migration.drop_table :taxable_taxonomies
        ActiveRecord::Migration.drop_table :taxonomies
      end

      it "should find the records based on location id" do
        Subnet.search_for("location_id = #{@loc_a.id}").length.should == 1
      end

      it "should find the records based on organization id" do
        Subnet.search_for("organization_id = #{@org_a.id}").length.should == 1
      end
    end

    context 'querying with multiple :has_many => :through and polymorphism' do
      before do
        ActiveRecord::Migration.create_table(:usergroups) { |t| t.string :name }
        ActiveRecord::Migration.create_table(:usergroup_members) { |t| t.integer :usergroup_id; t.integer :member_id; t.string :member_type }
        ActiveRecord::Migration.create_table(:usermats) { |t| t.string :username }
        ActiveRecord::Migration.create_table(:cached_usergroup_members) { |t| t.integer :usergroup_id; t.integer :usermat_id }

        class Usergroup < ActiveRecord::Base
          has_many :usergroup_members
          has_many :usermats, :through => :usergroup_members, :source => :member, :source_type => 'Usermat'
          has_many :usergroups, :through => :usergroup_members, :source => :member, :source_type => 'Usergroup'

          has_many :cached_usergroup_members
          has_many :cached_usergroups, :through => :cached_usergroup_members, :source => :usergroup
          has_many :cached_usergroup_members, :foreign_key => 'usergroup_id'
        end

        class UsergroupMember < ActiveRecord::Base
          belongs_to :member, :polymorphic => true
          belongs_to :usergroup
        end

        class Usermat < ActiveRecord::Base
          has_many :usergroup_member, :as => :member
          has_many :cached_usergroup_members
          has_many :cached_usergroups, :through => :cached_usergroup_members, :source => :usergroup

          scoped_search :relation => :cached_usergroups, :on => :name, :rename => :usergroup_name
        end

        class CachedUsergroupMember < ActiveRecord::Base
          belongs_to :usermat
          belongs_to :usergroup
        end

        @group_1 = Usergroup.create!(:name => 'first')
        @group_2 = Usergroup.create!(:name => 'second')
        @group_3 = Usergroup.create!(:name => 'third')
        @group_4 = Usergroup.create!(:name => 'fourth')

        @usermat_1 = Usermat.create(:username => 'user A')
        @usermat_2 = Usermat.create(:username => 'user B')

        UsergroupMember.create!(:usergroup_id => @group_2.id, :member_id => @group_3.id, :member_type => 'Usergroup')
        UsergroupMember.create!(:usergroup_id => @group_1.id, :member_id => @usermat_2, :member_type => 'Usermat')
        UsergroupMember.create!(:usergroup_id => @group_4.id, :member_id => @usermat_1, :member_type => 'Usermat')

        CachedUsergroupMember.create!(:usergroup_id => @group_1.id, :usermat_id => @usermat_1.id)
      end

      after do
        ActiveRecord::Migration.drop_table :usergroups
        ActiveRecord::Migration.drop_table :usergroup_members
        ActiveRecord::Migration.drop_table :usermats
        ActiveRecord::Migration.drop_table :cached_usergroup_members
      end

      it "should find the usermat when searching on usergroup" do
        result = Usermat.search_for("usergroup_name = #{@group_1.name}")
        result.length.should == 1
        result.first.username.should == @usermat_1.username
      end
    end
  end
end
