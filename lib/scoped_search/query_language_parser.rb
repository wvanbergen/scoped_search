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
      pattern = /([-]?[\w]+)|([-]?["][\w ]+["])/ # Wes -Hays "dog man" -"cat woman"
      matches = query.scan(pattern).flatten.compact
      matches.each { |match|
        tokens << :not unless match.index('-').nil?
        # Remove any escaped quotes and any dashes - the dash usually the first character.
        # Remove any additional spaces - more that one.
        tokens << match.gsub(/[-"]/,'').gsub(/[ ]{2,}/, ' ')
      }
      return tokens
    end
  end
end