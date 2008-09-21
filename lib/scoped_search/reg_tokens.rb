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
  LESS_THAN = '[<][ ]'
  GREATER_THAN = '[>][ ]'
  LESS_THAN_OR_EQUAL_TO = '[<][=][ ]'
  GREATER_THAN_OR_EQUAL_TO = '[>][=][ ]'
  TO = 'TO'

  WordOrWord = "(#{WORD}#{SPACE}#{OR}#{SPACE}#{WORD})"
  WordOrString = "(#{WORD}#{SPACE}#{OR}#{SPACE}#{STRING})"
  StringOrWord = "(#{STRING}#{SPACE}#{OR}#{SPACE}#{WORD})"
  StringOrString = "(#{STRING}#{SPACE}#{OR}#{SPACE}#{STRING})"
  PossiblyNegatedWord = "(#{POSSIBLY_NEGATED}#{WORD})"
  PossiblyNegatedString = "(#{POSSIBLY_NEGATED}#{STRING})"
  
  DateFormatMMDDYYYY = "(#{MONTH}/#{DAY}/#{FULL_YEAR})"  # This would be the same for DD/MM/YYYY
  DateFormatYYYYMMDD = "(#{FULL_YEAR}/#{MONTH}/#{DAY})" 
  DatabaseFormat = "(#{FULL_YEAR}-#{MONTH}-#{DAY})"
  
  LessThanDateFormatMMDDYYYY = "(#{LESS_THAN}#{MONTH}/#{DAY}/#{FULL_YEAR})" 
  LessThanDateFormatYYYYMMDD = "(#{LESS_THAN}#{FULL_YEAR}/#{MONTH}/#{DAY})" 
  LessThanDatabaseFormat = "(#{LESS_THAN}#{FULL_YEAR}-#{MONTH}-#{DAY})"  
  
  GreaterThanDateFormatMMDDYYYY = "(#{GREATER_THAN}#{MONTH}/#{DAY}/#{FULL_YEAR})"  
  GreaterThanDateFormatYYYYMMDD = "(#{GREATER_THAN}#{FULL_YEAR}/#{MONTH}/#{DAY})" 
  GreaterThanDatabaseFormat = "(#{GREATER_THAN}#{FULL_YEAR}-#{MONTH}-#{DAY})"  
  
  LessThanOrEqualToDateFormatMMDDYYYY = "(#{LESS_THAN_OR_EQUAL_TO}#{MONTH}/#{DAY}/#{FULL_YEAR})" 
  LessThanOrEqualToDateFormatYYYYMMDD = "(#{LESS_THAN_OR_EQUAL_TO}#{FULL_YEAR}/#{MONTH}/#{DAY})" 
  LessThanOrEqualToDatabaseFormat = "(#{LESS_THAN_OR_EQUAL_TO}#{FULL_YEAR}-#{MONTH}-#{DAY})"  
  
  GreaterThanOrEqualToDateFormatMMDDYYYY = "(#{GREATER_THAN_OR_EQUAL_TO}#{MONTH}/#{DAY}/#{FULL_YEAR})"  
  GreaterThanOrEqualToDateFormatYYYYMMDD = "(#{GREATER_THAN_OR_EQUAL_TO}#{FULL_YEAR}/#{MONTH}/#{DAY})" 
  GreaterThanOrEqualToDatabaseFormat = "(#{GREATER_THAN_OR_EQUAL_TO}#{FULL_YEAR}-#{MONTH}-#{DAY})"  
  
  BetweenDateFormatMMDDYYYY = "(#{MONTH}/#{DAY}/#{FULL_YEAR}#{SPACE}#{TO}#{SPACE}#{MONTH}/#{DAY}/#{FULL_YEAR})"
  BetweenDateFormatYYYYMMDD = "(#{FULL_YEAR}/#{MONTH}/#{DAY}#{SPACE}#{TO}#{SPACE}#{FULL_YEAR}/#{MONTH}/#{DAY})" 
  BetweenDatabaseFormat = "(#{FULL_YEAR}-#{MONTH}-#{DAY}#{SPACE}#{TO}#{SPACE}#{FULL_YEAR}-#{MONTH}-#{DAY})"
end
      
      
      