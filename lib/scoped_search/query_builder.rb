require 'date_time_precision'

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
    # query. It will return an empty hash if the search query is empty, in which case
    # the scope call will simply return all records.
    def self.build_query(definition, query, options = {})
      query_builder_class = self.class_for(definition)
      if query.kind_of?(ScopedSearch::QueryLanguage::AST::Node)
        return query_builder_class.new(definition, query, options[:profile]).build_find_params(options)
      elsif query.kind_of?(String)
        return query_builder_class.new(definition, ScopedSearch::QueryLanguage::Compiler.parse(query), options[:profile]).build_find_params(options)
      else
        raise ArgumentError, "Unsupported query object: #{query.inspect}!"
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
    def build_find_params(options)
      keyconditions = []
      keyparameters = []
      parameters = []
      includes   = []
      joins   = []

      # Build SQL WHERE clause using the AST
      sql = @ast.to_sql(self, definition) do |notification, value|

        # Handle the notifications encountered during the SQL generation:
        # Store the parameters, includes, etc so that they can be added to
        # the find-hash later on.
        case notification
          when :keycondition then keyconditions << value
          when :keyparameter then keyparameters << value
          when :parameter    then parameters    << value
          when :include      then includes      << value
          when :joins        then joins         << value
          else raise ScopedSearch::QueryNotSupported, "Cannot handle #{notification.inspect}: #{value.inspect}"
        end
      end
        # Build SQL ORDER BY clause
      order = order_by(options[:order]) do |notification, value|
        case notification
          when :parameter then parameters << value
          when :include   then includes   << value
          when :joins     then joins      << value
          else raise ScopedSearch::QueryNotSupported, "Cannot handle #{notification.inspect}: #{value.inspect}"
        end
      end
      sql = (keyconditions + (sql.blank? ? [] : [sql]) ).map {|c| "(#{c})"}.join(" AND ")
      # Build hash for ActiveRecord::Base#find for the named scope
      find_attributes = {}
      find_attributes[:conditions] = [sql] + keyparameters + parameters unless sql.blank?
      find_attributes[:include]    = includes.uniq                      unless includes.empty?
      find_attributes[:joins]      = joins.uniq                         unless joins.empty?
      find_attributes[:order]      = order                              unless order.nil?

      # p find_attributes # Uncomment for debugging
      return find_attributes
    end

    def order_by(order, &block)
      order ||= definition.default_order
      return nil if order.blank?
      field_name, direction_name = order.to_s.split(/\s+/, 2)
      field = definition.field_by_name(field_name)
      raise ScopedSearch::QueryNotSupported, "the field '#{field_name}' in the order statement is not valid field for search" unless field
      sql = field.to_sql(&block)
      direction = (!direction_name.nil? && direction_name.downcase.eql?('desc')) ? " DESC" : " ASC"
      order = sql + direction

      return order
    end

    # A hash that maps the operators of the query language with the corresponding SQL operator.
    SQL_OPERATORS = { :eq => '=',  :ne => '<>', :like => 'LIKE', :unlike => 'NOT LIKE',
                      :gt => '>',  :lt =>'<',   :lte => '<=',    :gte => '>=',
                      :in => 'IN', :notin => 'NOT IN' }

    # Return the SQL operator to use given an operator symbol and field definition.
    #
    # By default, it will simply look up the correct SQL operator in the SQL_OPERATORS
    # hash, but this can be overridden by a database adapter.
    def sql_operator(operator, field)
      raise ScopedSearch::QueryNotSupported, "the operator '#{operator}' is not supported for field type '#{field.type}'" if [:like, :unlike].include?(operator) and !field.textual?
      SQL_OPERATORS[operator]
    end

    # Returns a NOT (...)  SQL fragment that negates the current AST node's children
    def to_not_sql(rhs, definition, &block)
      "NOT COALESCE(#{rhs.to_sql(self, definition, &block)}, 0)"
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
      timestamp = definition.parse_temporal(value)
      return nil unless timestamp

      timestamp = timestamp.to_date if field.date?
      # Check for the case that a date-only value is given as search keyword,
      # but the field is of datetime type. Change the comparison to return
      # more logical results.
      if field.datetime?
        span = datetime_precision_to_span(timestamp)
        if [:eq, :ne].include?(operator)
          # Instead of looking for an exact (non-)match, look for dates that
          # fall inside/outside the range of timestamps of that day.
          yield(:parameter, timestamp)
          yield(:parameter, timestamp + span)
          negate    = (operator == :ne) ? 'NOT ' : ''
          field_sql = field.to_sql(operator, &block)
          return "#{negate}(#{field_sql} >= ? AND #{field_sql} < ?)"

        elsif operator == :gt
          # Make sure timestamps on the given date are not included in the results
          # by moving the date to the next day.
          timestamp += span
          operator = :gte

        elsif operator == :lte
          # Make sure the timestamps of the given date are included by moving the
          # date to the next date.
          timestamp += span
          operator = :lt
        end
      end

      # Yield the timestamp and return the SQL test
      yield(:parameter, timestamp)
      "#{field.to_sql(operator, &block)} #{sql_operator(operator, field)} ?"
    end

    # Based on the precision of a timestamp, suggest a time span for a search tolerance
    # that would be logical to the user
    def datetime_precision_to_span(timestamp)
      case timestamp.precision
        when DateTimePrecision::YEAR then 365.days
        when DateTimePrecision::MONTH then 30.days
        when DateTimePrecision::DAY then 1.day
        when DateTimePrecision::HOUR then 1.hour
        when DateTimePrecision::MIN then 1.minute
        when DateTimePrecision::SEC then 1.second
        else 0.seconds
      end
    end

    # Validate the key name is in the set and translate the value to the set value.
    def translate_value(field, value)
      translated_value = field.complete_value[value.to_sym]
      raise ScopedSearch::QueryNotSupported, "'#{field.field}' should be one of '#{field.complete_value.keys.join(', ')}', but the query was '#{value}'" if translated_value.nil?
      translated_value
    end

    # A 'set' is group of possible values, for example a status might be "on", "off" or "unknown" and the database representation
    # could be for example a numeric value. This method will validate the input and translate it into the database representation.
    def set_test(field, operator,value, &block)
      set_value = translate_value(field, value)
      raise ScopedSearch::QueryNotSupported, "Operator '#{operator}' not supported for '#{field.field}'" unless [:eq,:ne].include?(operator)
      negate = ''
      if [true,false].include?(set_value)
        negate = 'NOT ' if operator == :ne
        if field.numerical?
          operator =  (set_value == true) ?  :gt : :eq
          set_value = 0
        else
          operator = (set_value == true) ? :ne : :eq
          set_value = false
        end
      end
      yield(:parameter, set_value)
      return "#{negate}(#{field.to_sql(operator, &block)} #{self.sql_operator(operator, field)} ?)"
    end

    # Generates a simple SQL test expression, for a field and value using an operator.
    #
    # This function needs a block that can be used to pass other information about the query
    # (parameters that should be escaped, includes) to the query builder.
    #
    # <tt>field</tt>:: The field to test.
    # <tt>operator</tt>:: The operator used for comparison.
    # <tt>value</tt>:: The value to compare the field with.
    def sql_test(field, operator, value, lhs, &block) # :yields: finder_option_type, value
      return field.to_ext_method_sql(lhs, sql_operator(operator, field), value, &block) if field.ext_method

      yield(:keyparameter, lhs.sub(/^.*\./,'')) if field.key_field

      if [:like, :unlike].include?(operator)
        yield(:parameter, (value !~ /^\%|\*/ && value !~ /\%|\*$/) ? "%#{value}%" : value.tr_s('%*', '%'))
        return "#{field.to_sql(operator, &block)} #{self.sql_operator(operator, field)} ?"

      elsif [:in, :notin].include?(operator)
        value.split(',').collect { |v| yield(:parameter, field.set? ? translate_value(field, v) : v.strip) }
        value = value.split(',').collect { "?" }.join(",")
        return "#{field.to_sql(operator, &block)} #{self.sql_operator(operator, field)} (#{value})"

      elsif field.temporal?
        return datetime_test(field, operator, value, &block)

      elsif field.set?
        return set_test(field, operator, value, &block)

      elsif field.relation && definition.reflection_by_name(field.definition.klass, field.relation).macro == :has_many
        value = value.to_i if field.offset
        yield(:parameter, value)
        connection = field.definition.klass.connection
        primary_key = "#{connection.quote_table_name(field.definition.klass.table_name)}.#{connection.quote_column_name(field.definition.klass.primary_key)}"
        if definition.reflection_by_name(field.definition.klass, field.relation).options.has_key?(:through)
          join = has_many_through_join(field)
          return "#{primary_key} IN (SELECT #{primary_key} FROM #{join} WHERE #{field.to_sql(operator, &block)} #{self.sql_operator(operator, field)} ? )"
        else
          foreign_key = connection.quote_column_name(field.reflection_keys(definition.reflection_by_name(field.definition.klass, field.relation))[1])
          return "#{primary_key} IN (SELECT #{foreign_key} FROM #{connection.quote_table_name(field.klass.table_name)} WHERE #{field.to_sql(operator, &block)} #{self.sql_operator(operator, field)} ? )"
        end

      else
        value = value.to_i if field.offset
        yield(:parameter, value)
        return "#{field.to_sql(operator, &block)} #{self.sql_operator(operator, field)} ?"
      end
    end

    def has_many_through_join(field)
      many_class = field.definition.klass
      through = definition.reflection_by_name(many_class, field.relation).options[:through]
      connection = many_class.connection

      # table names
      endpoint_table_name = field.klass.table_name
      many_table_name = many_class.table_name
      middle_table_name = definition.reflection_by_name(many_class, through).klass.table_name

      # primary and foreign keys + optional condition for the many to middle join
      pk1, fk1   = field.reflection_keys(definition.reflection_by_name(many_class, through))
      condition1 = field.reflection_conditions(definition.reflection_by_name(field.klass, many_table_name))

      # primary and foreign keys + optional condition for the endpoint to middle join
      pk2, fk2   = field.reflection_keys(definition.reflection_by_name(field.klass, middle_table_name))
      condition2 = field.reflection_conditions(definition.reflection_by_name(many_class, field.relation))

      <<-SQL
        #{connection.quote_table_name(many_table_name)}
        INNER JOIN #{connection.quote_table_name(middle_table_name)}
        ON #{connection.quote_table_name(many_table_name)}.#{connection.quote_column_name(pk1)} = #{connection.quote_table_name(middle_table_name)}.#{connection.quote_column_name(fk1)} #{condition1}
        INNER JOIN #{connection.quote_table_name(endpoint_table_name)}
        ON #{connection.quote_table_name(middle_table_name)}.#{connection.quote_column_name(fk2)} = #{connection.quote_table_name(endpoint_table_name)}.#{connection.quote_column_name(pk2)} #{condition2}
      SQL
    end

    # This module gets included into the Field class to add SQL generation.
    module Field

      # Return an SQL representation for this field. Also make sure that
      # the relation which includes the search field is included in the
      # SQL query.
      #
      # This function may yield an :include that should be used in the
      # ActiveRecord::Base#find call, to make sure that the field is available
      # for the SQL query.
      def to_sql(operator = nil, &block) # :yields: finder_option_type, value
        num = rand(1000000)
        connection = klass.connection
        if key_relation
          yield(:joins, construct_join_sql(key_relation, num) )
          yield(:keycondition, "#{key_klass.table_name}_#{num}.#{connection.quote_column_name(key_field.to_s)} = ?")
          klass_table_name = relation ? "#{klass.table_name}_#{num}" : klass.table_name
          return "#{connection.quote_table_name(klass_table_name)}.#{connection.quote_column_name(field.to_s)}"
        elsif key_field
          yield(:joins, construct_simple_join_sql(num))
          yield(:keycondition, "#{key_klass.table_name}_#{num}.#{connection.quote_column_name(key_field.to_s)} = ?")
          klass_table_name = relation ? "#{klass.table_name}_#{num}" : klass.table_name
          return "#{connection.quote_table_name(klass_table_name)}.#{connection.quote_column_name(field.to_s)}"
        elsif relation
          yield(:include, relation)
        end
        column_name = connection.quote_table_name(klass.table_name.to_s) + "." + connection.quote_column_name(field.to_s)
        column_name = "(#{column_name} >> #{offset*word_size} & #{2**word_size - 1})" if offset
        column_name
      end

      # This method construct join statement for a key value table
      # It assume the following table structure
      #  +----------+  +---------+ +--------+
      #  | main     |  | value   | | key    |
      #  | main_pk  |  | main_fk | |        |
      #  |          |  | key_fk  | | key_pk |
      #  +----------+  +---------+ +--------+
      # uniq name for the joins are needed in case that there is more than one condition
      # on different keys in the same query.
      def construct_join_sql(key_relation, num)
        join_sql = ""
        connection = klass.connection
        key = key_relation.to_s.singularize.to_sym

        key_table = definition.reflection_by_name(klass, key).table_name
        value_table = klass.table_name.to_s

        value_table_fk_key, key_table_pk = reflection_keys(definition.reflection_by_name(klass, key))

        main_reflection = definition.reflection_by_name(definition.klass, relation)
        if main_reflection
          main_table = definition.klass.table_name
          main_table_pk, value_table_fk_main = reflection_keys(definition.reflection_by_name(definition.klass, relation))

          join_sql = "\n  INNER JOIN #{connection.quote_table_name(value_table)} #{value_table}_#{num} ON (#{main_table}.#{main_table_pk} = #{value_table}_#{num}.#{value_table_fk_main})"
          value_table = " #{value_table}_#{num}"
        end
        join_sql += "\n INNER JOIN #{connection.quote_table_name(key_table)} #{key_table}_#{num} ON (#{key_table}_#{num}.#{key_table_pk} = #{value_table}.#{value_table_fk_key}) "

        return join_sql
      end

      # This method construct join statement for a key value table
      # It assume the following table structure
      #  +----------+  +---------+
      #  | main     |  | key     |
      #  | main_pk  |  | value   |
      #  |          |  | main_fk |
      #  +----------+  +---------+
      # uniq name for the joins are needed in case that there is more than one condition
      # on different keys in the same query.
      def construct_simple_join_sql(num)
        connection = klass.connection
        key_value_table = klass.table_name

        main_table = definition.klass.table_name
        main_table_pk, value_table_fk_main = reflection_keys(definition.reflection_by_name(definition.klass, relation))

        join_sql = "\n  INNER JOIN #{connection.quote_table_name(key_value_table)} #{key_value_table}_#{num} ON (#{connection.quote_table_name(main_table)}.#{connection.quote_column_name(main_table_pk)} = #{key_value_table}_#{num}.#{connection.quote_column_name(value_table_fk_main)})"
        return join_sql
      end

      def reflection_keys(reflection)
        pk = reflection.klass.primary_key
        fk = reflection.options[:foreign_key]
        # activerecord prior to 3.1 doesn't respond to foreign_key method and hold the key name in the reflection primary key
        fk ||= reflection.respond_to?(:foreign_key) ? reflection.foreign_key : reflection.primary_key_name
        reflection.macro == :belongs_to ? [fk, pk] : [pk, fk]
      end

      def reflection_conditions(reflection)
        return unless reflection
        conditions = reflection.options[:conditions]
        conditions ||= "#{reflection.options[:source]}_type = '#{reflection.options[:source_type]}'" if reflection.options[:source] && reflection.options[:source_type]
        conditions ||= "#{reflection.try(:foreign_type)} = '#{reflection.klass}'" if  reflection.options[:polymorphic]
        " AND #{conditions}" if conditions
      end

      def to_ext_method_sql(key, operator, value, &block)
        raise ScopedSearch::QueryNotSupported, "'#{definition.klass}' doesn't respond to '#{ext_method}'" unless definition.klass.respond_to?(ext_method)
        conditions = definition.klass.send(ext_method.to_sym,key, operator, value) rescue {}
        raise ScopedSearch::QueryNotSupported, "external method '#{ext_method}' should return hash" unless conditions.kind_of?(Hash)
        sql = ''
        conditions.map do |notification, content|
          case notification
            when :include then yield(:include, content)
            when :joins then yield(:joins, content)
            when :conditions then sql = content
            when :parameter then content.map{|c| yield(:parameter, c)}
          end
        end
        return sql
      end
    end

    # This module contains modules for every AST::Node class to add SQL generation.
    module AST

      # Defines the to_sql method for AST LeadNodes
      module LeafNode
        def to_sql(builder, definition, &block)
          # for boolean fields allow a short format (example: for 'enabled = true' also allow 'enabled')
          field = definition.field_by_name(value)
          if field && field.set? && field.complete_value.values.include?(true)
            key = field.complete_value.map{|k,v| k if v == true}.compact.first
            return builder.set_test(field, :eq, key, &block)
          end
          # Search keywords found without context, just search on all the default fields
          fragments = definition.default_fields_for(value).map do |field|
            builder.sql_test(field, field.default_operator, value,'', &block)
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

        # Returns an IS (NOT) NULL SQL fragment
        def to_null_sql(builder, definition, &block)
          field = definition.field_by_name(rhs.value)
          raise ScopedSearch::QueryNotSupported, "Field '#{rhs.value}' not recognized for searching!" unless field

          if field.key_field
            yield(:parameter, rhs.value.to_s.sub(/^.*\./,''))
          end
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
                          builder.sql_test(field, operator, rhs.value,'', &block) }.compact

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
          field = definition.field_by_name(lhs.value)
          raise ScopedSearch::QueryNotSupported, "Field '#{lhs.value}' not recognized for searching!" unless field
          builder.sql_test(field, operator, rhs.value,lhs.value, &block)
        end

        # Convert this AST node to an SQL fragment.
        def to_sql(builder, definition, &block)
          if operator == :not && children.length == 1
            builder.to_not_sql(rhs, definition, &block)
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
          fragments = children.map { |c| c.to_sql(builder, definition, &block) }.map { |sql| "(#{sql})" unless sql.blank? }.compact
          fragments.empty? ? nil : "#{fragments.join(" #{operator.to_s.upcase} ")}"
        end
      end
    end

    # The PostgreSQLAdapter make sure that searches are case sensitive when
    # using the like/unlike operators, by using the PostrgeSQL-specific
    # <tt>ILIKE operator</tt> instead of <tt>LIKE</tt>.
    class PostgreSQLAdapter < ScopedSearch::QueryBuilder

      # Switches out the default query generation of the <tt>sql_test</tt>
      # method if full text searching is enabled and a text search is being
      # performed.
      def sql_test(field, operator, value, lhs, &block)
        if [:like, :unlike].include?(operator) && field.full_text_search
          yield(:parameter, value)
          negation = (operator == :unlike) ? "NOT " : ""
          locale = (field.full_text_search == true) ? 'english' : field.full_text_search
          return "#{negation}to_tsvector('#{locale}', #{field.to_sql(operator, &block)}) #{self.sql_operator(operator, field)} to_tsquery('#{locale}', ?)"
        else
          super
        end
      end

      # Switches out the default LIKE operator in the default <tt>sql_operator</tt>
      # method for ILIKE or @@ if full text searching is enabled.
      def sql_operator(operator, field)
        raise ScopedSearch::QueryNotSupported, "the operator '#{operator}' is not supported for field type '#{field.type}'" if [:like, :unlike].include?(operator) and !field.textual?
        return '@@' if [:like, :unlike].include?(operator) && field.full_text_search
        case operator
          when :like   then 'ILIKE'
          when :unlike then 'NOT ILIKE'
          else super(operator, field)
        end
      end

      # Returns a NOT (...)  SQL fragment that negates the current AST node's children
      def to_not_sql(rhs, definition, &block)
        "NOT COALESCE(#{rhs.to_sql(self, definition, &block)}, false)"
      end

      def order_by(order, &block)
        sql = super(order, &block)
        sql += sql.include?('DESC') ? ' NULLS LAST ' : ' NULLS FIRST ' if sql
        sql
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
