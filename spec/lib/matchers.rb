class ParseTo
  
  def initialize(tree)
    @expected_tree = tree
  end
  
  def matches?(model)
    @model = model
    @parsed_tree = ScopedSearch::QueryLanguage::Compiler.parse(@model).to_a 
    return @parsed_tree == @expected_tree
  end
  
  def description
    "be parsed to #{@parsed_tree.inspect}"
  end
  
  def failure_message
    "#{@expected_tree.inspect}, but found #{@parsed_tree.inspect}"
  end
  
  def negative_failure_message
    " expected not to be parsed to #{@expected_tree.inspect}"
  end  
  
end

class TokenizeTo
  
  def initialize(tokens)
    @expected_tokes = tokens
  end
  
  def matches?(string)
    @string = string
    @parsed_tokens = ScopedSearch::QueryLanguage::Compiler.tokenize(@string)
    return @parsed_tokens == @expected_tokes
  end
  
  def description
    "#{@string} expected to tokenized to #{@expected_tokes.inspect}"
  end
  
  def failure_message
    "#{@expected_tokes.inspect} expected, but found #{@parsed_tokens.inspect}"
  end
  
  def negative_failure_message
    " expected not to be tokenized to #{@expected_tree.inspect}"
  end  
  
end


def parse_to(tree)
  ParseTo.new(tree)
end

def tokenize_to(*tokens)
  TokenizeTo.new(tokens)
end