module ScopedSearch::Spec::Matchers
  def be_infix_operator(operator = nil)
    simple_matcher('node to be an infix operator') do |node|
      node.kind_of?(ScopedSearch::QueryLanguage::AST::OperatorNode) &&
          node.infix? && (operator.nil? || operator == node.operator)
    end
  end

  def be_prefix_operator(operator = nil)
    simple_matcher('node to be an prefix operator') do |node|
      node.kind_of?(ScopedSearch::QueryLanguage::AST::OperatorNode) &&
          node.prefix? && (operator.nil? || operator == node.operator)
    end
  end

  def be_logical_operator(operator = nil)
    simple_matcher('node to be an logical operator') do |node|
      node.kind_of?(ScopedSearch::QueryLanguage::AST::LogicalOperatorNode) &&
          (operator.nil? || operator == node.operator)
    end
  end

  def be_leaf_node(value = nil)
    simple_matcher('node to be an logical operator') do |node|
      node.kind_of?(ScopedSearch::QueryLanguage::AST::LeafNode) && (value.nil? || value == node.value)
    end
  end

  def tokenize_to(*tokens)
    simple_matcher("to tokenize to #{tokens.inspect}") do |string|
      tokens == ScopedSearch::QueryLanguage::Compiler.tokenize(string)
    end
  end

  def parse_to(tree)
    simple_matcher("to parse to #{tree.inspect}") do |string|
      tree == ScopedSearch::QueryLanguage::Compiler.parse(string).to_a
    end
  end
end
