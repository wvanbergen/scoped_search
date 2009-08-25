module ScopedSearch
  
  class Definition
    
    class Field
      
      attr_reader :definition, :field, :only_explicit, :relation
      
      def klass
        if relation
          definition.klass.reflections[relation].klass
        else
          definition.klass
        end
      end
      
      # Find the relevant column definition in the AR class
      def column
        klass.columns_hash[field.to_s]
      end
      
      def type
        column.type
      end
      
      def datetime?
        [:datetime, :time, :timestamp].include?(type)
      end
      
      def date?
        type == :date
      end
      
      def temporal?
        datetime? || date?
      end
      
      def numerical?
        [:integer, :double, :float, :decimal].include?(type)
      end
      
      def textual?
        [:string, :text].include?(type)
      end
      
      # Returns the default search operator for this field.
      def default_operator
        @default_operator ||= case type
          when :string, :text then :like
          else :eq
        end
      end

      def initialize(definition, field, options = {})
        @definition = definition
        @field      = field.to_sym

        # Set attributes from options hash
        @relation         = options[:relation]
        @only_explicit    = !!options[:only_explicit]
        @default_operator = options[:default_operator] if options.has_key?(:default_operator)
        
        # Store this field is the field array
        definition.fields[@field] ||= self
        definition.unique_fields   << self
        
        # Store definition for alias / aliases as well
        definition.fields[options[:alias]] ||= self                    if options[:alias]
        options[:aliases].each { |al| definition.fields[al] ||= self } if options[:aliases]        
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
    
    def default_fields_for(value, operator = nil)
      # Use the value to detect
      column_types  = []
      column_types += [:string, :text]                      if [nil, :like, :unlike, :ne, :eq].include?(operator)
      column_types += [:integer, :double, :float, :decimal] if value =~ NUMBER_REGXP
      column_types += [:datetime, :date, :timestamp]        if ScopedSearch::QueryBuilder.parse_temporal(value)

      default_fields.select { |field| column_types.include?(field.type) }
    end
    
    def default_fields
      unique_fields.reject { |field| field.only_explicit }
    end
    
    def on(field, options = {})
      Field.new(self, field, options)
    end
    
    def in(relation, options)
      field = options.delete(:on)
      options[:relation] = relation
      Field.new(self, field, options)
    end
    
    protected
    
    # Registers the search_for named scope within the class
    def register_named_scope! # :nodoc
      @klass.named_scope(:search_for, lambda { |*args| ScopedSearch::QueryBuilder.build_query(args[1] || self, args[0]) })
    end    
    
  end
  
end