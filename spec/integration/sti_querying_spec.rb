require "spec_helper"

# These specs will run on all databases that are defined in the spec/database.yml file.
# Comment out any databases that you do not have available for testing purposes if needed.
ScopedSearch::RSpec::Database.test_databases.each do |db|

  describe ScopedSearch, "using a #{db} database" do

    before(:all) do
      ScopedSearch::RSpec::Database.establish_named_connection(db)

      @related_class = ScopedSearch::RSpec::Database.create_model(int: :integer)

      @parent_class = ScopedSearch::RSpec::Database.create_model(int: :integer, type: :string, related_id: :integer) do |klass|
        klass.scoped_search on: :int
      end
      @subclass1 = ScopedSearch::RSpec::Database.create_sti_model(@parent_class)
      @subclass2 = ScopedSearch::RSpec::Database.create_sti_model(@parent_class) do |klass|
        klass.belongs_to @related_class.table_name.to_sym, foreign_key: :related_id
        klass.scoped_search on: :int, rename: :other_int
        klass.scoped_search relation: @related_class.table_name, on: :int, rename: :related_int
      end

      @related_class.has_many @subclass1.table_name.to_sym

      @record1 = @subclass1.create!(int: 7)
      @related_record1 = @related_class.create!(int: 42)
      @record2 = @subclass2.create!(int: 9, related_id: @related_record1.id)
    end

    after(:all) do
      @record1.destroy
      @record2.destroy

      ScopedSearch::RSpec::Database.drop_model(@parent_class)
      ScopedSearch::RSpec::Database.drop_model(@related_class)
      ScopedSearch::RSpec::Database.close_connection
    end

    context 'querying STI parent and subclasses' do
      it "should find a record using the parent class" do
        @parent_class.search_for('int = 7').should eq([@record1])
      end

      it "should find a record using the subclass" do
        @subclass1.search_for('int = 7').should eq([@record1])
      end

      it "should not find a record using the wrong subclass" do
        @subclass2.search_for('int = 7').should eq([])
        @subclass2.search_for('int = 9').should eq([@record2])
      end

      it "parent should not recognize field from subclass" do
        lambda { @parent_class.search_for('related_int = 9') }.should raise_error(ScopedSearch::QueryNotSupported, "Field 'related_int' not recognized for searching!")
      end

      it "should autocomplete int field on parent" do
        @parent_class.complete_for('').should contain(' int ')
      end

      it "should autocomplete int field on subclass" do
        @subclass1.complete_for('').should contain(' int ')
      end

      it "should autocomplete int, other_int, related_int fields on subclass" do
        @subclass2.complete_for('').should contain(' int ')
        @subclass2.complete_for('').should contain(' other_int ')
        @subclass2.complete_for('').should contain(' related_int ')
      end
    end

    context 'querying definition on STI subclass' do
      it "should find a record using subclass definition" do
        @subclass2.search_for('other_int = 9').should eq([@record2])
      end

      it "should find a record via relation" do
        @subclass2.search_for('related_int = 42').should eq([@record2])
      end
    end
  end
end
