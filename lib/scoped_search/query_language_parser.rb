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
            elsif /^#{RegTokens::BetweenDateFormatMMDDYYYY}$/ =~ item or
                  /^#{RegTokens::BetweenDateFormatYYYYMMDD}$/ =~ item or
                  /^#{RegTokens::BetweenDatabaseFormat}$/ =~ item
              conditions_tree << [item, :between_dates]              
            elsif /^#{RegTokens::GreaterThanOrEqualToDateFormatMMDDYYYY}$/ =~ item or
                  /^#{RegTokens::GreaterThanOrEqualToDateFormatYYYYMMDD}$/ =~ item or
                  /^#{RegTokens::GreaterThanOrEqualToDatabaseFormat}$/ =~ item
              conditions_tree << [item, :greater_than_or_equal_to_date] 
            elsif /^#{RegTokens::LessThanOrEqualToDateFormatMMDDYYYY}$/ =~ item or
                  /^#{RegTokens::LessThanOrEqualToDateFormatYYYYMMDD}$/ =~ item or
                  /^#{RegTokens::LessThanOrEqualToDatabaseFormat}$/ =~ item
              conditions_tree << [item, :less_than_or_equal_to_date]              
            elsif /^#{RegTokens::GreaterThanDateFormatMMDDYYYY}$/ =~ item or
                  /^#{RegTokens::GreaterThanDateFormatYYYYMMDD}$/ =~ item or
                  /^#{RegTokens::GreaterThanDatabaseFormat}$/ =~ item
              conditions_tree << [item, :greater_than_date] 
            elsif /^#{RegTokens::LessThanDateFormatMMDDYYYY}$/ =~ item or
                  /^#{RegTokens::LessThanDateFormatYYYYMMDD}$/ =~ item or
                  /^#{RegTokens::LessThanDatabaseFormat}$/ =~ item
              conditions_tree << [item, :less_than_date]                           
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
      pattern = [RegTokens::BetweenDateFormatMMDDYYYY,
                 RegTokens::BetweenDateFormatYYYYMMDD,
                 RegTokens::BetweenDatabaseFormat,
                 RegTokens::GreaterThanOrEqualToDateFormatMMDDYYYY,
                 RegTokens::GreaterThanOrEqualToDateFormatYYYYMMDD,
                 RegTokens::GreaterThanOrEqualToDatabaseFormat,
                 RegTokens::LessThanOrEqualToDateFormatMMDDYYYY,
                 RegTokens::LessThanOrEqualToDateFormatYYYYMMDD,
                 RegTokens::LessThanOrEqualToDatabaseFormat,
                 RegTokens::GreaterThanDateFormatMMDDYYYY,
                 RegTokens::GreaterThanDateFormatYYYYMMDD,
                 RegTokens::GreaterThanDatabaseFormat,
                 RegTokens::LessThanDateFormatMMDDYYYY,
                 RegTokens::LessThanDateFormatYYYYMMDD,
                 RegTokens::LessThanDatabaseFormat,
                 RegTokens::DateFormatMMDDYYYY,
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
        tokens << :not if match.index('-') == 0
        # Remove any escaped quotes
        # Remove any dashes preceded by a space or at the beginning of a token
        # Remove any additional spaces - more that one.
        cleaned_token = match.gsub(/"/,'').gsub(/^-| -/,'').gsub(/[ ]{2,}/, ' ')
        tokens << cleaned_token if cleaned_token.length > 0
      }
      return tokens
    end
  end
end