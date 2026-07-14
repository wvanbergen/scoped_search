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

  describe ScopedSearch, "ext_method with has/not has on a #{db} database" do

    before(:all) do
      ScopedSearch::RSpec::Database.establish_named_connection(db)
    end

    after(:all) do
      ScopedSearch::RSpec::Database.close_connection
    end

    context 'on a direct field' do
      before(:all) do
        @class = ScopedSearch::RSpec::Database.create_model(alpha: :integer) do |klass|
          klass.send(:define_singleton_method, :test_ext_has) do |key, operator, value|
            if value.nil?
              case operator
              when 'IS NOT NULL'
                { conditions: "#{klass.table_name}.alpha > 1" }
              when 'IS NULL'
                { conditions: "#{klass.table_name}.alpha IS NULL OR #{klass.table_name}.alpha <= 1" }
              end
            else
              { conditions: "#{klass.table_name}.alpha = ?", parameter: [value.to_i] }
            end
          end
          klass.scoped_search on: :alpha, ext_method: :test_ext_has
        end

        @included = @class.create!(alpha: 2)
        @excluded = @class.create!(alpha: 1)
        @null_record = @class.create!(alpha: nil)
      end

      after(:all) do
        ScopedSearch::RSpec::Database.drop_model(@class)
      end

      it 'should delegate set? to ext_method' do
        @class.search_for('set? alpha').should == [@included]
      end

      it 'should delegate null? to ext_method' do
        results = @class.search_for('null? alpha')
        results.should include(@excluded)
        results.should include(@null_record)
        results.length.should == 2
      end

      it 'should still find records via value search' do
        @class.search_for('alpha = 2').should == [@included]
      end
    end

    context 'on a relation field' do
      before(:all) do
        @main = ScopedSearch::RSpec::Database.create_model(name: :string) {}

        @related = ScopedSearch::RSpec::Database.create_model(
          value: :string,
          promoted: :boolean,
          main_id: :integer
        ) do |klass|
        end

        related_table = @related.table_name
        main_table = @main.table_name
        related_class = @related
        main_class = @main

        @related.belongs_to main_table.to_sym, foreign_key: :main_id
        @main.has_many related_table.to_sym, foreign_key: :main_id

        @main.send(:define_singleton_method, :test_ext_promoted) do |key, operator, value|
          if value.nil?
            subquery = related_class.where(promoted: true).select(:main_id).to_sql
            case operator
            when 'IS NOT NULL'
              { conditions: "#{main_table}.id IN (#{subquery})" }
            when 'IS NULL'
              { conditions: "#{main_table}.id NOT IN (#{subquery})" }
            end
          else
            { joins: related_table.to_sym,
              conditions: "#{related_table}.value #{operator} ? AND #{related_table}.promoted = ?",
              parameter: [value, true] }
          end
        end

        @main.scoped_search(
          relation: related_table.to_sym,
          on: :value,
          rename: :promoted_items,
          ext_method: :test_ext_promoted
        )

        @record_a = @main.create!(name: 'a')
        @related.create!(value: 'item1', promoted: true, main_id: @record_a.id)

        @record_b = @main.create!(name: 'b')
        @related.create!(value: 'item2', promoted: false, main_id: @record_b.id)

        @record_c = @main.create!(name: 'c')
      end

      after(:all) do
        ScopedSearch::RSpec::Database.drop_model(@related)
        ScopedSearch::RSpec::Database.drop_model(@main)
      end

      it 'should delegate set? to ext_method, not raw relation' do
        @main.search_for('set? promoted_items').should == [@record_a]
      end

      it 'should delegate null? to ext_method, not raw relation' do
        results = @main.search_for('null? promoted_items')
        results.should include(@record_b)
        results.should include(@record_c)
        results.length.should == 2
      end

      it 'should still use ext_method for value search' do
        @main.search_for('promoted_items = item1').should == [@record_a]
        @main.search_for('promoted_items = item2').should == []
      end
    end
  end
end
