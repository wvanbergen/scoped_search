module ScopedSearch::QueryLanguage::Parser

  DEFAULT_SEQUENCE_OPERATOR = :and
  
  LOGICAL_INFIX_OPERATORS  = [:and, :or]
  LOGICAL_PREFIX_OPERATORS = [:not]
  COMPARISON_OPERATORS = [:eq, :ne, :gt, :gte, :lt, :lte]
  ALL_INFIX_OPERATORS = LOGICAL_INFIX_OPERATORS + COMPARISON_OPERATORS
  ALL_PREFIX_OPERATORS = LOGICAL_PREFIX_OPERATORS + COMPARISON_OPERATORS
  
  def parse
    @tokens = tokenize
    @current_token_pos = -1      
    parse_expression_sequence.simplify
  end

  def current_token
    @current_token
  end
  
  def peek_token(amount = 1)
    @tokens[@current_token_pos + amount]
  end

  def next_token
    @current_token_pos += 1
    @current_token = @tokens[@current_token_pos]
  end


  def parse_expression_sequence
    expressions = []
    expressions << parse_expression until peek_token.nil? || peek_token == :rparen
    next_token if peek_token == :rparen # skip :rparen
    return ScopedSearch::QueryLanguage::AST::LogicalOperatorNode.new(DEFAULT_SEQUENCE_OPERATOR, expressions)
  end

  def parse_infix_operator
    first_operand = @previous_expression
    operator = next_token
    second_operand = parse_expression(LOGICAL_INFIX_OPERATORS.include?(operator))
    if LOGICAL_INFIX_OPERATORS.include?(operator)
      return ScopedSearch::QueryLanguage::AST::LogicalOperatorNode.new(operator, [first_operand, second_operand])
    else
      return ScopedSearch::QueryLanguage::AST::OperatorNode.new(operator, [first_operand, second_operand])
    end
  end

  def parse_prefix_operator
    if LOGICAL_INFIX_OPERATORS.include?(current_token)
      return ScopedSearch::QueryLanguage::AST::LogicalOperatorNode.new(current_token, [parse_expression])
    else
      return ScopedSearch::QueryLanguage::AST::OperatorNode.new(current_token, [parse_expression])
    end
  end

  def parse_expression(expand_rhs = true)
  
    @previous_expression = case next_token
      when nil;       nil
      when :lparen;   parse_expression_sequence
      when String;    ScopedSearch::QueryLanguage::AST::LeafNode.new(current_token)
      else           
        if ALL_PREFIX_OPERATORS.include?(current_token)
          parse_prefix_operator 
        else
          parse_expression # skip current token
        end
    end
    
    if peek_token == :comma
      next_token # skip comma      
    elsif ScopedSearch::QueryLanguage::AST::LeafNode === @previous_expression
      @previous_expression = parse_infix_operator if expand_rhs && ALL_INFIX_OPERATORS.include?(peek_token)
    else
      @previous_expression = parse_infix_operator if expand_rhs && LOGICAL_INFIX_OPERATORS.include?(peek_token)
    end
    
    return @previous_expression
  end
end