require "#{File.dirname(__FILE__)}/../spec_helper"

# These specs will run on all databases that are defined in the spec/database.yml file.
# Comment out any databases that you do not have available for testing purposes if needed.
ScopedSearch::RSpec::Database.test_databases.each do |db|

  describe ScopedSearch, "using a #{db} database" do

    before(:all) do
      ScopedSearch::RSpec::Database.establish_named_connection(db)
    
      @class = ScopedSearch::RSpec::Database.create_model(:string => :string, :another => :string, :explicit => :string) do |klass|
        klass.scoped_search :on => :string
        klass.scoped_search :on => :another,  :default_operator => :eq, :alias => :alias, :default_order => :desc
        klass.scoped_search :on => :explicit, :only_explicit => true
      end

      @class.create!(:string => 'foo', :another => 'temp 1', :explicit => 'baz')
      @class.create!(:string => 'bar', :another => 'temp 2', :explicit => 'baz')
      @class.create!(:string => 'baz', :another => nil,      :explicit => nil)
    end

    after(:all) do
      ScopedSearch::RSpec::Database.drop_model(@class)
      ScopedSearch::RSpec::Database.close_connection
    end

    context 'in an implicit string field' do
      it "should find the record with an exact string match" do
        @class.search_for('foo').should have(1).item
      end

      it "should find the other two records using NOT with an exact string match" do
        @class.search_for('-foo').should have(2).item
      end

      it "should find the record with an exact string match and an explicit field operator" do
        @class.search_for('string = foo').should have(1).item
      end

      it "should find the record with an exact string match and an explicit field operator" do
        @class.search_for('another = foo').should have(0).items
      end

      it "should find the record with an partial string match" do
        @class.search_for('fo').should have(1).item
      end

      it "should find the other two records using NOT with an partial string match" do
        @class.search_for('-fo').should have(2).item
      end

      it "should not find the record with an explicit equals operator and a partial match" do
        @class.search_for('= fo').should have(0).items
      end

      it "should find the record with an explicit LIKE operator and a partial match" do
        @class.search_for('~ fo').should have(1).items
      end

      it "should find the all other record with an explicit NOT LIKE operator and a partial match" do
        @class.search_for('string !~ fo').should have(@class.count - 1).items
      end

      it "should not find a record with a non-match" do
        @class.search_for('nonsense').should have(0).items
      end

      it "should find two records if it partially matches them" do
        @class.search_for('ba').should have(2).item
      end

      it "should find no records starting with an a" do
        @class.search_for('a%').should have(0).item
      end

      it "should find one records ending with an oo" do
        @class.search_for('%oo').should have(1).item
      end

      it "should find records without case sensitivity when using the LIKE operator" do
        @class.search_for('string ~ FOO').should have(1).item
      end

      it "should not find records without case sensitivity when using the = operator" do
        @class.search_for('string = FOO').should have(0).items
      end

      it "should find records without case sensitivity when using the != operator" do
        @class.search_for('string != FOO').should have(3).items
      end

      it "should find records without case sensitivity when using the NOT LIKE operator" do
        @class.search_for('string !~ FOO').should have(2).items
      end

      it "should find the record if one of the query words match using OR" do
        @class.search_for('foo OR nonsense').should have(1).item
      end

      it "should find no records in one of the AND conditions isn't met" do
        @class.search_for('foo AND nonsense').should have(0).item
      end

      it "should find two records every single OR conditions matches one single record" do
        @class.search_for('foo OR baz').should have(2).item
      end

      it "should find two records every single AND conditions matches one single record" do
        @class.search_for('foo AND baz').should have(0).item
      end
    end

    context 'in a field with a different default operator' do
      it "should find an exact match" do
        @class.search_for('"temp 1"').should have(1).item
      end

      it "should find the orther records using NOT and an exact match" do
        @class.search_for('-"temp 1"').should have(2).item
      end

      it "should find an explicit match" do
        @class.search_for('another = "temp 1"').should have(1).item
      end

      it "should not find a partial match" do
        @class.search_for('temp').should have(0).item
      end

      it "should find all records using a NOT with a partial match on all records" do
        @class.search_for('-temp"').should have(3).item
      end

      it "should find a partial match when the like operator is given" do
        @class.search_for('~ temp').should have(2).item
      end
      
      it "should find a negation of partial match when the like operator is give with an explicit NOT operator" do
        @class.search_for('!(~ temp)').should have(1).item
      end

      it "should find a partial match when the like operator and the field name is given" do
        @class.search_for('another ~ temp').should have(2).item
      end
    end

    context 'using an aliased field' do
      it "should find an explicit match using its alias" do
        @class.search_for('alias = "temp 1"').should have(1).item
      end
    end

    context 'in an explicit string field' do

      it "should not find the records if the explicit field is not given in the query" do
        @class.search_for('= baz').should have(1).item
      end

      it "should find all records when searching on the explicit field" do
        @class.search_for('explicit = baz').should have(2).items
      end

      it "should find no records if the value in the explicit field is not an exact match" do
        @class.search_for('explicit = ba').should have(0).item
      end

      it "should find all records when searching on the explicit field" do
        @class.search_for('explicit ~ ba').should have(2).items
      end

      it "should only find the record with string = foo and explicit = baz" do
        @class.search_for('foo, explicit = baz').should have(1).item
      end
    end

    context 'using null? and set? queries' do

      it "should return all records if the string field is being checked with set?" do
        @class.search_for('set? string').should have(3).items
      end

      it "should return no records if the string field is being checked with null?" do
        @class.search_for('null? string').should have(0).items
      end

      it "should return all records with a value if the string field is being checked with set?" do
        @class.search_for('set? explicit').should have(2).items
      end

      it "should return all records without a value if the string field is being checked with null?" do
        @class.search_for('null? explicit').should have(1).items
      end
    end
    context 'using order' do
      it "sort by string ASC" do
        @class.search_for('',:order => 'string ASC').first.string.should eql('bar')
      end

      it "sort by string DESC" do
        @class.search_for('',:order => 'string DESC').first.string.should eql('foo')
      end

       it "default order by another DESC" do
        @class.search_for('').first.string.should eql('bar')
      end

       it "group by explicit" do
        @class.search_for('',:group => 'explicit').should have(2).items
      end
    end
  end
end
