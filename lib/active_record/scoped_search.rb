module ActiveRecord::ScopedSearch
  
  # Creates a named scope in the class it was called upon
  def searchable_on(*fields)
    self.cattr_accessor :scoped_search_fields
    self.scoped_search_fields = fields
    self.named_scope :search_for, lambda { |keywords| self.build_scoped_search_conditions(keywords) }
  end
  
  # Build a hash that is used for the named_scope search_for.
  # This function will split the search_string into keywords, and search for all the keywords
  # in the fields that were provided to searchable_on
  def build_scoped_search_conditions(search_string)
    if search_string.nil? || search_string.strip.blank?
      return { :conditions => nil }
    else
      conditions = []
      query_params = {}

      
      class << search_string
        include ActiveRecord::ScopedSearch::QueryStringParser
      end
        
      search_string.to_search_query.each_with_index do |search_condition, index|
        keyword_name = "keyword_#{index}".to_sym
        query_params[keyword_name] = "%#{search_condition.first}%" 
        keyword_conditions = self.scoped_search_fields.map { |field| "#{connection.quote_column_name(field)} LIKE :#{keyword_name.to_s}" }

        # a keyword may be found in any of the provided fields, so join the conitions with OR
        cond = (keyword_conditions * ' OR ')
        cond = "NOT(#{cond})" if search_condition.length == 2 && search_condition.last == :not

        conditions << "(#{cond})"
      end
            
      # all keywords must be matched, so join the conditions with AND
      return { :conditions => [conditions * ' AND ', query_params] } 
    end
  end
  
end