require 'active_record'

# ScopedSearch is the base module for the scoped_search plugin. This file
# defines some modules and exception classes, loads the necessary files, and
# installs itself in ActiveRecord.
#
# The ScopedSearch module defines two modules that can be mixed into
# ActiveRecord::Base as class methods. <tt>ScopedSearch::ClassMethods</tt>
# will register the scoped_search class function, which can be used to define
# the search fields. <tt>ScopedSearch::BackwardsCompatibility</tt> will
# register the <tt>searchable_on</tt> method for backwards compatibility with
# previous scoped_search versions (1.x).
module ScopedSearch

  # The ClassMethods module will be included into the ActiveRecord::Base class
  # to add the <tt>ActiveRecord::Base.scoped_search</tt> method and the
  # <tt>ActiveRecord::Base.search_for</tt> named scope.
  module ClassMethods

    def self.extended(base)
      super
      base.class_attribute :scoped_search_definition
    end

    # Export the scoped_search method fo defining the search options.
    # This method will create a definition instance for the class if it does not yet exist,
    # or if a parent definition exists then it will create a new one inheriting it,
    # and use the object as block argument and return value.
    def scoped_search(*definitions)
      self.scoped_search_definition ||= ScopedSearch::Definition.new(self)
      unless self.scoped_search_definition.klass == self  # inheriting the parent
        self.scoped_search_definition = ScopedSearch::Definition.new(self)
      end

      definitions.each do |definition|
        if definition[:on].kind_of?(Array)
          definition[:on].each { |field| self.scoped_search_definition.define(definition.merge(:on => field)) }
        else
          self.scoped_search_definition.define(definition)
        end
      end
      return self.scoped_search_definition
    end
  end

  # The default scoped_search exception class.
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
require 'scoped_search/version'
require 'scoped_search/definition'
require 'scoped_search/query_language'
require 'scoped_search/query_builder'
require 'scoped_search/auto_complete_builder'
require 'scoped_search/validators'

# Import the search_on method in the ActiveReocrd::Base class
ActiveRecord::Base.send(:extend, ScopedSearch::ClassMethods)

# Rails & Compass integration
require 'scoped_search/railtie' if defined?(::Rails)
require 'scoped_search/compass' if defined?(::Compass)
