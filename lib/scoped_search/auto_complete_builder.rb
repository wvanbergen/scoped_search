module ScopedSearch

  # The AutoCompleteBuilder class builds suggestions to complete query based on
  # the query language syntax.
  class AutoCompleteBuilder

    LOGICAL_INFIX_OPERATORS  = ScopedSearch::QueryLanguage::Parser::LOGICAL_INFIX_OPERATORS
    LOGICAL_PREFIX_OPERATORS = ScopedSearch::QueryLanguage::Parser::LOGICAL_PREFIX_OPERATORS
    NULL_PREFIX_OPERATORS    = ScopedSearch::QueryLanguage::Parser::NULL_PREFIX_OPERATORS
    NULL_PREFIX_COMPLETER    = ['has']
    COMPARISON_OPERATORS     = ScopedSearch::QueryLanguage::Parser::COMPARISON_OPERATORS
    PREFIX_OPERATORS         = LOGICAL_PREFIX_OPERATORS + NULL_PREFIX_OPERATORS

    attr_reader :ast, :definition, :query, :tokens

    # This method will parse the query string and build  suggestion list using the
    # search query.
    def self.auto_complete(definition, query, options = {})
      return [] if (query.nil? or definition.nil? or !definition.respond_to?(:fields))

      new(definition, query, options).build_autocomplete_options
    end

    # Initializes the instance by setting the relevant parameters
    def initialize(definition, query, options)
      @definition = definition
      @ast        = ScopedSearch::QueryLanguage::Compiler.parse(query)
      @query      = query
      @tokens     = tokenize
      @options    = options
    end

    # Test the validity of the current query and suggest possible completion
    def build_autocomplete_options
      # First parse to find illegal syntax in the existing query,
      # this method will throw exception on bad syntax.
      is_query_valid

      # get the completion options
      node = last_node
      completion = complete_options(node)

      suggestions = []
      suggestions += complete_keyword        if completion.include?(:keyword)
      suggestions += LOGICAL_INFIX_OPERATORS if completion.include?(:logical_op)
      suggestions += LOGICAL_PREFIX_OPERATORS + NULL_PREFIX_COMPLETER if completion.include?(:prefix_op)
      suggestions += complete_operator(node) if completion.include?(:infix_op)
      suggestions += complete_value          if completion.include?(:value)

      build_suggestions(suggestions, completion.include?(:value))
    end

    # parse the query and return the complete options
    def complete_options(node)

      return [:keyword] + [:prefix_op] if tokens.empty?

      #prefix operator
      return [:keyword] if last_token_is(PREFIX_OPERATORS)

      # left hand
      if is_left_hand(node)
        if (tokens.size == 1 || last_token_is(PREFIX_OPERATORS + LOGICAL_INFIX_OPERATORS) ||
            last_token_is(PREFIX_OPERATORS + LOGICAL_INFIX_OPERATORS, 2))
          options = [:keyword]
          options += [:prefix_op]  unless last_token_is(PREFIX_OPERATORS)
        else
          options = [:logical_op]
        end
        return options
      end

      if is_right_hand
        # right hand
        return [:value]
      else
        # comparison operator completer
        return [:infix_op]
      end
    end

    # Test the validity of the existing query, this method will throw exception on illegal
    # query syntax.
    def is_query_valid
      # skip test for null prefix operators if in the process of completing the field name.
      return if(last_token_is(NULL_PREFIX_OPERATORS, 2) && !(query =~ /(\s|\)|,)$/))
      QueryBuilder.build_query(definition, query)
    end

    def is_left_hand(node)
      field = definition.field_by_name(node.value) if node.respond_to?(:value)
      lh = field.nil? || field.key_field && !(query.end_with?(' '))
      lh = lh || last_token_is(NULL_PREFIX_OPERATORS, 2)
      lh = lh && !is_right_hand
      lh
    end

    def is_right_hand
      rh = last_token_is(COMPARISON_OPERATORS)
      if(tokens.size > 1 && !(query.end_with?(' ')))
        rh = rh || last_token_is(COMPARISON_OPERATORS, 2)
      end
      rh
    end

    def last_node
      last = ast
      while (last.kind_of?(ScopedSearch::QueryLanguage::AST::OperatorNode) && !(last.children.empty?)) do
        last = last.children.last
      end
      last
    end

    def last_token_is(list,index = 1)
      if tokens.size >= index
        return list.include?(tokens[tokens.size - index])
      end
      return false
    end

    def tokenize
      tokens = ScopedSearch::QueryLanguage::Compiler.tokenize(query)
      # skip parenthesis, it is not needed for the auto completer.
      tokens.delete_if {|t| t == :lparen || t == :rparen }
      tokens
    end

    def build_suggestions(suggestions, is_value)
      return [] if (suggestions.blank?)

      q = query
      unless q =~ /(\s|\)|,)$/ || last_token_is(COMPARISON_OPERATORS)
        val = Regexp.escape(tokens.last.to_s).gsub('\*', '.*')
        suggestions = suggestions.map {|s| s if s.to_s =~ /^"?#{val}"?/i}.compact
        quoted = /("?#{Regexp.escape(tokens.last.to_s)}"?)$/.match(q)
        q.chomp!(quoted[1]) if quoted
      end

      # for dotted field names compact the suggestions list to be one suggestion
      # unless the user has typed the relation name entirely or the suggestion list
      # is short.
      last_token = tokens.last.to_s
      if (suggestions.size > 10 && (tokens.empty? || !last_token.include?('.')) && !is_value)
        suggestions = suggestions.map  do |s|
          !last_token.empty? && s.to_s.split('.')[0].end_with?(last_token) ? s.to_s : s.to_s.split('.')[0]
        end
      end

      suggestions.uniq.map {|m| "#{q} #{m}"}
    end

    # suggest all searchable field names.
    # in relations suggest only the long format relation.field.
    def complete_keyword
      keywords = []
      definition.fields.each do|f|
        next unless f[1].complete_enabled
        if (f[1].key_field)
          keywords += complete_key(f[0], f[1], tokens.last)
        else
          keywords << f[0].to_s + ' '
        end
      end
      keywords.sort
    end

    #this method completes the keys list in a key-value schema in the format table.keyName
    def complete_key(name, field, val)
      return ["#{name}."] if !val || !val.is_a?(String) || !(val.include?('.'))
      val = val.sub(/.*\./,'')

      connection    = definition.klass.connection
      quoted_table  = field.key_klass.connection.quote_table_name(field.key_klass.table_name)
      quoted_field  = field.key_klass.connection.quote_column_name(field.key_field)
      field_name    = "#{quoted_table}.#{quoted_field}"

      field.key_klass
        .where(value_conditions(field_name, val))
        .select(field_name)
        .limit(20)
        .distinct
        .map(&field.key_field)
        .compact
        .map { |f| "#{name}.#{f} " }
    end

    # this method auto-completes values of fields that have a :complete_value marker
    def complete_value
      if last_token_is(COMPARISON_OPERATORS)
        token = tokens[tokens.size - 2]
        val = ''
      else
        token = tokens[tokens.size - 3]
        val = tokens[tokens.size - 1]
      end

      field = definition.field_by_name(token)
      return [] unless field && field.complete_value

      return complete_set(field) if field.set?
      return complete_date_value if field.temporal?
      return complete_key_value(field, token, val) if field.key_field

      special_values = field.special_values.select { |v| v =~ /\A#{val}/ }
      special_values + complete_value_from_db(field, special_values, val)
    end

    def complete_value_from_db(field, special_values, val)
      count = 20 - special_values.count
      completer_scope(field)
        .where(@options[:value_filter])
        .where(value_conditions(field.quoted_field, val))
        .select(field.quoted_field)
        .limit(count)
        .distinct
        .map(&field.field)
        .compact
        .map { |v| v.is_a?(String) ? "\"#{v.gsub('"', '\"')}\"" : v }
    end

    def completer_scope(field)
      klass = field.klass
      scope = klass.respond_to?(:completer_scope) ? klass.completer_scope(@options) : klass
      scope.respond_to?(:reorder) ? scope.reorder(Arel.sql(field.quoted_field)) : scope.scoped(:order => field.quoted_field)
    end

    # set value completer
    def complete_set(field)
      field.complete_value.keys
    end
    # date value completer
    def complete_date_value
      options = []
      options << '"30 minutes ago"'
      options << '"1 hour ago"'
      options << '"2 hours ago"'
      options << 'Today'
      options << 'Yesterday'
      options << 'Tomorrow'
      options << 2.days.ago.strftime('%A')
      options << 3.days.ago.strftime('%A')
      options << 4.days.ago.strftime('%A')
      options << 5.days.ago.strftime('%A')
      options << '"6 days ago"'
      options << 7.days.ago.strftime('"%b %d,%Y"')
      options << '"2 weeks from now"'
      options
    end

    # complete values in a key-value schema
    def complete_key_value(field, token, val)
      key_name = token.sub(/^.*\./,"")
      key_klass = field.key_klass.where(field.key_field => key_name).first
      raise ScopedSearch::QueryNotSupported, "Field '#{key_name}' not recognized for searching!" if key_klass.nil?

      query = completer_scope(field)

      if field.key_klass != field.klass
        key   = field.key_klass.to_s.gsub(/.*::/,'').underscore.to_sym
        fk    = definition.reflection_by_name(field.klass, key).association_foreign_key.to_sym
        query = query.where(fk => key_klass.id)
      end

      query
        .where(value_conditions(field.quoted_field, val))
        .select("DISTINCT #{field.quoted_field}")
        .limit(20)
        .map(&field.field)
        .compact
        .map { |v| v.to_s =~ /\s/ ? "\"#{v}\"" : v }
    end

    # This method returns conditions for selecting completion from partial value
    def value_conditions(field_name, val)
      val.blank? ? nil : "CAST(#{field_name} as CHAR(50)) LIKE '#{val.gsub("'","''")}%'".tr_s('%*', '%')
    end

    # This method complete infix operators by field type
    def complete_operator(node)
      definition.operator_by_field_name(node.value).map { |o| o.end_with?(' ') ? o : "#{o} " }
    end
  end
end
