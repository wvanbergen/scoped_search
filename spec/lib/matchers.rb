RSpec::Matchers.define :be_infix_operator do |operator|
  match { |node| node.kind_of?(ScopedSearch::QueryLanguage::AST::OperatorNode) && node.infix? && (operator.nil? || operator == node.operator) }
end

RSpec::Matchers.define :be_prefix_operator do |operator|
  match { |node| node.kind_of?(ScopedSearch::QueryLanguage::AST::OperatorNode) && node.prefix? && (operator.nil? || operator == node.operator) }
end

RSpec::Matchers.define :be_logical_operator do |operator|
  match { |node| node.kind_of?(ScopedSearch::QueryLanguage::AST::LogicalOperatorNode) && (operator.nil? || operator == node.operator) }
end

RSpec::Matchers.define :be_leaf_node do |value|
  match { |node| node.kind_of?(ScopedSearch::QueryLanguage::AST::LeafNode) && (value.nil? || value == node.value) }
end

RSpec::Matchers.define :tokenize_to do |*tokens|
  match { |str| tokens == ScopedSearch::QueryLanguage::Compiler.tokenize(str) }
end

RSpec::Matchers.define :parse_to do |tree|
  match { |str| tree == ScopedSearch::QueryLanguage::Compiler.parse(str).to_a }
end

RSpec::Matchers.define :contain do |*expected|
  match_for_should do |actual|
    expected.all? { |e| actual.include?(e) }
  end

  match_for_should_not do |actual|
    expected.none? { |e| actual.include?(e) }
  end
end
