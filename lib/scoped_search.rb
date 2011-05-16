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

  # The current scoped_search version. Do not change thisvalue by hand,
  # because it will be updated automatically by the gem release script.
  VERSION = "2.3.0"

  # The ClassMethods module will be included into the ActiveRecord::Base class
  # to add the <tt>ActiveRecord::Base.scoped_search</tt> method and the
  # <tt>ActiveRecord::Base.search_for</tt> named scope.
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

  # The <tt>BackwardsCompatibility</tt> module can be included into
  # <tt>ActiveRecord::Base</tt> to provide the <tt>searchable_on</tt> search
  # field definition syntax that is compatible with scoped_seach 1.x
  #
  # Currently, it is included into <tt>ActiveRecord::Base</tt> by default, but
  # this may change in the future. So, please uodate to the newer syntax as
  # soon as possible.
  module BackwardsCompatibility

    # Defines fields to search on using a syntax compatible with scoped_search 1.x
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
require 'scoped_search/definition'
require 'scoped_search/query_language'
require 'scoped_search/query_builder'
require 'scoped_search/auto_complete_builder'

# Import the search_on method in the ActiveReocrd::Base class
ActiveRecord::Base.send(:extend, ScopedSearch::ClassMethods)
ActiveRecord::Base.send(:extend, ScopedSearch::BackwardsCompatibility)

if defined?(ActionController)
  require "scoped_search/rails_helper"
  ActionController::Base.helper(ScopedSearch::RailsHelper)
end
