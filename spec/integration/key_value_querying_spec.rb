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

      context 'querying a key-value schema' do

        before(:all) do
          ActiveRecord::Migration.create_table(:keys) { |t| t.string :name }
          class ::Key < ActiveRecord::Base; has_many :facts; end

          ActiveRecord::Migration.create_table(:facts) { |t| t.string :value; t.integer :key_id; t.integer :item_id }
          class ::Fact < ActiveRecord::Base
            belongs_to :key
            belongs_to :item, :class_name => "MyItem", :foreign_key => :item_id
          end

          # The class that will run the queries
          ActiveRecord::Migration.create_table(:items) { |t| t.string :name }
          class ::Item < ActiveRecord::Base
            has_many :facts
            has_many :keys, :through => :facts

            scoped_search :in => :facts, :on => :value, :rename => :facts, :in_key => :keys, :on_key => :name, :complete_value => true
          end
          class ::MyItem < ::Item
          end

          @key1 = Key.create!(:name => 'color')
          @key2 = Key.create!(:name => 'size')

          @kv1 = MyItem.create!(:name => 'bar')
          @kv2 = MyItem.create!(:name => 'barbary')

          Fact.create!(:value => 'green', :key => @key1, :item => @kv1)
          Fact.create!(:value => 'gold' , :key => @key1, :item => @kv2)
          Fact.create!(:value => '5'    , :key => @key2, :item => @kv1)

        end

        after(:all) do
          ScopedSearch::RSpec::Database.drop_model(Item)
          ScopedSearch::RSpec::Database.drop_model(Fact)
          ScopedSearch::RSpec::Database.drop_model(Key)
          Object.send :remove_const, :Fact
          Object.send :remove_const, :Key
          Object.send :remove_const, :Item
          Object.send :remove_const, :MyItem
        end

        it "should find all bars with a fact name color and fact value green" do
          Item.search_for('facts.color = green').length.should == 1
        end

        it "should find all bars with a fact name color and fact value gold" do
          Item.search_for('facts.color = gold').first.name.should eql('barbary')
        end

        it "should find all bars with a fact name size and fact value 5" do
          Item.search_for('facts.size = 5').length.should == 1
        end

        it "should find all bars with a fact color green and fact size 5" do
          Item.search_for('facts.color = green and facts.size = 5').length.should == 1
        end

        it "should find all bars with a fact color gold or green" do
          Item.search_for('facts.color = gold or facts.color = green').length.should == 2
        end

        it "should find all bars that has size value" do
          Item.search_for('has facts.size').length.should == 1
        end

        it "should find all bars that has color value" do
          Item.search_for('has facts.color').length.should == 2
        end

        it "should complete facts names" do
          Item.complete_for('facts.').length.should == 2
        end

        it "should complete values for fact name = color" do
          Item.complete_for('facts.color = ').length.should == 2
        end

        it "should find all bars with a fact name color and fact value gold of descendant class" do
          if ActiveRecord::VERSION::MAJOR == 3
            MyItem.search_for('facts.color = gold').first.name.should eql('barbary')
          end
        end

      end

    end
  end

