# Regular expression tokens to be used for parsing.
module RegTokens
   
  WORD = '[\w]+'
  SPACE = '[ ]'
  STRING = '["][\w ]+["]'
  OR = 'OR'
  POSSIBLY_NEGATED = '[-]?'

  WordOrWord = "(#{WORD}#{SPACE}#{OR}#{SPACE}#{WORD})"
  WordOrString = "(#{WORD}#{SPACE}#{OR}#{SPACE}#{STRING})"
  StringOrWord = "(#{STRING}#{SPACE}#{OR}#{SPACE}#{WORD})"
  StringOrString = "(#{STRING}#{SPACE}#{OR}#{SPACE}#{STRING})"
  PossiblyNegatedWord = "(#{POSSIBLY_NEGATED}#{WORD})"
  PossiblyNegatedString = "(#{POSSIBLY_NEGATED}#{STRING})"
end
      