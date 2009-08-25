module ScopedSearch
  module Adapter

    def self.setup(connection)
      adapter = connection.class.name.split('::').last
      const_get(adapter).setup(connection) if const_defined?(adapter)
    end

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
    
    module PostgreSQLAdapter
      def setup(connection)
        ScopedSearch::QueryBuilder.send :extend, QueryBuilderClassMethods
      end
      
      module QueryBuilderClassMethods
        def sql_operator(sql_operator, field)
          case operator
          when :eq;     '='  
          when :like;   'ILIKE'              
          when :unlike; 'NOT ILIKE'              
          when :ne;     '<>'  
          when :gt;     '>'
          when :lt;     '<'
          when :lte;    '<='
          when :gte;    '>='
          end
        end
      end
    end
  end
end
