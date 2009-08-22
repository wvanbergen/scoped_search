module ScopedSearch
  
  class Definition
    
    attr_accessor :fields, :default_fields
    
    def initialize(klass)
      @klass = klass
      @fields = {}
      @default_fields = {}
      
      register_named_scope!
    end
    
    # Registers the search_for named scope within the class
    def register_named_scope!
      @klass.named_scope(:search_for, lambda { |query| ScopedSearch::QueryBuilder.build_query(@klass, query) })
    end
    
    def on(field, options ={})
      # Store the search definition in the @scoped_search_fields hash.
      fields[field] = options.merge(:field => field)
    
      # Set search definition for alias / aliases as well
      fields[options[:alias]] = fields[field] if options[:alias]
      options[:aliases].each { |al| fields[al] = fields[field] } if options[:aliases]
      
      default_fields[field] = fields[field] unless false === options[:default]
    end
    
  end
  
end