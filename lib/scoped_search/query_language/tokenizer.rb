module ScopedSearch::QueryLanguage::Tokenizer

  KEYWORDS = { 'and' => :and, 'or' => :or, 'not' => :not, 'set?' => :notnull, 'null?' => :null }
  OPERATORS = { '&' => :and, '|' => :or, '&&' => :and, '||' => :or, '-'=> :not, '!' => :not, '~' => :like, '!~' => :unlike,
      '=' => :eq, '==' => :eq, '!=' => :ne, '<>' => :ne, '>' => :gt, '<' => :lt, '>=' => :gte, '<=' => :lte }

  
  def tokenize
    @current_char_pos = -1
    to_a
  end

  def current_char
    @current_char
  end

  def peek_char(amount = 1)
    @str[@current_char_pos + amount, 1]
  end

  def next_char
    @current_char_pos += 1
    @current_char = @str[@current_char_pos, 1]
  end

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

  def tokenize_operator(&block)
    operator = current_char
    operator << next_char if OPERATORS.has_key?(operator + peek_char)
    yield(OPERATORS[operator])
  end

  def tokenize_keyword(&block)
    keyword = current_char
    keyword << next_char while /[^=<>\s\&\|\)\(,]/ =~ peek_char      
    KEYWORDS.has_key?(keyword.downcase) ? yield(KEYWORDS[keyword.downcase]) : yield(keyword)
  end

  def tokenize_quoted_keyword(&block)
    keyword = ""
    until next_char.nil? || current_char == '"'
      keyword << (current_char == "\\" ? next_char : current_char)
    end
    yield(keyword)      
  end

  alias :each :each_token
  
end