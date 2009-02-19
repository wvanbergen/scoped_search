module ScopedSearch
  
  module ClassMethods
    
    def self.extended(base) # :nodoc:
      require 'scoped_search/query_language'
      require 'scoped_search/query_builder'
    end
  
    # Creates a named scope in the class it was called upon.
    #
    # fields:: The fields to search on.
    def searchable_on(*fields)
        
      # Get a collection of fields to be searched on.
      if fields.first.class.to_s == 'Hash'
        if fields.first.has_key?(:only)
          # only search on these fields.
          fields = fields.first[:only]
        elsif fields.first.has_key?(:except)
          # Get all the fields and remove any that are in the -except- list.
          fields = self.column_names.collect { |column| fields.first[:except].include?(column.to_sym) ? nil : column.to_sym }.compact
        end
      end
    
      # Get an array of associate modules.
      assoc_models = self.reflections.collect { |key,value| key }
    
      # Subtract out the fields to be searched on that are part of *this* model.
      # Any thing left will be associate module fields to be searched on.
      assoc_fields = fields - self.column_names.collect { |column| column.to_sym }
    
      # Subtraced out the associated fields from the fields so that you are only left
      # with fields in *this* model.
      fields -= assoc_fields
    
      # Loop through each of the associate models and group accordingly each
      # associate model field to search.  Assuming the following relations:
      # has_many :clients
      # has_many :notes,
      # belongs_to :user_type 
      # assoc_groupings will look like
      # assoc_groupings = {:clients => [:first_name, :last_name],
      #                    :notes => [:descr],
      #                    :user_type => [:identifier]}
      assoc_groupings = {}
      assoc_models.each do |assoc_model|
        assoc_groupings[assoc_model] = []
      	assoc_fields.each do |assoc_field|
      	  unless assoc_field.to_s.match(/^#{assoc_model.to_s}_/).nil?
            assoc_groupings[assoc_model] << assoc_field.to_s.sub(/^#{assoc_model.to_s}_/, '').to_sym 
          end
        end
      end

      # If a grouping does not contain any fields to be searched on then remove it.
      assoc_groupings = assoc_groupings.delete_if {|group, field_group| field_group.empty?}
    
      # Set the appropriate class attributes. 
      self.cattr_accessor :scoped_search_fields, :scoped_search_assoc_groupings
      self.scoped_search_fields = fields
      self.scoped_search_assoc_groupings = assoc_groupings
      self.named_scope :search_for, lambda { |keywords| self.build_scoped_search_conditions(keywords) }
    end
  
    # Build a hash that is used for the named_scope search_for.
    # This function will split the search_string into keywords, and search for all the keywords
    # in the fields that were provided to searchable_on.
    #
    # search_string:: The search string to parse.
    def build_scoped_search_conditions(search_string)    
      if search_string.nil? || search_string.strip.blank?
        return {:conditions => nil}
      else        
        query_fields = {}
        self.scoped_search_fields.each do |field| 
          field_name = connection.quote_table_name(table_name) + "." + connection.quote_column_name(field)
          query_fields[field_name] = self.columns_hash[field.to_s].type
        end
        
        assoc_model_indx = 0
        assoc_fields_indx = 1
        assoc_models_to_include = []
        self.scoped_search_assoc_groupings.each do |group|  
          assoc_models_to_include << group[assoc_model_indx]
          group[assoc_fields_indx].each do |group_field|
            field_name = connection.quote_table_name(group[assoc_model_indx].to_s.pluralize) + "." + connection.quote_column_name(group_field)
            query_fields[field_name] = self.reflections[group[assoc_model_indx]].klass.columns_hash[group_field.to_s].type
          end
        end
        
        ast = ScopedSearch::QueryLanguage::Compiler.parse(search_string) 
        conditions = ScopedSearch::QueryBuilder.new(ast, query_fields).build_query(self)
 
        retVal = {:conditions => conditions}
        retVal[:include] = assoc_models_to_include unless assoc_models_to_include.empty?

        return retVal
      end
    end
  end
end

ActiveRecord::Base.send(:extend, ScopedSearch::ClassMethods)