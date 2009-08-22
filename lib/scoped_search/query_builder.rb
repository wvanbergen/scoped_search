module ScopedSearch

  class QueryBuilder
    
    attr_reader :ast, :klass
    
    # Creates a find parameter hash given a class, and query string.
    def self.build_query(klass, query) 
      # Return all record when an empty search string is given
      if !query.kind_of?(String) || query.strip.blank?
        return { :conditions => nil }
      else
        builder = self.new(klass, ScopedSearch::QueryLanguage::Compiler.parse(query))
        return builder.build_find_params
      end
    end

    # Initializes the klass by setting the relevant parameters
    def initialize(klass, ast)
      @klass, @ast = klass, ast
    end
    
    # Actually builds the find parameters
    def build_find_params
      parameters = []
      sql = @ast.to_sql(klass) { |parameter| parameters << parameter }
      return { :conditions => [sql] + parameters }
    end
   
    module AST
      
      # Defines the to_sql method for AST LeadNodes
      module LeafNode
        def to_sql(klass, &block)
          # Search keywords found without context, just search on all the default fields
          fragments = klass.scoped_search.default_fields.map do |(field, options)|
            field_name = klass.connection.quote_table_name(klass.table_name) + "." + klass.connection.quote_column_name(field)
            yield("%#{value}%")
            "#{field_name} LIKE ?"
          end
          "(#{fragments.join(' OR ')})"
        end
      end
      
      # Defines the to_sql method for AST operator nodes
      module OperatorNode
        
        def sql_operator
          case operator
          when :eq;        '='  
          when :like;      'LIKE'              
          when :not_like;  'NOT LIKE'              
          when :ne;        '<>'  
          when :gt;        '>'
          when :lt;        '<'
          when :lte;       '<='
          when :gte;       '>='
          end
        end
        
        def to_not_sql(klass, &block)
          child = children.first
          "(NOT(#{child.to_sql(klass, &block)}) OR #{child.to_sql(klass, &block)} IS NULL)"
        end
        
        def to_default_fields_sql(klass, &block)
          # Search keywords found without context, just search on all the default fields
          fragments = klass.scoped_search.default_fields.map do |(field, options)|
            
            field_name = klass.connection.quote_table_name(klass.table_name) + "." + klass.connection.quote_column_name(field)
            value = children.last.value
                      
            yield("#{value}")
            "#{field_name} #{sql_operator} ?"
          end
          "(#{fragments.join(' OR ')})"
        end
        
        def to_single_field_sql(klass, &block)
          raise "Not a leaf node" unless children.first.kind_of?(ScopedSearch::QueryLanguage::AST::LeafNode)
          raise "Not a leaf node" unless children.last.kind_of?(ScopedSearch::QueryLanguage::AST::LeafNode)
          
          field = klass.scoped_search.fields[children.first.value.to_sym]
          raise "Field not supported in search!" unless field
          field_name = klass.connection.quote_table_name(klass.table_name) + "." + klass.connection.quote_column_name(field[:field])
          
          yield(children.last.value)
          "(#{field_name} #{sql_operator} ?)"
        end
        
        def to_sql(klass, &block)
          if operator == :not && children.length == 1
            to_not_sql(klass, &block)
          elsif children.length == 1
            to_default_fields_sql(klass, &block)            
          elsif children.length == 2
            to_single_field_sql(klass, &block)
          else
            raise "Don't know how to handle this operator node: #{operator.inspect} with #{children.inspect}!"
          end
        end 
      end
      
      # Defines the to_sql method for AST AND/OR operators
      module LogicalOperatorNode
        def to_sql(klass, &block)
          sql_fragments = children.map { |c| c.to_sql(klass, &block) }
          "(#{sql_fragments.join(" #{operator.to_s.upcase} ")})"
        end 
      end      
    end
  end

  QueryLanguage::AST::LeafNode.send(:include, QueryBuilder::AST::LeafNode)
  QueryLanguage::AST::OperatorNode.send(:include, QueryBuilder::AST::OperatorNode)
  QueryLanguage::AST::LogicalOperatorNode.send(:include, QueryBuilder::AST::LogicalOperatorNode)  
end
