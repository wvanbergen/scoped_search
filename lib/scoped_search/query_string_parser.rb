module ScopedSearch::QueryStringParser
  
  def to_search_query
    items = lex_for_query_string_parsing
    search_conditions = []
    
    negate = false
    items.each do |item|
      case item
      when :not
        negate = true
      else
        search_conditions << (negate ? [item, :not] : [item])
        negate = false
      end
    end
    return search_conditions
  end
  
  def lex_for_query_string_parsing
    terms = []
    current_term = ""
    quoted_string_openend = false
    
    self.each_char do |char|
      
      case char
      when /\s/
        if quoted_string_openend
          current_term << char
        elsif current_term.length > 0
          terms << current_term
          current_term = ""
        end
      
      when '-'
        if quoted_string_openend || current_term.length > 0
          current_term << char
        else
          terms << :not
        end
        
      when '"'
        if quoted_string_openend
          if current_term.length > 0
            if current_term[-1,1] == "\\"
              current_term[-1] = char
            else
              terms << current_term
              current_term = ""
              quoted_string_openend = false
            end
          else 
            quoted_string_openend = false
          end

        else
          quoted_string_openend = true
        end
        
      else
        current_term << char
      end
      
    end
    terms << current_term if current_term.length > 0
    return terms
  end
  
end