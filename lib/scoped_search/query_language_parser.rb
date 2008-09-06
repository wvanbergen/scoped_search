module ScopedSearch
  
  class QueryLanguageParser
    
    def parse_query(query = nil)
      return build_conditions_tree(tokenize(query))
    end
    
    def self.parse(query)
      self.new.parse_query(query)
    end
    
    protected
  
    def build_conditions_tree(tokens)
      conditions_tree = []
    
      negate = false
      tokens.each do |item|
        case item
        when :not
          negate = true
        else
          conditions_tree << (negate ? [item, :not] : [item, :like])
          negate = false
        end
      end
      return conditions_tree
    end
  
    def tokenize(query)
      tokens = []
      current_token = ""
      quoted_string_openend = false
    
      query.each_char do |char|
      
        case char
        when /\s/
          if quoted_string_openend
            current_token << char
          elsif current_token.length > 0
            tokens << current_token
            current_token = ""
          end
      
        when '-'
          if quoted_string_openend || current_token.length > 0
            current_token << char
          else
            tokens << :not
          end
        
        when '"'
          if quoted_string_openend
            if current_token.length > 0
              if current_token[-1,1] == "\\"
                current_token[-1] = char
              else
                tokens << current_token
                current_token = ""
                quoted_string_openend = false
              end
            else 
              quoted_string_openend = false
            end

          else
            quoted_string_openend = true
          end
        
        else
          current_token << char
        end
      
      end
      tokens << current_token if current_token.length > 0
      return tokens
    end
  end
end