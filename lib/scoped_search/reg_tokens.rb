# Regular expression tokens to be used for parsing.
module RegTokens
   
  WORD = '[\w]+'
  SPACE = '[ ]'
  STRING = '["][\w ]+["]'
  OR = 'OR'
  POSSIBLY_NEGATED = '[-]?'
  MONTH = '[\d]{1,2}'
  DAY = '[\d]{1,2}'
  FULL_YEAR = '[\d]{4}'

  WordOrWord = "(#{WORD}#{SPACE}#{OR}#{SPACE}#{WORD})"
  WordOrString = "(#{WORD}#{SPACE}#{OR}#{SPACE}#{STRING})"
  StringOrWord = "(#{STRING}#{SPACE}#{OR}#{SPACE}#{WORD})"
  StringOrString = "(#{STRING}#{SPACE}#{OR}#{SPACE}#{STRING})"
  PossiblyNegatedWord = "(#{POSSIBLY_NEGATED}#{WORD})"
  PossiblyNegatedString = "(#{POSSIBLY_NEGATED}#{STRING})"
  DateFormatMMDDYYYY = "(#{MONTH}/#{DAY}/#{FULL_YEAR})"  # This would be the same for DD/MM/YYYY
  DateFormatYYYYMMDD = "(#{FULL_YEAR}/#{MONTH}/#{DAY})" 
  DatabaseFormat = "(#{FULL_YEAR}-#{MONTH}-#{DAY})"
end
      
      
      