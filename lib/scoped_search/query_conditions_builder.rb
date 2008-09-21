module ScopedSearch
  
  class QueryConditionsBuilder

    # Build the query
    def self.build_query(search_conditions, query_fields)
      self.new.build(search_conditions, query_fields)
    end

    def initialize
      @query_fields = nil 
      @query_params = {}
    end 


    # Build the query
    # 
    # Hash query_options : A hash of fields and field types.
    #
    # Exampe: 
    # search_conditions = [["Wes", :like], ["Hays", :not], ["Hello World", :like], ["Goodnight Moon", :not], 
    #                     ["Bob OR Wes", :or], ["Happy cow OR Sad Frog", :or], ["Man made OR Dogs", :or], 
    #                     ["Cows OR Frog Toys", :or], ['9/28/1980, :datetime]]
    # query_fields = {:first_name => :string, :created_at => :datetime}
    # 
    # Exceptons : 
    #   1) If urlParams does not contain a :controller key.      
    def build(search_conditions, query_fields) 
      raise 'search_conditions must be a hash' unless search_conditions.class.to_s == 'Array'
      raise 'query_fields must be a hash' unless query_fields.class.to_s == 'Hash'
      @query_fields = query_fields

      conditions = []
      
      search_conditions.each_with_index do |search_condition, index|
        keyword_name = "keyword_#{index}".to_sym
        conditions << case search_condition.last
                        #when :integer: integer_conditions(keyword_name, search_condition.first)
          
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
    # end    
    
    def like_condition(keyword_name, value)
      @query_params[keyword_name] = "%#{value}%"
      retVal = []
      @query_fields.each do |field, field_type|  #|key,value| 
        if field_type == :string or field_type == :text
          retVal << "#{field} LIKE :#{keyword_name.to_s}"
        end
      end
      "(#{retVal.join(' OR ')})"
    end
    
    def not_like_condition(keyword_name, value)
      @query_params[keyword_name] = "%#{value}%"
      retVal = []
      @query_fields.each do |field, field_type|  #|key,value| 
        if field_type == :string or field_type == :text
          retVal << "(#{field} NOT LIKE :#{keyword_name.to_s} OR #{field} IS NULL)"
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
          retVal << "(#{field} LIKE :#{keyword_name_a.to_s} OR #{field} LIKE :#{keyword_name_b.to_s})"
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
      helper_date_operation('=', keyword_name, value)
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
