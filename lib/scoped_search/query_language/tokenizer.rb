# The Tokenizer module adds methods to the query language compiler that transforms a query string
# into a stream of tokens, which are more appropriate for parsing a query string.
module ScopedSearch::QueryLanguage::Tokenizer

  # All keywords that the language supports
  KEYWORDS = { 'and' => :and, 'or' => :or, 'not' => :not, 'set?' => :notnull, 'has' => :notnull, 'null?' => :null,  'before' => :lt, 'after' => :gt, 'at' => :eq }

  # Every operator the language supports.
  OPERATORS = { '&' => :and, '|' => :or, '&&' => :and, '||' => :or, '-'=> :not, '!' => :not, '~' => :like, '!~' => :unlike,
      '=' => :eq, '==' => :eq, '!=' => :ne, '<>' => :ne, '>' => :gt, '<' => :lt, '>=' => :gte, '<=' => :lte }

  # Tokenizes the string and returns the result as an array of tokens.
  def tokenize
    @current_char_pos = -1
    to_a
  end

  # Returns the current character of the string
  def current_char
    @current_char
  end

  # Returns a following character of the string (by default, the next
  # character), without updating the position pointer.
  def peek_char(amount = 1)
    @str[@current_char_pos + amount, 1]
  end

  # Returns the next character of the string, and moves the position
  # pointer one step forward
  def next_char
    @current_char_pos += 1
    @current_char = @str[@current_char_pos, 1]
  end

  # Tokenizes the string by iterating over the characters.
  def each_token(&block)
    while next_char
      case current_char
      when /^\s?$/; # ignore
      when '(';  yield(:lparen)
      when ')';  yield(:rparen)
      when ',';  yield(:comma)
      when /\&|\||=|<|>|!|~|-/;  tokenize_operator(&block)
      when '"';                  tokenize_quoted_keyword(&block)
      else;                      tokenize_keyword(&block)
      end
    end
  end

  # Tokenizes an operator that occurs in the OPERATORS hash
  def tokenize_operator(&block)
    operator = current_char
    operator << next_char if OPERATORS.has_key?(operator + peek_char)
    yield(OPERATORS[operator])
  end

  # Tokenizes a keyword, and converts it to a Symbol if it is recognized as a
  # reserved language keyword (the KEYWORDS array).
  def tokenize_keyword(&block)
    keyword = current_char
    keyword << next_char while /[^=~<>\s\&\|\)\(,]/ =~ peek_char
    KEYWORDS.has_key?(keyword.downcase) ? yield(KEYWORDS[keyword.downcase]) : yield(keyword)
  end

  # Tokenizes a keyword that is quoted using double quotes. Allows escaping
  # of double quote characters by backslashes.
  def tokenize_quoted_keyword(&block)
    keyword = ""
    until next_char.nil? || current_char == '"'
      keyword << (current_char == "\\" ? next_char : current_char)
    end
    yield(keyword)
  end

  alias :each :each_token

end
