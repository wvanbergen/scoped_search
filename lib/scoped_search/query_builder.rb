module ScopedSearch

  class QueryBuilder
    
    attr_reader :ast, :definition
    
    # Creates a find parameter hash given a class, and query string.
    def self.build_query(definition, query) 
      # Return all record when an empty search string is given
      if !query.kind_of?(String) || query.strip.blank?
        return { :conditions => nil }
      elsif query.kind_of?(ScopedSearch::QueryLanguage::AST::Node)
        return self.new(definition, query).build_find_params
      else
        return self.new(definition, ScopedSearch::QueryLanguage::Compiler.parse(query)).build_find_params
      end
    end

    # Initializes the instance by setting the relevant parameters
    def initialize(definition, ast)
      @definition, @ast = definition, ast
    end
    
    # Actually builds the find parameters
    def build_find_params
      parameters = []
      includes   = []
      
      # Build SQL WHERE clause using the AST
      sql = @ast.to_sql(definition) do |notification, value|
        
        # Handle the notifications encountered during the SQL generation:
        # Store the parameters, includes, etc so that they can be added to
        # the find-hash later on.
        case notification
        when :parameter then parameters << value
        when :include   then includes   << value
        else raise ScopedSearch::QueryNotSupported, "Cannot handle #{notification.inspect}: #{value.inspect}"
        end
      end
      
      # Build hash for ActiveRecord::Base#find for the named scope
      find_attributes = {}
      find_attributes[:conditions] = [sql] + parameters unless sql.nil?
      find_attributes[:include]    = includes.uniq      unless includes.empty?
      # p find_attributes # Uncomment for debugging
      return find_attributes
    end
    
    # Return the SQL operator to use
    def self.sql_operator(operator, field)
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

    # Perform a comparison between a field and a Date(Time) value.
    # Makes sure the date is valid and adjust the comparison in
    # some cases to return more logical results
    def self.datetime_test(field, operator, value, &block)
      
      # Parse the value as a date/time and ignore invalid timestamps
      timestamp = parse_temporal(value)
      return nil unless timestamp 
      timestamp = Date.parse(timestamp.strftime('%Y-%m-%d')) if field.date?      
      
      # Check for the case that a date-only value is given as search keyword,
      # but the field is of datetime type. Change the comparison to return
      # more logical results.
      if timestamp.day_fraction == 0 && field.datetime?
        
        if [:eq, :ne].include?(operator)
          # Instead of looking for an exact (non-)match, look for dates that
          # fall inside/outside the range of timestamps of that day.
          yield(:parameter, timestamp)
          yield(:parameter, timestamp + 1)
          negate    = (operator == :ne) ? 'NOT' : ''
          field_sql = field.to_sql(operator, &block)
          return "#{negate}(#{field_sql} >= ? AND #{field_sql} < ?)"
          
        elsif operator == :gt
          # Make sure timestamps on the given date are not included in the results
          # by moving the date to the next day.
          timestamp += 1
          operator = :gte
          
        elsif operator == :lte
          # Make sure the timestamps of the given date are included by moving the 
          # date to the next date.
          timestamp += 1
          operator = :lt
        end
      end
    
      # Yield the timestamp and return the SQL test
      yield(:parameter, timestamp)
      "#{field.to_sql(operator, &block)} #{self.sql_operator(operator, field)} ?"
    end
    
    # Generates a simple SQL test expression, for a field and value using an operator.
    def self.sql_test(field, operator, value, &block)
      if [:like, :unlike].include?(operator) && value !~ /^\%/ && value !~ /\%$/
        yield(:parameter, "%#{value}%")
        return "#{field.to_sql(operator, &block)} #{self.sql_operator(operator, field)} ?"
      elsif field.temporal?
        return datetime_test(field, operator, value, &block)
      else
        yield(:parameter, value)
        return "#{field.to_sql(operator, &block)} #{self.sql_operator(operator, field)} ?"
      end
    end
    
    # Try to parse a string as a datetime.
    def self.parse_temporal(value)
      DateTime.parse(value, true) rescue nil
    end

    module Field
      
      # Return an SQL representation for this field
      def to_sql(operator = nil, &block)
        yield(:include, relation) if relation
        definition.klass.connection.quote_table_name(klass.table_name) + "." + 
            definition.klass.connection.quote_column_name(field)
      end
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
            
        # Returns a NOT(...)  SQL fragment that negates the current AST node's children  
        def to_not_sql(definition, &block)
          "(NOT(#{rhs.to_sql(definition, &block)}) OR #{rhs.to_sql(definition, &block)} IS NULL)"
        end
        
        # Returns a IS (NOT) NULL SQL fragment
        def to_null_sql(definition, &block)
          field = definition.fields[rhs.value.to_sym]  
          raise ScopedSearch::QueryNotSupported, "Field '#{rhs.value}' not recognized for searching!" unless field
          
          case operator
            when :null    then "#{field.to_sql(&block)} IS NULL"
            when :notnull then "#{field.to_sql(&block)} IS NOT NULL"
          end
        end
        
        # No explicit field name given, run the operator on all default fields
        def to_default_fields_sql(definition, &block)
          raise ScopedSearch::QueryNotSupported, "Value not a leaf node" unless rhs.kind_of?(ScopedSearch::QueryLanguage::AST::LeafNode)          
          
          # Search keywords found without context, just search on all the default fields
          fragments = definition.default_fields_for(rhs.value, operator).map { |field|
            ScopedSearch::QueryBuilder.sql_test(field, operator, rhs.value, &block) }.compact
          fragments.empty? ? nil : "(#{fragments.join(' OR ')})"
        end
        
        # Explicit field name given, run the operator on the specified field only
        def to_single_field_sql(definition, &block)
          raise ScopedSearch::QueryNotSupported, "Field name not a leaf node" unless lhs.kind_of?(ScopedSearch::QueryLanguage::AST::LeafNode)
          raise ScopedSearch::QueryNotSupported, "Value not a leaf node"      unless rhs.kind_of?(ScopedSearch::QueryLanguage::AST::LeafNode)
          
          # Search only on the given field.
          field = definition.fields[lhs.value.to_sym]
          raise ScopedSearch::QueryNotSupported, "Field '#{lhs.value}' not recognized for searching!" unless field
          ScopedSearch::QueryBuilder.sql_test(field, operator, rhs.value, &block)
        end
        
        # Convert this AST node to an SQL fragment.
        def to_sql(definition, &block)
          if operator == :not && children.length == 1
            to_not_sql(definition, &block)
          elsif [:null, :notnull].include?(operator)
            to_null_sql(definition, &block)
          elsif children.length == 1
            to_default_fields_sql(definition, &block)            
          elsif children.length == 2
            to_single_field_sql(definition, &block)
          else
            raise ScopedSearch::QueryNotSupported, "Don't know how to handle this operator node: #{operator.inspect} with #{children.inspect}!"
          end
        end 
      end
      
      # Defines the to_sql method for AST AND/OR operators
      module LogicalOperatorNode
        def to_sql(definition, &block)
          fragments = children.map { |c| c.to_sql(definition, &block) }.compact
          fragments.empty? ? nil : "(#{fragments.join(" #{operator.to_s.upcase} ")})"
        end 
      end      
    end
  end

  Definition::Field.send(:include, QueryBuilder::Field)
  QueryLanguage::AST::LeafNode.send(:include, QueryBuilder::AST::LeafNode)
  QueryLanguage::AST::OperatorNode.send(:include, QueryBuilder::AST::OperatorNode)
  QueryLanguage::AST::LogicalOperatorNode.send(:include, QueryBuilder::AST::LogicalOperatorNode)  
end
