module ScopedSearch
  
  module ClassMethods
  
    def self.extended(base)
      require 'scoped_search/reg_tokens'
      require 'scoped_search/query_language_parser'
      require 'scoped_search/query_conditions_builder'
    end
  
    # Creates a named scope in the class it was called upon
    def searchable_on(*fields)
      if fields.first.class.to_s == 'Hash'
        if fields.first.has_key?(:only)
          fields = fields.first[:only]
        elsif fields.first.has_key?(:except)
          fields = self.columns_hash.collect { |column| 
                     fields.first[:except].include?(column[0].to_sym) ? nil : column[0].to_sym }.compact
        end
      end

      self.cattr_accessor :scoped_search_fields
      self.scoped_search_fields = fields
      self.named_scope :search_for, lambda { |keywords| self.build_scoped_search_conditions(keywords) }
    end
  
    # Build a hash that is used for the named_scope search_for.
    # This function will split the search_string into keywords, and search for all the keywords
    # in the fields that were provided to searchable_on
    def build_scoped_search_conditions(search_string)    
      if search_string.nil? || search_string.strip.blank?
        return {:conditions => nil}
      else        
        query_fields = {}
        self.scoped_search_fields.each do |field| 
          field_name = connection.quote_table_name(table_name) + "." + connection.quote_column_name(field)
          query_fields[field_name] = self.columns_hash[field.to_s].type
        end
        
        search_conditions = QueryLanguageParser.parse(search_string) 
        conditions = QueryConditionsBuilder.build_query(search_conditions, query_fields) 
        return {:conditions => conditions}
      end
    end
  end
end

ActiveRecord::Base.send(:extend, ScopedSearch::ClassMethods)