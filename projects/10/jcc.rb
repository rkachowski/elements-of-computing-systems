#!/usr/bin/env ruby,
require 'nokogiri'
require 'thor'
require 'pry-byebug'


class Jcc < Thor
  option :tokenize_only, type: :boolean, default: false
  desc "compile SOURCE", "compiles file"
  def compile(source)
    raise "File not found" unless File.exists?(source) or Dir.exists?(source)


  end
  default_task :compile
end


class Tokeniser
  @@lexical_terminals = {

      'class' => :keyword,
      'constructor' => :keyword,
      'function' => :keyword,
      'method'=> :keyword,
      'field'=> :keyword,
      'static'=> :keyword,
      'var'=> :keyword,
      'int'=> :keyword,
      'char'=> :keyword,
      'boolean'=> :keyword,
      'void'=> :keyword,
      'true'=> :keyword,
      'false'=> :keyword,
      'null'=> :keyword,
      'this'=> :keyword,
      'let'=> :keyword,
      'do'=> :keyword,
      'if'=> :keyword,
      'else'=> :keyword,
      'while'=> :keyword,
      'return'=> :keyword,
      '{' => :symbol,
      '}' => :symbol,
      '(' => :symbol,
      ')' => :symbol,
      '[' => :symbol,
      ']' => :symbol,
      '.' => :symbol,
      ',' => :symbol,
      ';' => :symbol,
      '+' => :symbol,
      '-' => :symbol,
      '*' => :symbol,
      '/' => :symbol,
      '&' => :symbol,
      '|' => :symbol,
      '<' => :symbol,
      '>' => :symbol,
      '=' => :symbol,
      '~' => :symbol
  }
  def initialize source
    @source = source
  end

  def tokenize
    lines = File.open(@source).each_line.to_a

    #remove comments
    lines.delete_if{ |l| l.match(/^\s*\/\//)}
    lines.map! { |l| l.sub /\/\*\*.*\*\//, '' }

    tokens = lines#.inject([]){|arr,l| arr.concat(l.split(" ")) }
    tokens.map! do |t|
      token = token(t)
      if token
        {t => token }
      else
        #the string represents a combination of tokens, so we'll return an array of each one
        [breakdown_token(t)]
      end
    end

    tokens.flatten!
    tokens.delete_if {|t| t.keys == [""]}
    tokens
  end

  def token str
    result = @@lexical_terminals[str]
    return result if result

    return "stringConstant" if str.match /^"[^\n]*"$/
    return "integerConstant" if str.match(/^\d+$/) and (0..32767).include?(str.to_i)
    return "identifier" if str.match /^[a-zA-Z_]+[\w\d]*$/
    nil
  end

  def breakdown_token str
    tokens = []

    last_token = str.chars.inject("") do |s,c|
      if s.start_with? '"' and not (s.length > 1 and s.end_with?('"'))
        next s+c
      end

      unless token(s+c)
        tokens << s
        c
      else
        s+c
      end
    end

    tokens << last_token
    tokens.delete_if{|c| c =~ /^\s+$/}.map {|t| { t => token(t)} }
  end
end


Jcc.start(ARGV)
