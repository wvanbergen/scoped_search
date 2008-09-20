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
                        when :integer: integer_conditions(keyword_name, search_condition.first)
          
                        when :like: like_condition(keyword_name, search_condition.first)
                        when :not: not_like_condition(keyword_name, search_condition.first)
            
                        when :or: or_condition(keyword_name, search_condition.first)
      
                        when :before_date: before_date(keyword_name, search_condition.first)
                        when :before_datetime: before_datetime(keyword_name, search_condition.first)
      
                        when :as_of_date: as_of_date(keyword_name, search_condition.first)
                        when :as_of_datetime: as_of_date(keyword_name, search_condition.first)
      
                        when :after_date: after_date(keyword_name, search_condition.first)
                        when :after_datetime: after_datetime(keyword_name, search_condition.first)        
            
                        when :between_dates: as_of_date(keyword_name, search_condition.first)
                        when :between_datetimes: as_of_datetime(keyword_name, search_condition.first)   
                                                           
                      end
          
      end

      [conditions.join(' AND '), @query_params] 
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
    
    # def before_date(keyword_name, value)
    # end
    # alias :bafore_datetime :before_date
    # 
    # def as_of_date(keyword_name, value)
    # end
    # alias :as_of_datetime :as_of_date 
    # 
    # def after_date(keyword_name, value)
    # end
    # alias :after_datetime :after_date
    # 
    # def between_dates(keyword_name, value)
    # end
    # alias :between_datetimes :between_dates    
  end
end

#  def other_method
# 
#    conditions = []
#    query_params = {}
#  
#    QueryLanguageParser.parse(search_string).each_with_index do |search_condition, index|
#      keyword_name = "keyword_#{index}".to_sym
#      query_params[keyword_name] = "%#{search_condition.first}%"
# 
#   
#     # a keyword may be found in any of the provided fields, so join the conitions with OR
#     if search_condition.length == 2 && search_condition.last == :not
#       keyword_conditions = self.scoped_search_fields.map do |field| 
#         field_name = connection.quote_table_name(table_name) + "." + connection.quote_column_name(field)
#         "(#{field_name} NOT LIKE :#{keyword_name.to_s} OR #{field_name} IS NULL)"
#       end
#       conditions << "(#{keyword_conditions.join(' AND ')})" 
#     elsif search_condition.length == 2 && search_condition.last == :or
#       word1, word2 = query_params[keyword_name].split(' OR ')
#       
#       query_params.delete(keyword_name)
#       keyword_name_a = "#{keyword_name.to_s}a".to_sym
#       keyword_name_b = "#{keyword_name.to_s}b".to_sym
#       query_params[keyword_name_a] = word1
#       query_params[keyword_name_b] = word2
#       
#       keyword_conditions = self.scoped_search_fields.map do |field| 
#         field_name = connection.quote_table_name(table_name) + "." + connection.quote_column_name(field)
#         "(#{field_name} LIKE :#{keyword_name_a.to_s} OR #{field_name} LIKE :#{keyword_name_b.to_s})"
#       end
#       conditions << "(#{keyword_conditions.join(' OR ')})"            
#     else
#       keyword_conditions = self.scoped_search_fields.map do |field| 
#         field_name = connection.quote_table_name(table_name) + "." + connection.quote_column_name(field)
#         "#{field_name} LIKE :#{keyword_name.to_s}"
#       end
#       conditions << "(#{keyword_conditions.join(' OR ')})"
#     end       
#   end
# end
