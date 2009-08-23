module ScopedSearch
      
  module ClassMethods
    
    # Export the scoped_search method fo defining the search options.
    # This method will create a definition instance for the class if it does not yet exist,
    # and use the object as block argument and retun value.
    def scoped_search
      @scoped_search ||= ScopedSearch::Definition.new(self)
      yield(@scoped_search) if block_given?
      return @scoped_search
    end

    # Defines fields to search on using a syntax compatible with scoped_search 1.2
    # TODO: improve backwards compatibility?
    def searchable_on(*fields)
      fields.each { |field| scoped_search.on(field) }
    end
  end
end

# Load all lib files
require 'scoped_search/definition'      
require 'scoped_search/query_language'
require 'scoped_search/query_builder'

# Import the search_on method in the ActiveReocrd::Base class
ActiveRecord::Base.send(:extend, ScopedSearch::ClassMethods)
