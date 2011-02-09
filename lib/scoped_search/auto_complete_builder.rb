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
      suggestions += @definition.fields.keys if completion.include?(:keyword)
      suggestions += LOGICAL_INFIX_OPERATORS if completion.include?(:logical_op)
      suggestions += LOGICAL_PREFIX_OPERATORS + NULL_PREFIX_COMPLETER if completion.include?(:prefix_op)
      suggestions += complete_operator(node) if completion.include?(:infix_op)
      suggestions += ["right_hand_side !"]   if completion.include?(:value)

      build_suggestions(suggestions)
    end

    # parse the query and return the complete options
    def complete_options node

      return [:keyword] + [:prefix_op] if tokens.empty?

      #prefix operator
      return [:keyword] if PREFIX_OPERATORS.include?(tokens.last)

      # left hand
      if is_left_hand(node)
        options = [:keyword]
        options += [:logical_op] unless (tokens.size == 1 || (PREFIX_OPERATORS + LOGICAL_INFIX_OPERATORS).include?(tokens.last))
        options += [:prefix_op]  unless PREFIX_OPERATORS.include?(tokens.last)
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
      if ((tokens.size >= 2) and (NULL_PREFIX_OPERATORS.include?(tokens[tokens.size - 2])))
        if (definition.fields.keys.map {|s| s if s.to_s=~ /^#{tokens.last}/}.compact.empty? )
          raise ScopedSearch::QueryNotSupported, "Field '#{tokens.last}' not recognized for searching!"
        else
          return
        end
      end

      QueryBuilder.build_query(definition, query)
    end

    def is_left_hand(node)
      lh = !(definition.fields.keys.include?(node.value.to_sym))

      lh = lh or NULL_PREFIX_OPERATORS.include?(tokens[tokens.size - 2]) if (tokens.size > 1)

      lh = lh && !is_right_hand
      lh
    end

    def is_right_hand
      rh = COMPARISON_OPERATORS.include?(tokens.last)
      if(tokens.size > 1 && !(query.end_with?(' ')))
        rh = rh || COMPARISON_OPERATORS.include?(tokens[tokens.size - 2])
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

    def tokenize
      tokens = ScopedSearch::QueryLanguage::Compiler.tokenize(query)
      # skip parentice, it is not needed for the auto completer.
      tokens.delete_if {|t| t == :lparen || t == :rparen }
      tokens
    end

    def build_suggestions(suggestions)
      token = tokens.last
      return [] if (suggestions.blank?)
      q=query
      unless q =~ /(\s|\)|,)$/
        suggestions = suggestions.map {|s| s if s.to_s =~ /^#{token}/}.compact
        q.chomp!(token)
      end
      suggestions.map {|m| "#{q} #{m}".gsub(/\s+/," ")}
    end

    def complete_operator(node)
      field = definition.fields[node.value.to_sym]
      return [] if field.nil?

      return ['=', '>', '<', '<=', '>=','!='] if field.numerical?
      return ['=', '!=', '~', '!~']           if field.textual?
      return ['=', '>', '<']                  if field.temporal?
    end

  end

end

# Load lib files
require 'scoped_search/query_builder'
