if defined?(ActionController)
  require "scoped_search/rails_helper"
  ActionController::Base.helper(ScopedSearch::RailsHelper)
end

if defined?(::Rails::Engine)
  require 'scoped_search/engine'
end
