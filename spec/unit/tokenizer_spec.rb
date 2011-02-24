require "#{File.dirname(__FILE__)}/../spec_helper"

describe ScopedSearch::QueryLanguage::Tokenizer do

  it "should create tokens for strings" do
    'some simple keywords'.should tokenize_to('some', 'simple', 'keywords')
  end

  it "should ignore excessive whitespace" do
    "  with\twhitespace   \n".should tokenize_to('with', 'whitespace')
  end

  it "should leave quoted strings intact" do
    '"quoted string"'.should tokenize_to("quoted string")
  end

  it "should allow escaping quotes in quoted strings using a backslash" do
    '"quoted \"string"'.should tokenize_to('quoted "string')
  end

  it "should allow escaping the escape charachter" do
    '"quoted \\\\string"'.should tokenize_to('quoted \\string')
  end

  it "should handle unclosed quoted string gracefully" do
    '"quoted string'.should tokenize_to("quoted string")
  end

  it "should tokenize multiple quoted strings" do
    '"quoted string"   "another"  '.should tokenize_to("quoted string", 'another')
  end

  it "should tokenize multiple quoted strings without separating whitespace" do
    '"quoted string""another"'.should tokenize_to("quoted string", 'another')
  end

  it "should tokenize combinations of quoted strings and unquoted strings" do
    '"quoted string" another'.should tokenize_to("quoted string", 'another')
  end

  it "should tokenize combinations of quoted strings and unquoted strings without whitespace" do
    '"quoted string"another'.should tokenize_to("quoted string", 'another')
  end

  it "should allow quotes in the middle of a normal string" do
    'a"b'.should tokenize_to('a"b')
  end

  it "should parse keyword characters" do
    'a | -("b""c") & d'.should tokenize_to('a', :or, :not, :lparen, 'b', 'c', :rparen, :and, 'd')
  end

  it "should tokenize null operators" do
    'set? a null? b'.should tokenize_to(:notnull, 'a', :null, 'b')
  end

  it "should parse double keyword characters" do
    'a || b'.should tokenize_to('a', :or, 'b')
  end

  it "should parse double keyword characters with whitespace as separate tokens" do
    'a | | b'.should tokenize_to('a', :or, :or, 'b')
  end

  it "should parse keyword strings" do
    "a and b".should tokenize_to('a', :and, 'b')
  end

  it "should parse keyword strings with different capitalizations" do
    "a AnD b".should tokenize_to('a', :and, 'b')
  end

  it "should not parse keyword strings when quoted" do
    'a "and" b'.should tokenize_to('a', 'and', 'b')
  end

  it "should not parse a negation character within a string as NOT keyword" do
    'a-b'.should tokenize_to('a-b')
  end

  it "should parse an AND operator within a string as separate token" do
    'a&b'.should tokenize_to('a', :and, 'b')
  end

  it "should parse an OR operator within a string as separate token" do
    'a||b'.should tokenize_to('a', :or, 'b')
  end

  it "should parse an equals operator within a string as separate token" do
    'a=b'.should tokenize_to('a', :eq, 'b')
  end

  it "should not parse an operator within a string as separate token when quoted" do
    '"a=b"'.should tokenize_to('a=b')
  end

end
