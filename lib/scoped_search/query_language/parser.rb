# The Parser module adss methods to the query language compiler that transform a string
# into an abstract syntax tree, which can be used for query generation.
#
# This module depends on the tokeinzer module to transform the string into a stream
# of tokens, which is more appropriate for parsing. The parser itself is a LL(1)
# recursive descent parser.
module ScopedSearch::QueryLanguage::Parser

  DEFAULT_SEQUENCE_OPERATOR = :and

  LOGICAL_INFIX_OPERATORS  = [:and, :or]
  LOGICAL_PREFIX_OPERATORS = [:not]
  NULL_PREFIX_OPERATORS    = [:null, :notnull]
  COMPARISON_OPERATORS = [:eq, :ne, :gt, :gte, :lt, :lte, :like, :unlike, :in, :notin]
  ALL_INFIX_OPERATORS = LOGICAL_INFIX_OPERATORS + COMPARISON_OPERATORS
  ALL_PREFIX_OPERATORS = LOGICAL_PREFIX_OPERATORS + COMPARISON_OPERATORS + NULL_PREFIX_OPERATORS

  # Start the parsing process by parsing an expression sequence
  def parse
    @tokens = tokenize
    while @tokens.last.is_a?(Symbol) do
      @tokens.delete_at(@tokens.size - 1)
    end
    parse_expression_sequence(true).simplify
  end

  # Parses a sequence of expressions
  def parse_expression_sequence(root_node = false)
    expressions = []

    next_token if !root_node && peek_token == :lparen # skip starting :lparen
    expressions << parse_logical_expression until peek_token.nil? || peek_token == :rparen
    next_token if !root_node && peek_token == :rparen # skip final :rparen

    return ScopedSearch::QueryLanguage::AST::LogicalOperatorNode.new(DEFAULT_SEQUENCE_OPERATOR, expressions, root_node)
  end

  # Parses a logical expression.
  def parse_logical_expression
    lhs = case peek_token
      when nil;             nil
      when :lparen;         parse_expression_sequence
      when :not;            parse_logical_not_expression
      when :null, :notnull; parse_null_expression
      when *LOGICAL_INFIX_OPERATORS; parse_logical_infix_expression
      else;                 parse_comparison
    end

    if LOGICAL_INFIX_OPERATORS.include?(peek_token)
      parse_logical_infix_expression([lhs])
    else
      lhs
    end
  end

  def parse_logical_infix_expression(previous = [])
    operator = next_token
    rhs = parse_logical_expression
    ScopedSearch::QueryLanguage::AST::LogicalOperatorNode.new(operator, previous + [rhs])
  end

  # Parses a NOT expression
  def parse_logical_not_expression
    next_token # = skip NOT operator
    negated_expression = case peek_token
      when :not;    parse_logical_not_expression
      when :lparen; parse_expression_sequence
      else          parse_comparison
    end

    raise ScopedSearch::QueryNotSupported, "No operands found" if negated_expression.empty?
    return ScopedSearch::QueryLanguage::AST::OperatorNode.new(:not, [negated_expression])
  end

  # Parses a set? or null? expression
  def parse_null_expression
    return ScopedSearch::QueryLanguage::AST::OperatorNode.new(next_token, [parse_value])
  end

  # Parses a comparison
  def parse_comparison
    next_token if peek_token == :comma # skip comma
    return (String === peek_token) ? parse_infix_comparison : parse_prefix_comparison
  end

  # Parses a prefix comparison, i.e. without an explicit field: <operator> <value>
  def parse_prefix_comparison
    token = next_token
    case token
    when :in
      parse_prefix_in(true)
    when :notin
      parse_prefix_in(false)
    else
      ScopedSearch::QueryLanguage::AST::OperatorNode.new(token, [parse_value])
    end
  end

  def parse_prefix_in(inclusion)
    cmp, log = inclusion ? [:eq, :or] : [:ne, :and]
    leaves = parse_multiple_values.map do |x|
      leaf = ScopedSearch::QueryLanguage::AST::LeafNode.new(x)
      ScopedSearch::QueryLanguage::AST::OperatorNode.new(cmp, [leaf])
    end
    ScopedSearch::QueryLanguage::AST::LogicalOperatorNode.new(log, leaves)
  end

  # Parses an infix expression, i.e. <field> <operator> <value>
  def parse_infix_comparison
    lhs = parse_value
    return case peek_token
      when nil
        lhs
      when :comma
        next_token # skip comma
        lhs
      else
        if COMPARISON_OPERATORS.include?(peek_token)
          comparison_operator = next_token
          rhs = parse_value
          ScopedSearch::QueryLanguage::AST::OperatorNode.new(comparison_operator, [lhs, rhs])
        else
          lhs
        end
    end
  end

  # Parse values in the format (val, val, val)
  def parse_multiple_values
    next_token if  peek_token == :lparen #skip :lparen
    value = []
    value << current_token if String === next_token until peek_token.nil? || peek_token == :rparen
    next_token if peek_token == :rparen  # consume the :rparen
    value
  end

  # This can either be a constant value or a field name.
  def parse_value
    if String === peek_token
      ScopedSearch::QueryLanguage::AST::LeafNode.new(next_token)
    elsif ([:in, :notin].include? current_token)
      value = parse_multiple_values().join(',')
      ScopedSearch::QueryLanguage::AST::LeafNode.new(value)
    else
      raise ScopedSearch::QueryNotSupported, "Value expected but found #{peek_token.inspect}"
    end
  end

  protected

  def current_token # :nodoc:
    @current_token
  end

  def peek_token(amount = 1) # :nodoc:
    @tokens[amount - 1]
  end

  def next_token # :nodoc:
    @current_token = @tokens.shift
  end

end
