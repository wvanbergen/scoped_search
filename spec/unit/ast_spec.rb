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
end
