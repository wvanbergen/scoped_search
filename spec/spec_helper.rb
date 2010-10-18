$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'rubygems'
require 'rspec'
require 'active_record'

require 'scoped_search'

module ScopedSearch::RSpec; end

require "#{File.dirname(__FILE__)}/lib/matchers"
require "#{File.dirname(__FILE__)}/lib/database"
require "#{File.dirname(__FILE__)}/lib/mocks"


RSpec.configure do |config|
  config.include ScopedSearch::RSpec::Mocks
end
