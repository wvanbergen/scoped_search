module ScopedSearch::QueryLanguage

  require 'scoped_search/query_language/ast'
  require 'scoped_search/query_language/tokenizer'
  require 'scoped_search/query_language/parser'

  class Compiler 

    include Tokenizer
    include Parser
    include Enumerable
    
    def initialize(str)
      @str = str
    end
    
    def self.parse(str)
      compiler = self.new(str)
      compiler.parse
    end
    
    def self.tokenize(str)
      compiler = self.new(str)
      compiler.tokenize
    end
        
  end
end


