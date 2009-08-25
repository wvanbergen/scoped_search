module ScopedSearch
      
  module ClassMethods
    
    # Export the scoped_search method fo defining the search options.
    # This method will create a definition instance for the class if it does not yet exist,
    # and use the object as block argument and retun value.
    def scoped_search(*definitions)
      @scoped_search ||= ScopedSearch::Definition.new(self)
      definitions.each do |definition|
        if definition[:on].kind_of?(Array)
          definition[:on].each { |field| @scoped_search.define(definition.merge(:on => field)) }
        else
          @scoped_search.define(definition)
        end
      end
      return @scoped_search
    end

  end
  
  module BackwardsCompatibility
    # Defines fields to search on using a syntax compatible with scoped_search 1.2
    def searchable_on(*fields)
      fields.each do |field| 
        if relation = self.reflections.keys.detect { |relation| field.to_s =~ Regexp.new("^#{relation}_(\\w+)$") }
          scoped_search(:in => relation, :on => $1.to_sym) 
        else
          scoped_search(:on => field)
        end
      end
    end    
  end
  
  class Exception < StandardError
  end

  class DefinitionError < ScopedSearch::Exception
  end
  
  class QueryNotSupported < ScopedSearch::Exception
  end
  
end

# Load all lib files
require 'scoped_search/definition'
require 'scoped_search/adapters'
require 'scoped_search/query_language'
require 'scoped_search/query_builder'

# Import the search_on method in the ActiveReocrd::Base class
ActiveRecord::Base.send(:extend, ScopedSearch::ClassMethods)
ActiveRecord::Base.send(:extend, ScopedSearch::BackwardsCompatibility)
