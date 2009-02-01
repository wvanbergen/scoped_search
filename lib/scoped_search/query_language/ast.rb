module ScopedSearch::QueryLanguage::AST
  
  class Node
    def inspect
      "<AST::#{self.class.to_s.split('::').last} #{self.to_a.inspect}>"
    end
    
    def simplify
      return self
    end
  end
   
  class LeafNode < Node
    attr_reader :value
   
    def initialize(value)
      @value = value
    end
     
    def to_a
      value
    end
  end

 
  class OperatorNode < Node
    attr_reader :operator
    attr_reader :children
     
    def initialize(operator, children)
      @operator = operator
      @children = children
    end
     
    def simplify
      @children = children.map { |c| c.simplify }
      return self 
    end
     
    def to_a
      [@operator] + @children.map { |c| c.to_a }
    end
  end
  

 class LogicalOperatorNode < OperatorNode
   
   def simplify
     if children.length == 1
       return children.first.simplify
     else
       @children = children.clone
       simplified_children = []
       while child = children.shift
         if child.kind_of?(LogicalOperatorNode) && child.operator == self.operator
           simplified_children += child.children.map { |c| c.simplify }
         else
           simplified_children << child.simplify
         end
       end
       @children = simplified_children
       return self  
     end
   end
 end  
end
