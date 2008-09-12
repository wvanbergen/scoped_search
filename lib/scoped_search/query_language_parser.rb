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
            else
              conditions_tree << (negate ? [item, :not] : [item, :like])
              negate = false
            end
        end
      end
      return conditions_tree
    end
  
    # **Patterns**
    # Each pattern is sperated by a "|".  With regular expressions the order of the expression does matter.
    #
    # ([\w]+[ ]OR[ ][\w]+)
    # ([\w]+[ ]OR[ ]["][\w ]+["])
    # (["][\w ]+["][ ]OR[ ][\w]+)
    # (["][\w ]+["][ ]OR[ ]["][\w ]+["])
    #   Any two combinations of letters, numbers and underscores that are seperated by " OR " (a single space must 
    #   be on each side of the "OR"). 
    #   THESE COULD BE COMBINED BUT BECAUSE OF THE WAY PARSING WORKS THIS IS NOT DONE ON PURPOSE!!
    #
    # ([-]?[\w]+) 
    #   Any combination of letters, numbers and underscores that may or may not have a dash in front.
    # 
    # ([-]?["][\w ]+["])
    #   Any combination of letters, numbers, underscores and spaces within double quotes that may or may not have a dash in front.
    def tokenize(query)
      pattern = ['([\w]+[ ]OR[ ][\w]+)',
                 '([\w]+[ ]OR[ ]["][\w ]+["])',
                 '(["][\w ]+["][ ]OR[ ][\w]+)',
                 '(["][\w ]+["][ ]OR[ ]["][\w ]+["])',
                 '([-]?[\w]+)',
                 '([-]?["][\w ]+["])']
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