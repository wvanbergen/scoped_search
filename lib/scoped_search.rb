module ScopedSearch

  # The ClassMethods module will be included into the ActiveRecord::Base class to add
  # the ActiveRecord::Base.scoped_search method and the ActiveRecord::Base.search_for
  # named scope.
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

  # The BackwardsCompatibility module can be included into ActiveRecord::Base to provide
  # a search field definition syntax that is compatible with scoped_seach 1.x
  #
  # Currently, it is included into ActiveRecord::Base by default, but this may change in
  # the future. So, please uodate to the newer syntax as soon as possible.
  module BackwardsCompatibility

    # Defines fields to search on using a syntax compatible with scoped_search 1.2
    def searchable_on(*fields)

      options = fields.last.kind_of?(Hash) ? fields.pop : {}
      # TODO: handle options?

      fields.each do |field|
        if relation = self.reflections.keys.detect { |relation| field.to_s =~ Regexp.new("^#{relation}_(\\w+)$") }
          scoped_search(:in => relation, :on => $1.to_sym)
        else
          scoped_search(:on => field)
        end
      end
    end
  end

  # The default ScopedSearch exception class.
  class Exception < StandardError
  end

  # The default exception class that is raised when there is something
  # wrong with the scoped_search definition call.
  #
  # You usually do not want to catch this exception, but fix the faulty
  # scoped_search method call.
  class DefinitionError < ScopedSearch::Exception
  end

  # The default exception class that is raised when there is a problem
  # with parsing or interpreting a search query.
  #
  # You may want to catch this exception and handle this gracefully.
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
