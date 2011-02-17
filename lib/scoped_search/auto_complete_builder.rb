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
      suggestions += complete_keyword if completion.include?(:keyword)
      suggestions += LOGICAL_INFIX_OPERATORS if completion.include?(:logical_op)
      suggestions += LOGICAL_PREFIX_OPERATORS + NULL_PREFIX_COMPLETER if completion.include?(:prefix_op)
      suggestions += complete_operator(node) if completion.include?(:infix_op)
      suggestions += complete_value(node)   if completion.include?(:value)

      build_suggestions(suggestions, completion.include?(:value))
    end

    # parse the query and return the complete options
    def complete_options node

      return [:keyword] + [:prefix_op] if tokens.empty?

      #prefix operator
      return [:keyword] if last_token_is(PREFIX_OPERATORS)

      # left hand
      if is_left_hand(node)
        options = [:keyword]
        options += [:logical_op] unless (tokens.size == 1 || last_token_is(PREFIX_OPERATORS + LOGICAL_INFIX_OPERATORS))
        options += [:prefix_op]  unless last_token_is(PREFIX_OPERATORS)
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
      if (last_token_is(NULL_PREFIX_OPERATORS, 2))
        if (definition.fields.keys.map {|s| s if s.to_s=~ /^#{tokens.last}/}.compact.empty? )
          raise ScopedSearch::QueryNotSupported, "Field '#{tokens.last}' not recognized for searching!"
        else
          return
        end
      end
      #todo: revert this when query supports key value
      #QueryBuilder.build_query(definition, query)
    end

    def is_left_hand(node)
      lh = !(definition.fields.keys.include?(node.value.to_sym)) #(field_by_name(node.value))
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

      # for relation fields compact the suggestions list to be one suggestion per relation
      # unless the user has typed the relation name entirely 
      if (tokens.empty? || !(tokens.last.to_s.include?('.') ) && !(is_value))
        suggestions = suggestions.map {|s|
          (s.to_s.split('.')[0].end_with?(tokens.last)) ? s.to_s : s.to_s.split('.')[0]
        }
      end
      q=query
      unless q =~ /(\s|\)|,)$/
        suggestions = suggestions.map {|s| s if s.to_s =~ /^#{tokens.last}/}.compact
        q.chomp!(tokens.last.to_s)
      end
      suggestions.uniq.map {|m| "#{q} #{m}".gsub(/\s+/," ")}
    end

    # suggest all searchable field names.
    # in relations suggest only the long format relation.field.
    def complete_keyword
      keywords = []
      definition.fields.each do|f|
        if (f[1].key_field)
          keywords += complete_key(f[1], tokens.last)
        elsif f[1].relation && !(f[0].to_s.include?('.'))
          next
        else
          keywords << f[0]
        end
      end
      keywords
    end

    #this method completes the keys list in a key-value schema in the format table.keyName
    def complete_key(field, val)
      return [field.relation] if !val || !val.is_a?(String) || !(val.include?('.'))
      val = val.sub(/.*\./,'')

      klass = field.key_klass
      field_name = field.key_field 
      opts = value_conditions(field, val)
      opts.merge!(:limit => 10, :select => field_name, :group => field_name )

      klass.all(opts).map(&field_name).compact.map{ |f| "#{field.relation}.#{f}"}
    end

    # this method auto-completes values of fields that have a :complete_value marker 
    def complete_value(node)
      if last_token_is(COMPARISON_OPERATORS)
        token = tokens[tokens.size-2]
        val = ''
      else
        token = tokens[tokens.size-3]
        val = tokens[tokens.size-1]
      end

      field = definition.field_by_name(token)
      return [] unless field && field.complete_value

      key_name = token.sub(/^.*\./,"")
      opts = value_conditions(field, val)

      if field.key_field
        klass = field.key_klass
        opts.merge!(:conditions => {field.key_field => key_name})
        return klass.first(opts).send(field.relation).map(&field.field).uniq
      else
        klass = field.klass
        opts.merge!(:limit => 10, :select => field.field, :group => field.field )
        return klass.all(opts).map(&field.field).compact
      end
    end

    #this method returns conditions for selecting completion from partial value
    def value_conditions(field, val)
      return {} if val.nil?
      field_name = (field.key_field) ? field.key_field : field.field
      return {:conditions => "#{field_name} LIKE '#{val}%'"} if  field.textual?
      return {:conditions => "#{field_name} >= #{val}"} if field.numerical?
      return {}
    end

    # This method complete infix operators by field type
    def complete_operator(node)
      field = definition.field_by_name(node.value)
      return [] if field.nil?

      return ['=', '>', '<', '<=', '>=','!='] if field.numerical?
      return ['=', '!=', '~', '!~']           if field.textual?
      return ['=', '>', '<']                  if field.temporal?
    end

  end

end

# Load lib files
require 'scoped_search/query_builder'
