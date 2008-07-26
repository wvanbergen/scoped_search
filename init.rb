$:.unshift "#{File.dirname(__FILE__)}/lib"
require 'active_record/scoped_search'
require 'active_record/scoped_search/query_string_parser'
ActiveRecord::Base.class_eval { extend ActiveRecord::ScopedSearch }