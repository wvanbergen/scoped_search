require "#{File.dirname(__FILE__)}/../spec_helper"

describe ScopedSearch::QueryLanguage::Parser do

  it "should create a 1-node tree for a single keyword" do
    'single'.should parse_to('single')
  end

  it "should create a two-item AND construct for two keywords" do
    'double_1 double_2'.should parse_to([:and, 'double_1', 'double_2'])
  end

  it "should create a three-item AND construct for three keywords" do
    'triplet_1 triplet_2 triplet_3'.should parse_to([:and, 'triplet_1', 'triplet_2', 'triplet_3'])
  end

  it "should create a four-item AND construct by simplifying AND constructs" do
    '1 (2 (3 4))'.should parse_to([:and, '1', '2', '3', '4'])
  end

  it "should create an OR construct" do
    'some OR simple OR keywords'.should parse_to([:or, 'some', 'simple', 'keywords'])
  end

  it "should nest an OR as second argument of the AND construct" do
    'some simple OR keywords'.should parse_to([:and, 'some', [:or, 'simple', 'keywords']])
  end

  it "should nest an OR as first argument of an AND construct" do
    'some OR simple keywords'.should parse_to([:and, [:or, 'some', 'simple'], 'keywords'])
  end

  it "should handle parenthesis as AND block, placed in an OR block" do
    'some OR (simple keywords)'.should parse_to([:or, 'some', [:and, 'simple', 'keywords']])
  end

  it "should handle parenthesis as OR block in an AND block" do
    '(some OR simple) keywords'.should parse_to([:and, [:or, 'some', 'simple'], 'keywords'])
  end

  it "should create a block for the NOT keyword" do
    'not easy'.should parse_to([:not, 'easy'])
  end

  it "should create a nsted NOT block" do
    'not !easy'.should parse_to([:not, [:not, 'easy']])
  end

  it "should create a block for the NOT keyword in an AND block" do
    'hard !easy'.should parse_to([:and, 'hard', [:not, 'easy']])
  end

  it "should create a block for the NOT keyword in an OR block" do
    'hard || !easy'.should parse_to([:or, 'hard', [:not, 'easy']])
  end

  it "should create a block for the NOT keyword in an OR block" do
    '!easy OR !hard'.should parse_to([:or, [:not, 'easy'], [:not, 'hard']])
  end

  it "should nest the NOT blocks correctly according to parantheses" do
    '!(easy OR !hard)'.should parse_to([:not, [:or, 'easy', [:not, 'hard']]])
  end

  it "should create OR blocks in an AND block" do
    '(a|b)(b|c)'.should parse_to([:and, [:or, 'a', 'b'], [:or, 'b', 'c']])
  end

  it "should create OR blocks in an explicit AND block" do
    '(a|b)&(b|c)'.should parse_to([:and, [:or, 'a', 'b'], [:or, 'b', 'c']])
  end

  it "should ignore a comma under normal circumstances" do
    'a,b'.should parse_to([:and, 'a', 'b'])
  end

  it "should correctly parse an infix comparison" do
    'a>b'.should parse_to([:gt, 'a', 'b'])
  end

  it "should correctly parse a prefix comparison" do
    '<b'.should parse_to([:lt, 'b'])
  end

  it "should create a comparison in an AND block because of the comma delimiter" do
    'a, < b'.should parse_to([:and, 'a', [:lt, 'b']])
  end

  it "should create a infix and prefix comparison in an AND block because of parentheses" do
    '(a = b) >c'.should parse_to([:and, [:eq, 'a', 'b'], [:gt, 'c']])
  end

  it "should create a infix and prefix comparison in an AND block because of a comma" do
    'a = b, >c'.should parse_to([:and, [:eq, 'a', 'b'], [:gt, 'c']])
  end

  it "should create a infix and prefix comparison in an AND block because of first come first serve" do
    'a = b > c'.should parse_to([:and, [:eq, 'a', 'b'], [:gt, 'c']])
  end

  it "should parse a null? keyword" do
    'set? a b null? c'.should parse_to([:and, [:notnull, 'a'], 'b', [:null, 'c']])
  end
end
