module ScopedSearch::QueryLanguage::AST

  # Constructs an AST from an array notation.
  def self.from_array(arg)
    if arg.kind_of?(Array)
      operator = arg.shift
      case operator
      when :and, :or
        LogicalOperatorNode.new(operator, arg.map { |c| from_array(c) })
      when Symbol
        OperatorNode.new(operator, arg.map { |c| from_array(c) })
      else
        raise ScopedSearch::Exception, "Not a valid array representation of an AST!"
      end
    else
      return LeafNode.new(arg)
    end
  end

  # Base AST node class. Instances of this class are used to represent an abstract syntax tree.
  # This syntax tree is created by the ScopedSearch::QueryLanguage parser and visited by the
  # ScopedSearch::QueryBuilder to create SQL query conditions.
  class Node

    def inspect # :nodoc
      "<AST::#{self.class.to_s.split('::').last} #{self.to_a.inspect}>"
    end

    # Tree simplification. By default, do nothing and return the node as is.
    def simplify
      return self
    end

    def compatible_with(node) # :nodoc
      false
    end
  end

  # AST lead node. This node represents leafs in the AST and can represent
  # either a search phrase or a search field name.
  class LeafNode < Node
    attr_reader :value

    def initialize(value) # :nodoc
      @value = value
    end

    # Return an array representation for the node
    def to_a
      value
    end

    def eql?(node) # :nodoc
      node.kind_of?(LeafNode) && node.value == value
    end
  end

  # AST class for representing operators in the query. An operator node has an operator
  # and operands that are represented as AST child nodes. Usually, operator nodes have
  # one or two children.
  # For logical operators, a distinct subclass exists to implement some tree
  # simplification rules.
  class OperatorNode < Node
    attr_reader :operator
    attr_reader :children

    def initialize(operator, children) # :nodoc
      @operator = operator
      @children = children
    end

    # Tree simplicication: returns itself after simpifying its children
    def simplify
      @children = children.map { |c| c.simplify }
      return self
    end

    # Return an array representation for the node
    def to_a
      [@operator] + @children.map { |c| c.to_a }
    end

    def eql?(node) # :nodoc
      node.kind_of?(OperatorNode) && node.operator == operator && node.children.eql?(children)
    end

    # Return the left-hand side (LHS) operand for this operator.
    def lhs
      raise ScopedSearch::Exception, "Operator does not have a LHS" if prefix?
      raise ScopedSearch::Exception, "Operators with more than 2 children do not have LHS/RHS" if children.length > 2
      children[0]
    end

    # Return the right-hand side (RHS) operand for this operator.
    def rhs
      raise ScopedSearch::Exception, "Operators with more than 2 children do not have LHS/RHS" if children.length > 2
      children.length == 1 ? children[0] : children[1]
    end

    # Returns true if this is an infix operator
    def infix?
      children.length > 1
    end

    # Returns true if this is a prefix operator
    def prefix?
      children.length == 1
    end

    # Returns a child node by index, starting with 0.
    def [](child_nr)
      children[child_nr]
    end

  end

  # AST class for representing AND or OR constructs.
  # Logical constructs can be simplified resulting in a less complex AST.
  class LogicalOperatorNode < OperatorNode

    # Checks whether another node is comparable so that it can be used for tree simplification.
    # A node can only be simplified if the logical operator is equal.
    def compatible_with(node)
      node.kind_of?(LogicalOperatorNode) && node.operator == self.operator
    end

    # Simplifies nested AND and OR constructs to single constructs with multiple arguments:
    # e.g. (a AND (b AND c)) -> (a AND b AND c)
    def simplify
      if children.length == 1
        # AND or OR constructs do nothing if they only have one operand
        # So remove the logal operator from the AST by simply using the opeand
        return children.first.simplify
      else
        # nested AND or OR constructs can be combined into one construct
        @children = children.map { |c| c.simplify }.map { |c| self.compatible_with(c) ? c.children : c }.flatten
        return self
      end
    end
  end
end
