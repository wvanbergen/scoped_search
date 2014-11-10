require 'rubygems'
require 'bundler/setup'

require 'rspec'
require 'scoped_search'

module ScopedSearch::RSpec; end

require "#{File.dirname(__FILE__)}/lib/matchers"
require "#{File.dirname(__FILE__)}/lib/database"
require "#{File.dirname(__FILE__)}/lib/mocks"


RSpec.configure do |config|
  config.include ScopedSearch::RSpec::Mocks

  config.expect_with :rspec do |c|
    c.syntax = :should
  end

  config.mock_with :rspec do |mocks|
    mocks.syntax = :should
  end
end
