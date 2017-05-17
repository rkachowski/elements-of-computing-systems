#!/usr/bin/env ruby
require 'nokogiri'
require 'thor'
require 'pry-byebug'


class Jcc < Thor
  option :tokenize_only, type: :boolean, default: false
  option :token_output, type: :string
  desc "compile SOURCE", "compiles file"
  def compile(source)
    raise "File not found" unless File.exists?(source) or Dir.exists?(source)

    if Dir.exists?(source)
      Dir[File.join(source, '*.jack')].each { |jack_file| compile jack_file }
      return
    end

    t = Tokeniser.new source
    t.tokenize
    binding.pry

    if options[:tokenize_only]
      filename = options[:token_output] || "#{source}Tok.xml"
      File.open(filename,"w") {|f| f << t.to_xml }
    end
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

  def remove_comments lines
    lines.map! { |l| l.split('//').first }

    while lines.any?{ |l| l.index('/*') } do
      comment_start = lines.find{ |l| l.index('/*')}
      comment_end = lines.find {|l| l.index('*/')}

      raise "Unmatched comment found! starting at line #{lines.index(comment_start)}" unless comment_end

      start_index,end_index =lines.index(comment_start),lines.index(comment_end)

      raise "degenerate state! starting at line #{lines.index(comment_start)}" if start_index == end_index

      lines[start_index] = comment_start.split('/*').first
      lines[end_index] = comment_end.split('*/').last

      lines.slice!( (start_index+1)...end_index)
    end
  end

  def tokenize
    lines = File.open(@source).each_line.to_a

    remove_comments lines

    tokens = lines
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
    @tokens = tokens
    @tokens
  end

  def to_xml
    b = Nokogiri::XML::Builder.new do |xml|
      xml.tokens {
       @tokens.each do |t|
         xml.send(t.values.first, " #{t.keys.first.gsub('"', '')} ")
       end
      }
    end

    b.doc.root.to_xml
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
      #only token that surrounds others is "" so we treat this differently
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
