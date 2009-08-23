$:.reject! { |e| e.include? 'TextMate' }
$: << File.join(File.dirname(__FILE__), '..', 'lib')

require 'rubygems'
require 'spec'
require 'active_record'

require 'scoped_search'
require 'scoped_search/query_language'

module ScopedSearch::Spec; end

require "#{File.dirname(__FILE__)}/lib/matchers"
require "#{File.dirname(__FILE__)}/lib/database"

Spec::Runner.configure do |config|
  config.include ScopedSearch::Spec::Matchers
end
