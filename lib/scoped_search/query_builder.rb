module ScopedSearch

  # The QueryBuilder class builds an SQL query based on aquery string that is
  # provided to the search_for named scope. It uses a SearchDefinition instance
  # to shape the query.
  class QueryBuilder

    attr_reader :ast, :definition

    # Creates a find parameter hash that can be passed to ActiveRecord::Base#find,
    # given a search definition and query string. This method is called from the
    # search_for named scope.
    #
    # This method will parse the query string and build an SQL query using the search
    # query. It will return an ampty hash if the search query is empty, in which case
    # the scope call will simply return all records.
    def self.build_query(definition, *args)
      query = args[0]
      options = args[1] || {}
      
      query_builder_class = self.class_for(definition)
      if query.kind_of?(ScopedSearch::QueryLanguage::AST::Node)
        return query_builder_class.new(definition, query, options[:profile]).build_find_params
      elsif query.kind_of?(String)
        return query_builder_class.new(definition, ScopedSearch::QueryLanguage::Compiler.parse(query), options[:profile]).build_find_params
      elsif query.nil?
        return { }
      else
        raise "Unsupported query object: #{query.inspect}!"
      end
    end
    
    # Loads the QueryBuilder class for the connection of the given definition.
    # If no specific adapter is found, the default QueryBuilder class is returned.
    def self.class_for(definition)
      self.const_get(definition.klass.connection.class.name.split('::').last)
    rescue
      self
    end

    # Initializes the instance by setting the relevant parameters
    def initialize(definition, ast, profile)
      @definition, @ast, @definition.profile = definition, ast, profile
    end

    # Actually builds the find parameters hash that should be used in the search_for
    # named scope.
    def build_find_params
      parameters = []
      includes   = []

      # Build SQL WHERE clause using the AST
      sql = @ast.to_sql(self, definition) do |notification, value|

        # Handle the notifications encountered during the SQL generation:
        # Store the parameters, includes, etc so that they can be added to
        # the find-hash later on.
        case notification
        when :parameter then parameters << value
        when :include   then includes   << value
        else raise ScopedSearch::QueryNotSupported, "Cannot handle #{notification.inspect}: #{value.inspect}"
        end
      end

      # Build hash for ActiveRecord::Base#find for the named scope
      find_attributes = {}
      find_attributes[:conditions] = [sql] + parameters unless sql.nil?
      find_attributes[:include]    = includes.uniq      unless includes.empty?
      # p find_attributes # Uncomment for debugging
      return find_attributes
    end

    # A hash that maps the operators of the query language with the corresponding SQL operator.
    SQL_OPERATORS = { :eq =>'=',  :ne => '<>', :like => 'LIKE', :unlike => 'NOT LIKE',
                      :gt => '>', :lt =>'<',   :lte => '<=',    :gte => '>=' }
    
    # Return the SQL operator to use given an operator symbol and field definition.
    #
    # By default, it will simply look up the correct SQL operator in the SQL_OPERATORS
    # hash, but this can be overrided by a database adapter.
    def sql_operator(operator, field)
      SQL_OPERATORS[operator]
    end

    # Perform a comparison between a field and a Date(Time) value.
    #
    # This function makes sure the date is valid and adjust the comparison in
    # some cases to return more logical results.
    #
    # This function needs a block that can be used to pass other information about the query
    # (parameters that should be escaped, includes) to the query builder.
    #
    # <tt>field</tt>:: The field to test.
    # <tt>operator</tt>:: The operator used for comparison.
    # <tt>value</tt>:: The value to compare the field with.
    def datetime_test(field, operator, value, &block) # :yields: finder_option_type, value

      # Parse the value as a date/time and ignore invalid timestamps
      timestamp = parse_temporal(value)
      return nil unless timestamp
      timestamp = Date.parse(timestamp.strftime('%Y-%m-%d')) if field.date?

      # Check for the case that a date-only value is given as search keyword,
      # but the field is of datetime type. Change the comparison to return
      # more logical results.
      if timestamp.day_fraction == 0 && field.datetime?

        if [:eq, :ne].include?(operator)
          # Instead of looking for an exact (non-)match, look for dates that
          # fall inside/outside the range of timestamps of that day.
          yield(:parameter, timestamp)
          yield(:parameter, timestamp + 1)
          negate    = (operator == :ne) ? 'NOT ' : ''
          field_sql = field.to_sql(operator, &block)
          return "#{negate}(#{field_sql} >= ? AND #{field_sql} < ?)"

        elsif operator == :gt
          # Make sure timestamps on the given date are not included in the results
          # by moving the date to the next day.
          timestamp += 1
          operator = :gte

        elsif operator == :lte
          # Make sure the timestamps of the given date are included by moving the
          # date to the next date.
          timestamp += 1
          operator = :lt
        end
      end

      # Yield the timestamp and return the SQL test
      yield(:parameter, timestamp)
      "#{field.to_sql(operator, &block)} #{sql_operator(operator, field)} ?"
    end

    # Generates a simple SQL test expression, for a field and value using an operator.
    #
    # This function needs a block that can be used to pass other information about the query
    # (parameters that should be escaped, includes) to the query builder.
    #
    # <tt>field</tt>:: The field to test.
    # <tt>operator</tt>:: The operator used for comparison.
    # <tt>value</tt>:: The value to compare the field with.
    def sql_test(field, operator, value, &block) # :yields: finder_option_type, value
      if [:like, :unlike].include?(operator) && value !~ /^\%/ && value !~ /\%$/
        yield(:parameter, "%#{value}%")
        return "#{field.to_sql(operator, &block)} #{self.sql_operator(operator, field)} ?"
      elsif field.temporal?
        return datetime_test(field, operator, value, &block)
      else
        yield(:parameter, value)
        return "#{field.to_sql(operator, &block)} #{self.sql_operator(operator, field)} ?"
      end
    end

    # Try to parse a string as a datetime.
    def parse_temporal(value)
      DateTime.parse(value, true) rescue nil
    end

    # This module gets included into the Field class to add SQL generation.
    module Field

      # Return an SQL representation for this field. Also make sure that
      # the relation which includes the search field is included in the
      # SQL query.
      #
      # This function may yield an :include that should be used in the
      # ActiveRecord::Base#find call, to make sure that the field is avalable
      # for the SQL query.
      def to_sql(operator = nil, &block) # :yields: finder_option_type, value
        yield(:include, relation) if relation
        definition.klass.connection.quote_table_name(klass.table_name.to_s) + "." +
            definition.klass.connection.quote_column_name(field.to_s)
      end
    end

    # This module contains modules for every AST::Node class to add SQL generation.
    module AST

      # Defines the to_sql method for AST LeadNodes
      module LeafNode
        def to_sql(builder, definition, &block)
          # Search keywords found without context, just search on all the default fields
          fragments = definition.default_fields_for(value).map do |field|
            builder.sql_test(field, field.default_operator, value, &block)
          end

          case fragments.length
            when 0 then nil
            when 1 then fragments.first
            else "#{fragments.join(' OR ')}"
          end
        end
      end

      # Defines the to_sql method for AST operator nodes
      module OperatorNode

        # Returns a NOT (...)  SQL fragment that negates the current AST node's children
        def to_not_sql(builder, definition, &block)
          "NOT COALESCE(#{rhs.to_sql(builder, definition, &block)}, 0)"
        end

        # Returns an IS (NOT) NULL SQL fragment
        def to_null_sql(builder, definition, &block)
          field = definition.fields[rhs.value.to_sym]
          raise ScopedSearch::QueryNotSupported, "Field '#{rhs.value}' not recognized for searching!" unless field

          case operator
            when :null    then "#{field.to_sql(builder, &block)} IS NULL"
            when :notnull then "#{field.to_sql(builder, &block)} IS NOT NULL"
          end
        end

        # No explicit field name given, run the operator on all default fields
        def to_default_fields_sql(builder, definition, &block)
          raise ScopedSearch::QueryNotSupported, "Value not a leaf node" unless rhs.kind_of?(ScopedSearch::QueryLanguage::AST::LeafNode)

          # Search keywords found without context, just search on all the default fields
          fragments = definition.default_fields_for(rhs.value, operator).map { |field|
                          builder.sql_test(field, operator, rhs.value, &block) }.compact

          case fragments.length
            when 0 then nil
            when 1 then fragments.first
            else "#{fragments.join(' OR ')}"
          end
        end

        # Explicit field name given, run the operator on the specified field only
        def to_single_field_sql(builder, definition, &block)
          raise ScopedSearch::QueryNotSupported, "Field name not a leaf node" unless lhs.kind_of?(ScopedSearch::QueryLanguage::AST::LeafNode)
          raise ScopedSearch::QueryNotSupported, "Value not a leaf node"      unless rhs.kind_of?(ScopedSearch::QueryLanguage::AST::LeafNode)

          # Search only on the given field.
          field = definition.fields[lhs.value.to_sym]
          raise ScopedSearch::QueryNotSupported, "Field '#{lhs.value}' not recognized for searching!" unless field
          builder.sql_test(field, operator, rhs.value, &block)
        end

        # Convert this AST node to an SQL fragment.
        def to_sql(builder, definition, &block)
          if operator == :not && children.length == 1
            to_not_sql(builder, definition, &block)
          elsif [:null, :notnull].include?(operator)
            to_null_sql(builder, definition, &block)
          elsif children.length == 1
            to_default_fields_sql(builder, definition, &block)
          elsif children.length == 2
            to_single_field_sql(builder, definition, &block)
          else
            raise ScopedSearch::QueryNotSupported, "Don't know how to handle this operator node: #{operator.inspect} with #{children.inspect}!"
          end
        end
      end

      # Defines the to_sql method for AST AND/OR operators
      module LogicalOperatorNode
        def to_sql(builder, definition, &block)
          fragments = children.map { |c| c.to_sql(builder, definition, &block) }.compact.map { |sql| "(#{sql})" }
          fragments.empty? ? nil : "#{fragments.join(" #{operator.to_s.upcase} ")}"
        end
      end
    end

    # The MysqlAdapter makes sure that case sensitive comparisons are used
    # when using the (not) equals operator, regardless of the field's
    # collation setting.
    class MysqlAdapter < ScopedSearch::QueryBuilder
      
      # Patches the default <tt>sql_operator</tt> method to add
      # <tt>BINARY</tt> after the equals and not equals operator to force
      # case-sensitive comparisons.
      def sql_operator(operator, field)
        if [:ne, :eq].include?(operator) && field.textual?
          "#{SQL_OPERATORS[operator]} BINARY"
        else
          super(operator, field)
        end
      end
    end

    # The PostgreSQLAdapter make sure that searches are case sensitive when
    # using the like/unlike operators, by using the PostrgeSQL-specific
    # <tt>ILIKE operator</tt> instead of <tt>LIKE</tt>.
    class PostgreSQLAdapter < ScopedSearch::QueryBuilder
      
      # Switches out the default LIKE operator for ILIKE in the default
      # <tt>sql_operator</tt> method.
      def sql_operator(operator, field)
        case operator
        when :like   then 'ILIKE'
        when :unlike then 'NOT ILIKE'
        else super(operator, field)
        end
      end
    end
    
    # The Oracle adapter also requires some tweaks to make the case insensitive LIKE work.
    class OracleEnhancedAdapter < ScopedSearch::QueryBuilder
      
      def sql_test(field, operator, value, &block) # :yields: finder_option_type, value
        if field.textual? && [:like, :unlike].include?(operator)
          yield(:parameter, (value !~ /^\%/ && value !~ /\%$/) ? "%#{value}%" : value)
          return "LOWER(#{field.to_sql(operator, &block)}) #{self.sql_operator(operator, field)} LOWER(?)"
        else
          return super(field, operator, value, &block)
        end
      end
    end
  end

  # Include the modules into the corresponding classes
  # to add SQL generation capabilities to them.

  Definition::Field.send(:include, QueryBuilder::Field)
  QueryLanguage::AST::LeafNode.send(:include, QueryBuilder::AST::LeafNode)
  QueryLanguage::AST::OperatorNode.send(:include, QueryBuilder::AST::OperatorNode)
  QueryLanguage::AST::LogicalOperatorNode.send(:include, QueryBuilder::AST::LogicalOperatorNode)
end
