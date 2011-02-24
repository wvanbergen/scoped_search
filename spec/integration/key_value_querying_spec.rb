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

          ActiveRecord::Migration.create_table(:facts) { |t| t.string :value; t.integer :key_id; t.integer :bar_id }
          class ::Fact < ActiveRecord::Base; belongs_to :key; belongs_to :bar; end

          # The class that will run the queries
          ::Bar = ScopedSearch::RSpec::Database.create_model(:name => :string) do |klass|
            klass.has_many :facts
            klass.has_many :keys, :through => :facts
            klass.scoped_search :in => :facts, :on => :value, :rename => :facts, :in_key => :keys, :on_key => :name, :complete_value => true
          end

          @key1 = Key.create!(:name => 'color')
          @key2 = Key.create!(:name => 'size')


          @bar1 = Bar.create!(:name => 'bar')
          @bar2 = Bar.create!(:name => 'barbary')

          Fact.create!(:value => 'green', :key => @key1, :bar => @bar1)
          Fact.create!(:value => 'gold' , :key => @key1, :bar => @bar2)
          Fact.create!(:value => '5'    , :key => @key2, :bar => @bar1)

        end

        after(:all) do
          ScopedSearch::RSpec::Database.drop_model(Bar)
          ScopedSearch::RSpec::Database.drop_model(Fact)
          ScopedSearch::RSpec::Database.drop_model(Key)
          Object.send :remove_const, :Fact
          Object.send :remove_const, :Key
          Object.send :remove_const, :Bar
        end

        it "should find all bars with a fact name color and fact value green" do
          Bar.search_for('facts.color = green').should have(1).items
        end

        it "should find all bars with a fact name size and fact value 5" do
            Bar.search_for('facts.size = 5').should have(1).items
        end

        it "should find all bars with a fact color green and fact size 5" do
          Bar.search_for('facts.color = green and facts.size = 5').should have(1).items
        end

        it "should find all bars that has size value" do
          Bar.search_for('has facts.size').should have(1).items
        end

        it "should find all bars that has color value" do
          Bar.search_for('has facts.color').should have(2).items
        end

        it "should complete facts names" do
          Bar.complete_for('facts.').should have(2).items
        end

         it "should complete values for fact name = color" do
          Bar.complete_for('facts.color = ').should have(2).items
        end

      end

    end
  end

