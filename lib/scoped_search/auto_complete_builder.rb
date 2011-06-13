module ScopedSearch


  LOGICAL_INFIX_OPERATORS  = ScopedSearch::QueryLanguage::Parser::LOGICAL_INFIX_OPERATORS
  LOGICAL_PREFIX_OPERATORS = ScopedSearch::QueryLanguage::Parser::LOGICAL_PREFIX_OPERATORS
  NULL_PREFIX_OPERATORS    = ScopedSearch::QueryLanguage::Parser::NULL_PREFIX_OPERATORS
  NULL_PREFIX_COMPLETER    = ['has']
  COMPARISON_OPERATORS     = ScopedSearch::QueryLanguage::Parser::COMPARISON_OPERATORS
  PREFIX_OPERATORS         = LOGICAL_PREFIX_OPERATORS + NULL_PREFIX_OPERATORS

  # The AutoCompleteBuilder class builds suggestions to complete query based on
  # the query language syntax.
  class AutoCompleteBuilder

    attr_reader :ast, :definition, :query, :tokens

    # This method will parse the query string and build  suggestion list using the
    # search query.
    def self.auto_complete(definition, query)
      return [] if (query.nil? or definition.nil? or !definition.respond_to?(:fields))

      new(definition, query).build_autocomplete_options
    end

    # Initializes the instance by setting the relevant parameters
    def initialize(definition, query)
      @definition = definition
      @ast        = ScopedSearch::QueryLanguage::Compiler.parse(query)
      @query      = query
      @tokens     = tokenize
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
      field = definition.field_by_name(node.value)
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

      q=query
      unless q =~ /(\s|\)|,)$/
        val = Regexp.escape(tokens.last.to_s).gsub('\*', '.*')
        suggestions = suggestions.map {|s| s if s.to_s =~ /^#{val}/i}.compact
        q.chomp!(tokens.last.to_s)
      end

      # for doted field names compact the suggestions list to be one suggestion
      # unless the user has typed the relation name entirely or the suggestion list
      # is short.
      if (suggestions.size > 10 && (tokens.empty? || !(tokens.last.to_s.include?('.')) ) && !(is_value))
        suggestions = suggestions.map {|s|
          (s.to_s.split('.')[0].end_with?(tokens.last)) ? s.to_s : s.to_s.split('.')[0]
        }
      end

      suggestions.uniq.map {|m| "#{q} #{m}".gsub(/\s+/," ")}
    end

    # suggest all searchable field names.
    # in relations suggest only the long format relation.field.
    def complete_keyword
      keywords = []
      definition.fields.each do|f|
        if (f[1].key_field)
          keywords += complete_key(f[0], f[1], tokens.last)
        else
          keywords << f[0].to_s+' '
        end
      end
      keywords.sort
    end

    #this method completes the keys list in a key-value schema in the format table.keyName
    def complete_key(name, field, val)
      return ["#{name}."] if !val || !val.is_a?(String) || !(val.include?('.'))
      val = val.sub(/.*\./,'')

      field_name = field.key_field
      opts =  value_conditions(field.key_field, val).merge(:limit => 20, :select => field_name, :group => field_name )

      field.key_klass.all(opts).map(&field_name).compact.map{ |f| "#{name}.#{f} "}
    end

    # this method auto-completes values of fields that have a :complete_value marker 
    def complete_value
      if last_token_is(COMPARISON_OPERATORS)
        token = tokens[tokens.size-2]
        val = ''
      else
        token = tokens[tokens.size-3]
        val = tokens[tokens.size-1]
      end

      field = definition.field_by_name(token)
      return [] unless field && field.complete_value

      return complete_set(field) if field.set?
      return complete_date_value if field.temporal?
      return complete_key_value(field, token, val) if field.key_field

      opts = value_conditions(field.field, val)
      opts.merge!(:limit => 20, :select => "DISTINCT #{field.field}")
      return field.klass.all(opts).map(&field.field).compact.map{|v| v.to_s =~ /\s+/ ? "\"#{v}\"" : v}
    end

    # set value completer
    def complete_set(field)
      field.complete_value.keys
    end
    # date value completer
    def complete_date_value
      options =[]
      options << '"30 minutes ago"'
      options << '"1 hour ago"'
      options << '"2 hours ago"'
      options << 'Today'
      options << 'Yesterday'
      options << 2.days.ago.strftime('%A')
      options << 3.days.ago.strftime('%A')
      options << 4.days.ago.strftime('%A')
      options << 5.days.ago.strftime('%A')
      options << '"6 days ago"'
      options << 7.days.ago.strftime('"%b %d,%Y"')
      options
    end

    # complete values in a key-value schema
    def complete_key_value(field, token, val)
      key_name = token.sub(/^.*\./,"")
      key_opts = value_conditions(field.field,val).merge(:conditions => {field.key_field => key_name})
      key_klass = field.key_klass.first(key_opts)
      raise ScopedSearch::QueryNotSupported, "Field '#{key_name}' not recognized for searching!" if key_klass.nil?

      opts = {:select => "DISTINCT #{field.field}"}
      if(field.key_klass != field.klass)
        key  = field.key_klass.to_s.gsub(/.*::/,'').underscore.to_sym
        fk   = field.klass.reflections[key].association_foreign_key.to_sym
        opts.merge!(:conditions => {fk => key_klass.id})
      else
        opts.merge!(key_opts)
      end
      return field.klass.all(opts.merge(:limit => 20)).map(&field.field).compact.map{|v| v.to_s =~ /\s+/ ? "\"#{v}\"" : v}
    end

    #this method returns conditions for selecting completion from partial value
    def value_conditions(field_name, val)
      return val.blank? ? {} : {:conditions => "#{field_name} LIKE '#{val}%'".tr_s('%*', '%')}
    end

    # This method complete infix operators by field type
    def complete_operator(node)
      definition.operator_by_field_name(node.value)
    end

  end

end

# Load lib files
require 'scoped_search/query_builder'
