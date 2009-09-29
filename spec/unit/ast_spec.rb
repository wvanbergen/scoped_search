require "#{File.dirname(__FILE__)}/../spec_helper"

describe ScopedSearch::QueryLanguage::AST do

  describe '.from_array' do

    context 'parsing a singular value' do
      before(:each) do
        @ast = ScopedSearch::QueryLanguage::AST.from_array('value')
      end

      it "should create a leaf node for a normal value" do
        @ast.should be_leaf_node('value')
      end
    end

    context 'parsing a prefix operator' do
      before(:each) do
        @ast = ScopedSearch::QueryLanguage::AST.from_array([:not, 'a'])
      end

      it "should create a operator node for an array starting with an operator" do
        @ast.should be_prefix_operator(:not)
      end

      it "should create a child node for every subsequent array item" do
        @ast.should have(1).children
      end

      it "should create set the RHS the the first child value" do
        @ast.rhs.should be_leaf_node('a')
      end
    end

    context 'pasring an infix operator' do
      before(:each) do
        @ast = ScopedSearch::QueryLanguage::AST.from_array([:eq, 'a', 'b'])
      end

      it "should create a operator node for an array starting with an operator" do
        @ast.should be_infix_operator(:eq)
      end

      it "should create a child node for every subsequent array item" do
        @ast.should have(2).children
      end

      it "should create set the LHS the the first child value" do
        @ast.lhs.should be_leaf_node('a')
      end

      it "should create set the RHS the the second child value" do
        @ast.rhs.should be_leaf_node('b')
      end
    end

    context 'parsing a nested logical construct' do
      before(:each) do
        @ast = ScopedSearch::QueryLanguage::AST.from_array([:and, 'a', [:or, 'b', [:not, 'c']]])
      end

      it "should create a logical operator node for an array starting with :and" do
        @ast.should be_logical_operator(:and)
      end

      it "should create a child node for every subsequent array item" do
        @ast.should have(2).children
      end

      it "should create a nested OR structure for a nested array" do
        @ast.lhs.should be_leaf_node('a')
      end

      it "should create a nested OR structure for a nested array" do
        @ast.rhs.should be_logical_operator(:or)
      end

      it "should create a leaf node in the nested OR structure" do
        @ast.rhs.lhs.should be_leaf_node('b')
      end

      it "should create a NOT operator in the nested OR structure" do
        @ast.rhs.rhs.should be_prefix_operator(:not)
      end

      it "should create a leaf node in the nested OR structure" do
        @ast.rhs.rhs.rhs.should be_leaf_node('c')
      end
    end
  end

  # Recursive tree simplification algorithm
  describe '#simplify' do

    it "should not simplify a leaf node" do
      tree('value').simplify.should eql(tree('value'))
    end

    it "should not simplify a prefix operator node node" do
      tree([:lt, '1']).simplify.should eql(tree([:lt, '1']))
    end

    it "should not simplify an infix operator node node" do
      tree([:lt, 'field', '1']).simplify.should eql(tree([:lt, 'field', '1']))
    end

    it "should simplify a single value in a logical operator" do
      tree([:and, 'a']).simplify.should eql(tree('a'))
    end

    it "should simplify a single operator in a logical operator" do
      tree([:or, [:gt, '2']]).simplify.should eql(tree([:gt, '2']))
    end

    it "should not simplify a logical operator with multiple values" do
      tree([:and, 'a', 'b']).simplify.should eql(tree([:and, 'a', 'b']))
    end

    it "should simplify nested logial operators" do
      tree([:and, [:and, 'a', 'b'], [:and, 'c']]).simplify.should eql(tree([:and, 'a', 'b', 'c']))
    end

    it "should simplify double nested logial operators" do
      tree([:and, [:and, 'a', [:and, 'b', 'c']]]).simplify.should eql(tree([:and, 'a', 'b', 'c']))
    end

    it "should not simplify nested operators if the operators are different" do
      tree([:or, 'a', [:and, 'b', 'c']]).simplify.should eql(tree([:or, 'a', [:and, 'b', 'c']]))
    end
  end
end

describe ScopedSearch::QueryLanguage::AST::OperatorNode do

  context 'with 1 child' do
    before(:each) do
      @node = tree([:not, '1'])
    end

    it 'should be a prefix operator' do
      @node.should be_prefix
    end

    it "should not be an infix operator" do
      @node.should_not be_infix
    end

    it 'should return the first child as RHS' do
      @node.rhs.should eql(@node[0])
    end

    it "should raise an error of the LHS is requested" do
      lambda { @node.lhs }.should raise_error
    end
  end

  context 'with 2 children' do
    before(:each) do
      @node = tree([:eq, '1', '2'])
    end

    it "should be an infix operator" do
      @node.should be_infix
    end

    it "should not be a prefix operator" do
      @node.should_not be_prefix
    end

    it "should return the first child as LHS" do
      @node.lhs.should eql(@node[0])
    end

    it "should return the second child as RHS" do
      @node.rhs.should eql(@node[1])
    end

  end

  context 'many children' do
    before(:each) do
      @node = tree([:and, '1', '2', '3', '4'])
    end

    it "should be an infix operator" do
      @node.should be_infix
    end

    it "should raise an error of the LHS is requested" do
      lambda { @node.lhs }.should raise_error
    end

    it "should raise an error of the RHS is requested" do
      lambda { @node.rhs }.should raise_error
    end
  end
end
