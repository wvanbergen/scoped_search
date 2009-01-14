module ScopedSearch
  
  class QueryConditionsBuilder

    # Builds the query string by calling the build method on a new instances of QueryConditionsBuilder.
    def self.build_query(search_conditions, query_fields)
      self.new.build(search_conditions, query_fields)
    end

    # Initializes the default class variables.
    def initialize
      @query_fields = nil 
      @query_params = {}
      
      @sql_like = 'LIKE'
      
      if ActiveRecord::Base.connected? and ActiveRecord::Base.connection.adapter_name.downcase == 'postgresql'
        @sql_like = 'ILIKE'
      end
    end 


    # Build the query based on the search conditions and the fields to query.
    # 
    # Hash query_options : A hash of fields and field types.
    #
    # Example: 
    #
    #   search_conditions = [["Wes", :like], ["Hays", :not], ["Hello World", :like], ["Goodnight Moon", :not], 
    #                       ["Bob OR Wes", :or], ["Happy cow OR Sad Frog", :or], ["Man made OR Dogs", :or], 
    #                       ["Cows OR Frog Toys", :or], ['9/28/1980, :datetime]]
    #   query_fields = {:first_name => :string, :created_at => :datetime}
    #
    # Exceptons : 
    #   1) If search_conditions is not an array
    #   2) If query_fields is not a Hash    
    def build(search_conditions, query_fields) 
      raise 'search_conditions must be a hash' unless search_conditions.class.to_s == 'Array'
      raise 'query_fields must be a hash' unless query_fields.class.to_s == 'Hash'
      @query_fields = query_fields

      conditions = []
 
      search_conditions.each_with_index do |search_condition, index|
        keyword_name = "keyword_#{index}".to_sym
        conditions << case search_condition.last
                        # Still thinking about this one
                        # when :integer: integer_conditions(keyword_name, search_condition.first)
          
                        when :like: like_condition(keyword_name, search_condition.first)
                        when :not: not_like_condition(keyword_name, search_condition.first)
            
                        when :or: or_condition(keyword_name, search_condition.first)
      
                        when :less_than_date: less_than_date(keyword_name, search_condition.first)      
                        when :less_than_or_equal_to_date: less_than_or_equal_to_date(keyword_name, search_condition.first)   
                        when :as_of_date: as_of_date(keyword_name, search_condition.first)      
                        when :greater_than_date: greater_than_date(keyword_name, search_condition.first) 
                        when :greater_than_or_equal_to_date: greater_than_or_equal_to_date(keyword_name, search_condition.first)   
                        
                        when :between_dates: between_dates(keyword_name, search_condition.first)                                                        
                      end          
      end

      [conditions.compact.join(' AND '), @query_params] 
    end    
    
    
    private 
    
    # def integer_condition(keyword_name, value)
      # Still thinking about this one
    # end    
    
    def like_condition(keyword_name, value)
      @query_params[keyword_name] = "%#{value}%"
      retVal = []
      @query_fields.each do |field, field_type|  #|key,value| 
        if field_type == :string or field_type == :text
          retVal << "#{field} #{@sql_like} :#{keyword_name.to_s}"
        end
      end
      "(#{retVal.join(' OR ')})"
    end
    
    def not_like_condition(keyword_name, value)
      @query_params[keyword_name] = "%#{value}%"
      retVal = []
      @query_fields.each do |field, field_type|  #|key,value| 
        if field_type == :string or field_type == :text
          retVal << "(#{field} NOT #{@sql_like} :#{keyword_name.to_s} OR #{field} IS NULL)"
        end
      end
      "(#{retVal.join(' AND ')})"
    end
    
    def or_condition(keyword_name, value)
      retVal = []
      word1, word2 = value.split(' OR ')
      keyword_name_a = "#{keyword_name.to_s}a".to_sym
      keyword_name_b = "#{keyword_name.to_s}b".to_sym
      @query_params[keyword_name_a] = "%#{word1}%"
      @query_params[keyword_name_b] = "%#{word2}%"      
      @query_fields.each do |field, field_type|  #|key,value| 
        if field_type == :string or field_type == :text
          retVal << "(#{field} #{@sql_like} :#{keyword_name_a.to_s} OR #{field} #{@sql_like} :#{keyword_name_b.to_s})"
        end
      end 
      "(#{retVal.join(' OR ')})"     
    end
    
    def less_than_date(keyword_name, value)
      helper_date_operation('<', keyword_name, value)     
    end
    
    def less_than_or_equal_to_date(keyword_name, value)
      helper_date_operation('<=', keyword_name, value)     
    end    
    
    def as_of_date(keyword_name, value)
      retVal = []
      begin
        dt = Date.parse(value) # This will throw an exception if it is not valid
        @query_params[keyword_name] = dt.to_s
        @query_fields.each do |field, field_type|  #|key,value| 
          if field_type == :date or field_type == :datetime or field_type == :timestamp
            retVal << "#{field} = :#{keyword_name.to_s}"
          end
        end
      rescue
        # do not search on any date columns since the date is invalid
        retVal = [] # Reset just in case
      end
      
      # Search the text fields for the date as well as it could be in text.
      # Also still search on the text columns for an invalid date as it could
      # have a different meaning.
      found_text_fields_to_search = false
      keyword_name_b = "#{keyword_name}b".to_sym      
      @query_fields.each do |field, field_type|  #|key,value| 
        if field_type == :string or field_type == :text
          found_text_fields_to_search = true
          retVal << "#{field} #{@sql_like} :#{keyword_name_b.to_s}"
        end
      end
      if found_text_fields_to_search
        @query_params[keyword_name_b] = "%#{value}%"
      end

      retVal.empty? ? '' : "(#{retVal.join(' OR ')})"      
    end
    
    def greater_than_date(keyword_name, value)
      helper_date_operation('>', keyword_name, value)
    end
    
    def greater_than_or_equal_to_date(keyword_name, value)
      helper_date_operation('>=', keyword_name, value)
    end    
    
    def between_dates(keyword_name, value)
      date1, date2 = value.split(' TO ')      
      dt1 = Date.parse(date1) # This will throw an exception if it is not valid
      dt2 = Date.parse(date2) # This will throw an exception if it is not valid
      keyword_name_a = "#{keyword_name.to_s}a".to_sym
      keyword_name_b = "#{keyword_name.to_s}b".to_sym 
      @query_params[keyword_name_a] = dt1.to_s
      @query_params[keyword_name_b] = dt2.to_s           

      retVal = []
      @query_fields.each do |field, field_type|  #|key,value| 
        if field_type == :date or field_type == :datetime or field_type == :timestamp
          retVal << "(#{field} BETWEEN :#{keyword_name_a.to_s} AND :#{keyword_name_b.to_s})"
        end
      end
      "(#{retVal.join(' OR ')})"  
    rescue
      # The date is not valid so just ignore it
      return nil      
    end  
    

    def helper_date_operation(operator, keyword_name, value)
      dt = Date.parse(value) # This will throw an exception if it is not valid
      @query_params[keyword_name] = dt.to_s
      retVal = []
      @query_fields.each do |field, field_type|  #|key,value| 
        if field_type == :date or field_type == :datetime or field_type == :timestamp
          retVal << "#{field} #{operator} :#{keyword_name.to_s}"
        end
      end
      "(#{retVal.join(' OR ')})"  
    rescue
      # The date is not valid so just ignore it
      return nil      
    end
  end
end
