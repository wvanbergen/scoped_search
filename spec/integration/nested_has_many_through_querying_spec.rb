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

    context 'quering on associations which are behind multiple has-many-through associations' do

      before(:all) do
        ActiveRecord::Migration.create_table(:sources) { |t| t.string :name }
        ActiveRecord::Migration.create_table(:first_jumps) { |t| t.string :name; t.integer :source_id }
        ActiveRecord::Migration.create_table(:join_jumps) { |t| t.string :name; t.integer :first_jump_id; t.integer :destination_id }
        ActiveRecord::Migration.create_table(:destinations) { |t| t.string :name; }

        class Source < ActiveRecord::Base
          has_many :first_jumps
          has_many :join_jumps, :through => :first_jumps
          has_many :destinations, :through => :join_jumps

          scoped_search :relation => :first_jumps, :on => :name, :rename => 'first_jump.name'
          scoped_search :relation => :join_jumps, :on => :name, :rename => 'join_jump.name'
          scoped_search :relation => :destinations, :on => :name, :rename => 'destination.name'
        end

        class FirstJump < ActiveRecord::Base
          belongs_to :source
          has_many :join_jumps
          has_many :destinations, :through => :join_jumps
        end

        class JoinJump < ActiveRecord::Base
          has_one :source, :through => :first_jump
          belongs_to :first_jump
          belongs_to :destination
        end

        class Destination < ActiveRecord::Base
          has_many :join_jumps
          has_many :first_jumps, :through => :join_jumps
          has_many :sources, :through => :first_jumps
        end

        @destination1 = Destination.create!(:name => 'dest-1')
        @destination2 = Destination.create!(:name => 'dest-2')
        @destination3 = Destination.create!(:name => 'dest-3')
        @source1 = Source.create!(:name => 'src1')
        @first_jump1 = FirstJump.create!(:name => 'jump-1-1', :source => @source1)
        @first_jump2 = FirstJump.create!(:name => 'jump-1-2', :source => @source1)

        @source2 = Source.create!(:name => 'src2')
        @first_jump_2_1 = FirstJump.create!(:name => 'jump-2-1', :source => @source2)
        @first_jump_2_2 = FirstJump.create!(:name => 'jump-2-2', :source => @source2)
        @first_jump_2_3 = FirstJump.create!(:name => 'jump-2-3', :source => @source2)
        @first_jump_2_4 = FirstJump.create!(:name => 'jump-2-4', :source => @source2)

        JoinJump.create!(:name => 'join-1-1', :destination => @destination1, :first_jump => @first_jump1)
        JoinJump.create!(:name => 'join-1-2', :destination => @destination2, :first_jump => @first_jump2)

        JoinJump.create!(:name => 'join-2-1', :destination => @destination1, :first_jump => @first_jump_2_1)
        JoinJump.create!(:name => 'join-2-2', :destination => @destination2, :first_jump => @first_jump_2_2)
        JoinJump.create!(:name => 'join-2-3', :destination => @destination2, :first_jump => @first_jump_2_3)
        JoinJump.create!(:name => 'join-2-4', :destination => @destination3, :first_jump => @first_jump_2_4)
      end

      after(:all) do
        ScopedSearch::RSpec::Database.drop_model(Source)
        ScopedSearch::RSpec::Database.drop_model(FirstJump)
        ScopedSearch::RSpec::Database.drop_model(JoinJump)
        ScopedSearch::RSpec::Database.drop_model(Destination)
        Object.send :remove_const, :Source
        Object.send :remove_const, :FirstJump
        Object.send :remove_const, :JoinJump
        Object.send :remove_const, :Destination
      end

      it "allows searching on has many through has many" do
        Source.search_for("join_jump.name = join-1-1").should == [@source1]
        Source.search_for("join_jump.name = join-2-1").should == [@source2]
        Source.search_for("join_jump.name ^ (join-1-1, join-2-1)").order(:id).should == [@source1, @source2]
      end

      it "allows searching on has many through has one through has many" do
        Source.search_for("destination.name = dest-1").order(:id).should == [@source1, @source2]
        Source.search_for("destination.name = dest-3").order(:id).should == [@source2]
        Source.search_for("destination.name = dest-3 or destination.name = dest-2").order(:id).should == [@source1, @source2]
        Source.search_for("destination.name = dest-3 and destination.name = dest-2").should == [@source2]
      end
    end
  end
end
