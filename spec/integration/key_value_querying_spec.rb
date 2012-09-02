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

      context 'querying a key-value schema' do

        before(:all) do
          ActiveRecord::Migration.create_table(:keys) { |t| t.string :name }
          class ::Key < ActiveRecord::Base; has_many :facts; end

          ActiveRecord::Migration.create_table(:facts) { |t| t.string :value; t.integer :key_id; t.integer :key_value_id }
          class ::Fact < ActiveRecord::Base; belongs_to :key; belongs_to :key_value; end

          # The class that will run the queries
          ::KeyValue = ScopedSearch::RSpec::Database.create_model(:name => :string) do |klass|
            klass.has_many :facts
            klass.has_many :keys, :through => :facts
            klass.scoped_search :in => :facts, :on => :value, :rename => :facts, :in_key => :keys, :on_key => :name, :complete_value => true
          end

          @key1 = Key.create!(:name => 'color')
          @key2 = Key.create!(:name => 'size')


          @kv1 = KeyValue.create!(:name => 'bar')
          @kv2 = KeyValue.create!(:name => 'barbary')

          Fact.create!(:value => 'green', :key => @key1, :key_value => @kv1)
          Fact.create!(:value => 'gold' , :key => @key1, :key_value => @kv2)
          Fact.create!(:value => '5'    , :key => @key2, :key_value => @kv1)

        end

        after(:all) do
          ScopedSearch::RSpec::Database.drop_model(KeyValue)
          ScopedSearch::RSpec::Database.drop_model(Fact)
          ScopedSearch::RSpec::Database.drop_model(Key)
          Object.send :remove_const, :Fact
          Object.send :remove_const, :Key
          Object.send :remove_const, :KeyValue
        end

        it "should find all bars with a fact name color and fact value green" do
          KeyValue.search_for('facts.color = green').should have(1).items
        end

         it "should find all bars with a fact name color and fact value gold" do
          KeyValue.search_for('facts.color = gold').first.name.should eql('barbary')
        end

        it "should find all bars with a fact name size and fact value 5" do
          KeyValue.search_for('facts.size = 5').should have(1).items
        end

        it "should find all bars with a fact color green and fact size 5" do
          KeyValue.search_for('facts.color = green and facts.size = 5').should have(1).items
        end

        it "should find all bars with a fact color gold or green" do
          KeyValue.search_for('facts.color = gold or facts.color = green').should have(2).items
        end

        it "should find all bars that has size value" do
          KeyValue.search_for('has facts.size').should have(1).items
        end

        it "should find all bars that has color value" do
          KeyValue.search_for('has facts.color').should have(2).items
        end

        it "should complete facts names" do
          KeyValue.complete_for('facts.').should have(2).items
        end

         it "should complete values for fact name = color" do
          KeyValue.complete_for('facts.color = ').should have(2).items
        end

      end

    end
  end

