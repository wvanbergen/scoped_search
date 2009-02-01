module ScopedSearch

  class QueryBuilder
    
    attr_reader :ast, :definition
    
    
    def initialize(ast, definition)
      @ast = ast
      @definition = definition
    end
    
    def build_query
      parameters = []
      sql = @ast.to_sql(@definition) { |parameter| parameters << parameter }
      return [sql] + parameters
    end
   
    module AST
      module LeafNode
        def to_sql(definition, &block)
          fragments = definition.map do |(field, type)|
            yield("%#{value}%")
            "#{field} LIKE ?"
          end
          "(#{fragments.join(' OR ')})"
        end
      end
      
      module OperatorNode
        def to_sql(definition, &block)

          if operator == :not
            child = children.first
            "(NOT(#{child.to_sql(definition, &block)}) OR #{child.to_sql(definition, &block)} IS NULL)"
          elsif children.length == 1
            raise 'boeh'
          else
            raise 'bah'            
          end
        end 
      end
      
      module LogicalOperatorNode
        def to_sql(definition, &block)
          sql_fragments = children.map { |c| c.to_sql(definition, &block) }
          "(#{sql_fragments.join(" #{operator.to_s.upcase} ")})"
        end 
      end      
    end
  end

  QueryLanguage::AST::LeafNode.send(:include, QueryBuilder::AST::LeafNode)
  QueryLanguage::AST::OperatorNode.send(:include, QueryBuilder::AST::OperatorNode)
  QueryLanguage::AST::LogicalOperatorNode.send(:include, QueryBuilder::AST::LogicalOperatorNode)  
end
