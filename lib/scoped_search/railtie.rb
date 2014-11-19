require 'scoped_search/engine'

module ScopedSearch
  class Railtie < ::Rails::Railtie

    initializer "scoped_search.setup_rails_helper" do |app|
      ActiveSupport.on_load :action_controller do
        require "scoped_search/rails_helper"
        ActionController::Base.helper(ScopedSearch::RailsHelper)
      end
    end
  end
end
