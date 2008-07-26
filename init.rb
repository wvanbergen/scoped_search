$:.unshift "#{File.dirname(__FILE__)}/lib"
require 'active_record/scoped_search'
ActiveRecord::Base.class_eval { extend ActiveRecord::ScopedSearch }