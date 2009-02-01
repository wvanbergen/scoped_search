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
   
    def to_sql(definition)
      "?"
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
       
      rewrite_children! if [:and, :or].include?(operator)
    end
     
    def simplify
      if [:and, :or].include?(operator) && children.length == 1
        return children.first.simplify
      else
        @children = children.map { |c| c.simplify }
        return self 
      end
    end
     
     def rewrite_children!
       if children.length == 1 
         if children.first.kind_of?(OperatorNode)
           child = children.first
           @operator = child.operator
           @children = child.children
         end
       else
         @children = children.clone
         simplified_children = []
         while child = children.shift
           if child.kind_of?(OperatorNode) && child.operator == self.operator
             simplified_children += child.children
           else
             simplified_children << child
           end
         end
         @children = simplified_children
       end
     end
     
     def sql_operator
       case @operator
       when :and; ' AND '
       when :or;  ' OR '
       when :eq;  ' = '
       when :ne;  ' <> '  
       when :gt;  ' > '
       when :gte; ' >= '
       when :lt;  ' < '
       when :lte; ' <= '
       end
     end
   
     def to_sql(definition)
       sql_op = sql_operator
       '(' + children.map { |c| c.to_sql(definition) }.join(sql_op) + ')'
     end
     
     def to_a
       [@operator] + @children.map { |c| c.to_a }
     end
   end      
 
   class FunctionNode
     attr_reader :function
     attr_reader :arguments
   
     def initialize(function, *arguments)
       @function  = function
       @arguments = arguments
     end
     
     def simplify
       @children = arguments.map { |a| a.simplify }
       return self
     end
   
     def to_sql(definition)
       "#{@function.to_s.upcase}(#{@arguments.map { |a| a.to_sql(definition) }.join(', ') })"
     end
     
     def to_a
       [@function] + @arguments.map { |a| a.to_a }
     end      
   end
end