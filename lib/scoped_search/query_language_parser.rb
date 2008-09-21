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
            if /^.+[ ]OR[ ].+$/ =~ item
              conditions_tree << [item, :or]
            elsif /^#{RegTokens::DateFormatMMDDYYYY}$/ =~ item or
                  /^#{RegTokens::DateFormatYYYYMMDD}$/ =~ item or
                  /^#{RegTokens::DatabaseFormat}$/ =~ item
              conditions_tree << [item, :as_of_date]
            else
              conditions_tree << (negate ? [item, :not] : [item, :like])
              negate = false
            end
        end
      end
      
      return conditions_tree
    end
    
    def tokenize(query)
      pattern = [RegTokens::DateFormatMMDDYYYY,
                 RegTokens::DateFormatYYYYMMDD,
                 RegTokens::DatabaseFormat,
                 RegTokens::WordOrWord,
                 RegTokens::WordOrString,
                 RegTokens::StringOrWord,
                 RegTokens::StringOrString,
                 RegTokens::PossiblyNegatedWord,
                 RegTokens::PossiblyNegatedString]               
      pattern = Regexp.new(pattern.join('|'))
      
      tokens = []
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