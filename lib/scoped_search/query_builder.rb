module ScopedSearch

  class QueryBuilder
    
    attr_reader :ast, :definition
    
    
    def initialize(ast, definition)
      @ast = ast
      @definition = definition
    end
    
    def build_query(klass)
      parameters = []
      sql = @ast.to_sql(klass, @definition) { |parameter| parameters << parameter }
      return [sql] + parameters
    end
   
    module AST
      module LeafNode
        def to_sql(klass, definition, &block)
          fragments = definition.map do |(field, type)|
            yield("%#{value}%")
            "#{field} LIKE ?"
          end
          "(#{fragments.join(' OR ')})"
        end
      end
      
      module OperatorNode
        
        def to_sql_operator(column)
          case operator
          when :eq; [:string, :text].include?(column.type) ? 'LIKE' : '='  
          when :ne; [:string, :text].include?(column.type) ? 'NOT LIKE' : '<>'  
          when :gt; '>'
          when :lt; '<'
          when :lte; '<='
          when :gte; '>='
          end
        end
        
        def to_sql(klass, definition, &block)

          if operator == :not
            child = children.first
            "(NOT(#{child.to_sql(klass, definition, &block)}) OR #{child.to_sql(klass, definition, &block)} IS NULL)"
          elsif children.length == 1
            raise 'boeh'
          elsif children.length == 2
            raise "Not a leaf node" unless children.first.kind_of?(ScopedSearch::QueryLanguage::AST::LeafNode)
            raise "Not a leaf node" unless children.last.kind_of?(ScopedSearch::QueryLanguage::AST::LeafNode)

            field = children.first.value.to_sym
            raise "Unknown column"  unless klass.columns_hash.has_key?(field.to_s)
            sql_operator = to_sql_operator(klass.columns_hash[field.to_s])
            field_name = klass.connection.quote_table_name(klass.table_name) + "." + klass.connection.quote_column_name(field)

            puts "(#{field_name} #{sql_operator} ?)"
            puts children.last.value
            
            yield(children.last.value)
            "(#{field_name} #{sql_operator} ?)"
          else
            raise 'bah'            
          end
        end 
      end
      
      # AND and OR constructs
      module LogicalOperatorNode
        def to_sql(klass, definition, &block)
          sql_fragments = children.map { |c| c.to_sql(klass, definition, &block) }
          "(#{sql_fragments.join(" #{operator.to_s.upcase} ")})"
        end 
      end      
    end
  end

  QueryLanguage::AST::LeafNode.send(:include, QueryBuilder::AST::LeafNode)
  QueryLanguage::AST::OperatorNode.send(:include, QueryBuilder::AST::OperatorNode)
  QueryLanguage::AST::LogicalOperatorNode.send(:include, QueryBuilder::AST::LogicalOperatorNode)  
end
