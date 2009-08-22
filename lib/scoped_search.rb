module ScopedSearch
      
  module ClassMethods
    
    def self.extended(base) # :nodoc:
      require 'scoped_search/query_language'
      require 'scoped_search/query_builder'
      require 'scoped_search/definition'      
    end
    
    # Export the scoped_search method fo defining the search options
    def scoped_search
      @scoped_search ||= ScopedSearch::Definition.new(self)
      yield(@scoped_search) if block_given?
      return @scoped_search
    end

    # Backwards compatibility?
    def searchable_on(*fields)
      fields.each { |field| scoped_search.on(field) }
    end
  end
end

# Import the search_on method in the ActiveReocrd::Base class
ActiveRecord::Base.send(:extend, ScopedSearch::ClassMethods)
