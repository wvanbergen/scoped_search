module ScopedSearch
  
  class Definition
    
    class Field
      
      attr_reader :definition, :field, :only_explicit, :default_operator, :relation
      
      def initialize(definition, field, options = {})
        @definition = definition
        @field      = field.to_sym

        # Parse options hash
        @only_explicit       = !!options[:only_explicit]
        @default_operator    = :like  # TODO: fix me
        
        # Store this field is the field array
        definition.fields[@field] = self
        definition.unique_fields << self
        
        # Store definition for alias / aliases as well
        definition.fields[options[:alias]] = self                    if options[:alias]
        options[:aliases].each { |al| definition.fields[al] = self } if options[:aliases]        
      end

      def to_sql
        definition.klass.connection.quote_table_name(definition.klass.table_name) + "." + 
              definition.klass.connection.quote_column_name(field)
      end
    end
    
    attr_reader :klass, :fields, :unique_fields
    
    def initialize(klass)
      @klass         = klass
      @fields        = {}
      @unique_fields = []
      
      register_named_scope!
    end
    
    def default_fields(type = nil)
      unique_fields.reject { |field| field.only_explicit }
    end
    
    def on(field, options ={})
      Field.new(self, field, options)
    end
    
    protected
    
    # Registers the search_for named scope within the class
    def register_named_scope! # :nodoc
      @klass.named_scope(:search_for, lambda { |query| ScopedSearch::QueryBuilder.build_query(@klass, query) })
    end    
    
  end
  
end