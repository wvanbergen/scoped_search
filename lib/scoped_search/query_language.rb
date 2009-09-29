module ScopedSearch::QueryLanguage

  require 'scoped_search/query_language/ast'
  require 'scoped_search/query_language/tokenizer'
  require 'scoped_search/query_language/parser'

  # The Compiler class can compile a query string into an Abstract Syntax Tree,
  # which in turn is used to build the SQL query.
  #
  # This class inclused the Tokenizer module to transform the query stream into
  # a stream of tokens, and includes the Parser module that will transform the
  # stream of tokens into an Abstract Syntax Tree (AST).
  class Compiler

    include Tokenizer
    include Parser
    include Enumerable

    def initialize(str) # :nodoc:
      @str = str
    end

    # Parser a query string to return an abstract syntax tree.
    def self.parse(str)
      compiler = self.new(str)
      compiler.parse
    end

    # Tokenizes a query string to return a stream of tokens.
    def self.tokenize(str)
      compiler = self.new(str)
      compiler.tokenize
    end

  end
end


