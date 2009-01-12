module ScopedSearch
  
  module ClassMethods
  
    def self.extended(base)
      require 'scoped_search/reg_tokens'
      require 'scoped_search/query_language_parser'
      require 'scoped_search/query_conditions_builder'
    end
  
    # Creates a named scope in the class it was called upon
    def searchable_on(*fields)
      # Make sure that the table to be searched actually exists
      if self.table_exists?
        if fields.first.class.to_s == 'Hash'
          if fields.first.has_key?(:only)
            fields = fields.first[:only]
          elsif fields.first.has_key?(:except)
            fields = self.column_names.collect { |column| 
                     fields.first[:except].include?(column.to_sym) ? nil : column.to_sym }.compact
          end
        end
        
        assoc_models = self.reflections.collect { |key,value| key }
        assoc_fields = fields - self.column_names.collect { |column| column.to_sym }
        fields -= assoc_fields
        
        assoc_groupings = {}
        assoc_models.each do |assoc_model|
          assoc_groupings[assoc_model] = []
        	assoc_fields.each do |assoc_field|
        	  unless assoc_field.to_s.match(/^#{assoc_model.to_s}_/).nil?
              assoc_groupings[assoc_model] << assoc_field.to_s.sub(/^#{assoc_model.to_s}_/, '').to_sym 
            end
          end
        end
        
        assoc_groupings = assoc_groupings.delete_if {|group, field_group| field_group.empty?}
        
        self.cattr_accessor :scoped_search_fields, :scoped_search_assoc_groupings
        self.scoped_search_fields = fields
        self.scoped_search_assoc_groupings = assoc_groupings
        self.named_scope :search_for, lambda { |keywords| self.build_scoped_search_conditions(keywords) }
      end
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
        
        assoc_models_to_include = []
        self.scoped_search_assoc_groupings.each do |group|
          assoc_models_to_include << group[0]
          group[1].each do |group_field|
            field_name = connection.quote_table_name(group[0].to_s.pluralize) + "." + connection.quote_column_name(group_field)
            query_fields[field_name] = self.reflections[group[0]].klass.columns_hash[group_field.to_s].type
          end
        end
        
        search_conditions = QueryLanguageParser.parse(search_string) 
        conditions = QueryConditionsBuilder.build_query(search_conditions, query_fields) 
        
        retVal = {:conditions => conditions}
        retVal[:include] = assoc_models_to_include unless assoc_models_to_include.empty?

        return retVal
      end
    end
  end
end

ActiveRecord::Base.send(:extend, ScopedSearch::ClassMethods)