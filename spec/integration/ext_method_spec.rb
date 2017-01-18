require "spec_helper"

# These specs will run on all databases that are defined in the spec/database.yml file.
# Comment out any databases that you do not have available for testing purposes if needed.
ScopedSearch::RSpec::Database.test_databases.each do |db|

  describe ScopedSearch, "using a #{db} database" do

    before(:all) do
      ScopedSearch::RSpec::Database.establish_named_connection(db)

      @class = ScopedSearch::RSpec::Database.create_model(alpha: :integer, beta_id: :integer) do |klass|
        klass.send(:define_singleton_method, :test_ext_alpha) do |key, operator, value|
          { conditions: "#{key} = ?", parameter: [value.to_i * 2] }
        end
        klass.scoped_search on: :alpha, ext_method: :test_ext_alpha
      end

      @class2 = ScopedSearch::RSpec::Database.create_model(int: :integer) do |klass|
        klass.has_one @class.table_name.to_sym, foreign_key: :beta_id
      end
      c2table = @class2.table_name.to_sym
      @class.belongs_to c2table, foreign_key: :beta_id

      @class.send(:define_singleton_method, :test_ext_beta) do |key, operator, value|
        { joins: c2table, conditions: "#{c2table}.int = ?", parameter: [value.to_i] }
      end
      @class.scoped_search relation: c2table, on: :int, rename: :beta, ext_method: :test_ext_beta

      @class.create!(alpha: 1)
      @beta = @class2.create!(int: 42)
      @two = @class.create!(alpha: 2, beta_id: @beta.id)
    end

    after(:all) do
      ScopedSearch::RSpec::Database.drop_model(@class)
      ScopedSearch::RSpec::Database.drop_model(@class2)
      ScopedSearch::RSpec::Database.close_connection
    end

    it 'should find record via conditions + parameter' do
      @class.search_for('alpha = 1').should == [@two]
    end

    it 'should find record via joins + conditions + parameter' do
      @class.search_for('beta = 42').should == [@two]
    end
  end
end
