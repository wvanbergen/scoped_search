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
      case definition.klass.connection.class.name.split('::').last
      when /postgresql/i
        PostgreSQLAdapter
      else
        self
      end
    end

    # Initializes the instance by setting the relevant parameters
    def initialize(definition, ast, profile)
      @definition = definition
      @ast = ast
      @definition.profile = profile
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

    def find_field_for_order_by(order, &block)
      order ||= definition.default_order
      return [nil, nil] if order.blank?
      field_name, direction_name = order.to_s.split(/\s+/, 2)
      field = definition.field_by_name(field_name)
      raise ScopedSearch::QueryNotSupported, "the field '#{field_name}' in the order statement is not valid field for search" unless field
      return field, direction_name
    end

    def order_by(order, &block)
      field, direction_name = find_field_for_order_by(order, &block)
      return nil if field.nil?
      sql = field.to_sql(&block)
      direction = (!direction_name.nil? && direction_name.downcase.eql?('desc')) ? " DESC" : " ASC"
      return sql + direction
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
      raise ScopedSearch::QueryNotSupported, "the operator '#{operator}' is not supported for field type '#{field.type}'" if !field.virtual? and [:like, :unlike].include?(operator) and !field.textual?
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
      return [] unless timestamp

      timestamp = timestamp.to_date if field.date?
      # Check for the case that a date-only value is given as search keyword,
      # but the field is of datetime type. Change the comparison to return
      # more logical results.
      if field.datetime?
        span = 1.minute if(value =~ /\A\s*\d+\s+\bminutes?\b\s+\bago\b\s*\z/i)
        span ||= (timestamp.day_fraction == 0) ? 1.day : 1.hour
        if [:eq, :ne].include?(operator)
          # Instead of looking for an exact (non-)match, look for dates that
          # fall inside/outside the range of timestamps of that day.
          negate    = (operator == :ne) ? 'NOT ' : ''
          field_sql = field.to_sql(operator, &block)
          return ["#{negate}(#{field_sql} >= ? AND #{field_sql} < ?)", timestamp, timestamp + span]

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

      # return the SQL test
      ["#{field.to_sql(operator, &block)} #{sql_operator(operator, field)} ?", timestamp]
    end

    # Validate the key name is in the set and translate the value to the set value.
    def translate_value(field, value)
      translated_value = field.complete_value[value.to_sym]
      raise ScopedSearch::QueryNotSupported, "'#{field.field}' should be one of '#{field.complete_value.keys.join(', ')}', but the query was '#{value}'" if translated_value.nil?
      translated_value
    end

    def map_value(field, value)
      old_value = value
      translator = field.value_translation
      value = translator.call(value) if translator
      raise ScopedSearch::QueryNotSupported, "Translation from any value to nil is not allowed, translated '#{old_value}'" if value.nil?
      value
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
      ["#{negate}(#{field.to_sql(operator, &block)} #{self.sql_operator(operator, field)} ?)", set_value]
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
      return field.to_ext_method_sql(lhs, sql_operator(operator, field), value, &block) if field.virtual?

      yield(:keyparameter, lhs.sub(/^.*\./,'')) if field.key_field

      condition, *values = if field.temporal?
                             datetime_test(field, operator, value, &block)
                           elsif field.set?
                             set_test(field, operator, value, &block)
                           else
                             ["#{field.to_sql(operator, &block)} #{self.sql_operator(operator, field)} #{value_placeholders(operator, value)}", value]
                           end
      values.each { |value| preprocess_parameters(field, operator, value, &block) }

      if field.relation && definition.reflection_by_name(field.definition.klass, field.relation).macro == :has_many
        connection = field.definition.klass.connection
        reflection = definition.reflection_by_name(field.definition.klass, field.relation)
        primary_key_col = reflection.options[:primary_key] || field.definition.klass.primary_key
        primary_key = "#{connection.quote_table_name(field.definition.klass.table_name)}.#{connection.quote_column_name(primary_key_col)}"
        key, join_table = if reflection.options.has_key?(:through)
                            [primary_key, has_many_through_join(field)]
                          else
                            [connection.quote_column_name(field.reflection_keys(reflection)[1]),
                             connection.quote_table_name(field.klass.table_name)]
                          end

        condition = "#{primary_key} IN (SELECT #{key} FROM #{join_table} WHERE #{condition} )"
      end
      condition
    end

    def preprocess_parameters(field, operator, value, &block)
      values = if [:in, :notin].include?(operator)
                 value.split(',').map { |v| map_value(field, field.set? ? translate_value(field, v) : v.strip) }
               elsif [:like, :unlike].include?(operator)
                 [(value !~ /^\%|\*/ && value !~ /\%|\*$/) ? "%#{value}%" : value.tr_s('%*', '%')]
               else
                 [map_value(field, field.offset ? value.to_i : value)]
               end
      values.each { |value| yield(:parameter, value) }
    end

    def value_placeholders(operator, value)
      return '?' unless [:in, :notin].include?(operator)

      '(' + value.split(',').map { '?' }.join(',') + ')'
    end

    def find_has_many_through_association(field, through)
      middle_table_association = nil
      field.klass.reflect_on_all_associations(:has_many).each do |reflection|
        class_name = reflection.options[:class_name].constantize.table_name if reflection.options[:class_name]
        middle_table_association = reflection.name if class_name == through.to_s
        middle_table_association = reflection.plural_name if reflection.plural_name == through.to_s
      end
      middle_table_association
    end

    # Walk the chain of has-many-throughs, collecting all tables we will need to join
    def nested_has_many(many_class, relation)
      acc = [relation]
      while (reflection = definition.reflection_by_name(many_class, relation))
        break if reflection.nil? || reflection.options[:through].nil?
        relation = reflection.options[:through]
        acc.unshift(relation)
      end
      acc.map { |relation| definition.reflection_by_name(many_class, relation) }
    end

    def has_many_through_join(field)
      many_class = field.definition.klass
      connection = many_class.connection
      sql = connection.quote_table_name(many_class.table_name)
      join_reflections = nested_has_many(many_class, field.relation)
      table_names = [[many_class.table_name, many_class.sti_name.tableize]] + join_reflections.map(&:table_name)

      join_reflections.zip(table_names.zip(join_reflections.drop(1))).reduce(sql) do |acc, (reflection, (previous_table, next_reflection))|
        fk1, pk1 = if reflection.respond_to?(:join_keys)
                     klass = reflection.method(:join_keys).arity == 1 ? [reflection.klass] : [] # ActiveRecord <5.2 workaround
                     reflection.join_keys(*klass).values # We are joining the tables "in reverse", so the PK and FK are swapped
                   else
                     [reflection.join_primary_key, reflection.join_foreign_key] #ActiveRecord 6.1
                   end

        previous_table, sti_name = previous_table
        # primary and foreign keys + optional conditions for the joins
        join_condition = if with_polymorphism?(reflection)
                           field.reflection_conditions(definition.reflection_by_name(next_reflection.klass, sti_name || previous_table))
                         else
                           ''
                         end

        acc + <<-SQL
          INNER JOIN #{connection.quote_table_name(reflection.table_name)}
          ON #{connection.quote_table_name(previous_table)}.#{connection.quote_column_name(pk1)} = #{connection.quote_table_name(reflection.table_name)}.#{connection.quote_column_name(fk1)} #{join_condition}
        SQL
      end
    end

    def with_polymorphism?(reflection)
      as = reflection.options[:as]
      return unless as
      definition.reflection_by_name(reflection.klass, as).options[:polymorphic]
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
        begin
          conditions = definition.klass.send(ext_method.to_sym, key, operator, value)
        rescue StandardError => e
          raise ScopedSearch::QueryNotSupported, "external method '#{ext_method}' failed with error: #{e}"
        end
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
            sql, *params = builder.set_test(field, :eq, key, &block)
            params.each { |p| yield(:parameter, p) }
            return sql
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

          # see if the value passes user defined validation
          if [:in, :notin].include?(operator)
            rhs.value.split(',').each { |v| validate_value(field, v) }
          else
            validate_value(field, rhs.value)
          end

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

        private

        def validate_value(field, value)
          validator = field.validator
          if validator
            valid = field.special_values.include?(value) || validator.call(value)
            raise ScopedSearch::QueryNotSupported, "Value '#{value}' is not valid for field '#{field.field}'" unless valid
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
        raise ScopedSearch::QueryNotSupported, "the operator '#{operator}' is not supported for field type '#{field.type}'" if !field.virtual? and [:like, :unlike].include?(operator) and !field.textual?
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
        if sql
          field, _ = find_field_for_order_by(order, &block)
          sql += sql.include?('DESC') ? ' NULLS LAST ' : ' NULLS FIRST ' if !field.nil? && field.column.null
        end
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
