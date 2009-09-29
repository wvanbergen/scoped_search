# The ScopedSearch::Adapter module contains adapters for the different
# database backends that can be used, to ensure that the experience on
# DBMSs are compatible.
module ScopedSearch::Adapter

  # Loads the appropriate database adapter for scoped search given the
  # current database connection, and calls its setup method to adapt
  # things as needed.
  def self.setup(connection)
    adapter = connection.class.name.split('::').last
    const_get(adapter).setup(connection) if const_defined?(adapter)
  end

  # The MySQL adapter changes the equals operator to make sure it is
  # case sensitive, whatever column collation is used.
  module MysqlAdapter

    def self.setup(connection)
      ScopedSearch::Definition::Field.send :include, FieldInstanceMethods
    end

    module FieldInstanceMethods

      # Monkey patch Field#to_sql method to ensure that comparisons using :eq / :ne
      # are case sensitive by adding a BINARY operator in front of the field name.
      def to_sql(operator = nil, &block)

        # Normal implementation
        yield(:include, relation) if relation
        field_name = definition.klass.connection.quote_table_name(klass.table_name) + "." +
            definition.klass.connection.quote_column_name(field)

        # Add BINARY operator if the field is textual and = or <> is used.
        field_name = "BINARY #{field_name}" if textual? && [:ne, :eq].include?(operator)
        return field_name
      end
    end

  end

  # The PostgreSQL adapter uses the ILKE operator instead of the LIKE operator that
  # is used by default, to make sure that queries are case-insensitive.
  module PostgreSQLAdapter

    # Change the LIKE operator to ILIKE.
    def self.setup(connection)
      ScopedSearch::QueryBuilder::SQL_OPERATORS[:like] = 'ILIKE'
      ScopedSearch::QueryBuilder::SQL_OPERATORS[:unlike] = 'NOT ILIKE'
    end
  end
end
