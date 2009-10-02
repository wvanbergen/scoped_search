$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'rubygems'
require 'spec'
require 'active_record'

require 'scoped_search'

module ScopedSearch::Spec; end

require "#{File.dirname(__FILE__)}/lib/matchers"
require "#{File.dirname(__FILE__)}/lib/database"
require "#{File.dirname(__FILE__)}/lib/mocks"


Spec::Runner.configure do |config|
  config.include ScopedSearch::Spec::Matchers
  config.include ScopedSearch::Spec::Mocks
end
