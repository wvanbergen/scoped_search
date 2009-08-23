module ScopedSearch

  class QueryBuilder
    
    attr_reader :ast, :definition
    
    # Creates a find parameter hash given a class, and query string.
    def self.build_query(definition, query) 
      # Return all record when an empty search string is given
      if !query.kind_of?(String) || query.strip.blank?
        return { :conditions => nil }
      else
        builder = self.new(definition, ScopedSearch::QueryLanguage::Compiler.parse(query))
        return builder.build_find_params
      end
    end

    # Initializes the instance by setting the relevant parameters
    def initialize(definition, ast)
      @definition, @ast = definition, ast
    end
    
    # Actually builds the find parameters
    def build_find_params
      parameters = []
      sql = @ast.to_sql(definition) { |parameter| parameters << parameter }
      return { :conditions => [sql] + parameters }
    end
    
    def self.sql_operator(operator)
      case operator
      when :eq;     '='  
      when :like;   'LIKE'              
      when :unlike; 'NOT LIKE'              
      when :ne;     '<>'  
      when :gt;     '>'
      when :lt;     '<'
      when :lte;    '<='
      when :gte;    '>='
      end  
    end
    
    def self.sql_test(field, operator, value, &block)
      if [:like, :unlike].include?(operator) && value !~ /^\%/ && value !~ /\%$/
        yield("%#{value}%")
      elsif field.temporal?
        timestamp = parse_temporal(value)
        return if timestamp.nil?
        yield(timestamp) 
      else
        yield(value)
      end
      "#{field.to_sql} #{self.sql_operator(operator)} ?"
    end
    
    def self.parse_temporal(value)
      Time.parse(value) rescue nil
    end

    module AST
      
      # Defines the to_sql method for AST LeadNodes
      module LeafNode
        def to_sql(definition, &block)
          # Search keywords found without context, just search on all the default fields
          fragments = definition.default_fields_for(value).map do |field|
            ScopedSearch::QueryBuilder.sql_test(field, field.default_operator, value, &block)
          end
          "(#{fragments.join(' OR ')})"
        end
      end
      
      # Defines the to_sql method for AST operator nodes
      module OperatorNode
        
        def sql_operator
          ScopedSearch::QueryBuilder.sql_operator(operator)
        end
        
        def to_not_sql(definition, &block)
          child = children.first
          "(NOT(#{child.to_sql(definition, &block)}) OR #{child.to_sql(definition, &block)} IS NULL)"
        end
        
        def to_default_fields_sql(definition, &block)
          raise "Value not a leaf node" unless children.last.kind_of?(ScopedSearch::QueryLanguage::AST::LeafNode)          
          
          # Search keywords found without context, just search on all the default fields
          fragments = definition.default_fields_for(children.last.value, operator).map do |field|
            ScopedSearch::QueryBuilder.sql_test(field, operator, children.last.value, &block)
          end
          "(#{fragments.join(' OR ')})"
        end
        
        def to_single_field_sql(definition, &block)
          raise "Field name not a leaf node" unless children.first.kind_of?(ScopedSearch::QueryLanguage::AST::LeafNode)
          raise "Value not a leaf node" unless children.last.kind_of?(ScopedSearch::QueryLanguage::AST::LeafNode)
          
          # Search only on the given field.
          field = definition.fields[children.first.value.to_sym]
          raise "Field not recognized for searching!" unless field
          ScopedSearch::QueryBuilder.sql_test(field, operator, children.last.value, &block)
        end
        
        def to_sql(definition, &block)
          if operator == :not && children.length == 1
            to_not_sql(definition, &block)
          elsif children.length == 1
            to_default_fields_sql(definition, &block)            
          elsif children.length == 2
            to_single_field_sql(definition, &block)
          else
            raise "Don't know how to handle this operator node: #{operator.inspect} with #{children.inspect}!"
          end
        end 
      end
      
      # Defines the to_sql method for AST AND/OR operators
      module LogicalOperatorNode
        def to_sql(definition, &block)
          fragments = children.map { |c| c.to_sql(definition, &block) }
          "(#{fragments.join(" #{operator.to_s.upcase} ")})"
        end 
      end      
    end
  end

  QueryLanguage::AST::LeafNode.send(:include, QueryBuilder::AST::LeafNode)
  QueryLanguage::AST::OperatorNode.send(:include, QueryBuilder::AST::OperatorNode)
  QueryLanguage::AST::LogicalOperatorNode.send(:include, QueryBuilder::AST::LogicalOperatorNode)  
end
