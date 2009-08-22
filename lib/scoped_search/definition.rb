module ScopedSearch
  
  class Definition
    
    class Field
      
      attr_reader :definition, :field, :only_explicit #, :relation
      
      def column
        definition.klass.columns_hash[field.to_s]
      end
      
      def temporal?
        [:datetime, :time, :timestamp].include? column.type
      end
      
      def numerical?
        [:integer, :double, :float, :decimal].include? column.type
      end
      
      def textual?
        [:string, :text].include? column.type
      end
      
      def default_operator
        @default_operator ||= begin
          case column.type
          when :string, :text
            :like
          else 
            :eq
          end
        end
      end
      
      def initialize(definition, field, options = {})
        @definition = definition
        @field      = field.to_sym

        # Parse options hash
        @only_explicit    = !!options[:only_explicit]
        @default_operator = options[:default_operator] if options.has_key?(:default_operator)
        
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
      
      register_named_scope! unless klass.respond_to?(:search_for)
    end
    
    NUMBER_REGXP    = /^\-?\d+(\.\d+)?$/
    YYYYMMDD_REGEXP = /^\d{4}[\/\-]?\d{2}[\/\-]?\d{2}$/
    DATELIKE_REGEXP = YYYYMMDD_REGEXP
    
    def default_fields_for(value, operator = nil)
      # Use the value to detect
      column_types  = []
      column_types += [:string, :text]                      if [nil, :like, :unlike, :ne, :eq].include?(operator)
      column_types += [:integer, :double, :float, :decimal] if value =~ NUMBER_REGXP
      column_types += [:datetime, :date, :timestamp]        if value =~ DATELIKE_REGEXP

      default_fields.select { |field| column_types.include?(field.column.type) }
    end
    
    def default_fields
      unique_fields.reject { |field| field.only_explicit }
    end
    
    def on(field, options ={})
      Field.new(self, field, options)
    end
    
    protected
    
    # Registers the search_for named scope within the class
    def register_named_scope! # :nodoc
      @klass.named_scope(:search_for, lambda { |*args| ScopedSearch::QueryBuilder.build_query(args[1] || self, args[0]) })
    end    
    
  end
  
end