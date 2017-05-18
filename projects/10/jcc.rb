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
    p = Parser.new t
    p.compile


    if options[:tokenize_only]
      filename = options[:token_output] || "#{source}Tok.xml"
      File.open(filename,"w") {|f| f << t.to_xml }
    end
  end
  default_task :compile
end

class Parser
  def initialize tokenizer
    @input = tokenizer
    @output = []
  end

  def compile
    compileClass 
  end

  def compileClass
    validate :keyword, 'class'

    klass = []
    @output << {:class => klass}
    advance klass

    validate_and_advance(klass,:identifier)
    validate_and_advance(klass,:symbol, "{")

    zeroOrMany ->{  compile_class_var_dec klass }
    zeroOrMany ->{  compile_subroutine_dec klass }

    validate_and_advance(klass,:symbol, "}")
  end

  def validate_and_advance(scope, type, value=nil)
      result, error = validate type, value
      raise error unless result == :ok
      advance scope
  end

  def find_valid *args
    args.each do |(type, value)|
      result = validate(type, value)
      return result if result[0] == :ok
    end
  end

  def zeroOrMany step
    result = :ok
    while result == :ok
      result = step.call
    end
  end

  def nest scope, sym
    result = []
    scope << {sym =>result }
    result
  end

  def compile_class_var_dec scope
    valid = find_valid [:keyword, 'static'], [:keyword, 'field']
    return unless valid and valid[0] == :ok
    varDec = nest scope, :varDec
    advance varDec

    valid = validate_type
    advance varDec

    #varname
    validate_and_advance(varDec, :identifier)

    zeroOrMany -> {validate_and_advance(varDec, :symbol, ','); validate_and_advance(varDec, :identifier)}

    validate_and_advance(varDec, :symbol, ';')

    [:ok]
  end

  def validate_type *args
    find_valid [:keyword, 'int'], [:keyword, 'char'],[:keyword, 'boolean'],[:identifier],*args
  end

  def compile_subroutine_dec scope
    valid = find_valid [:keyword, 'constructor'], [:keyword, 'function'],[:keyword, 'method']
    return unless valid[0] == :ok
    subroutineDec  = nest scope, :subroutineDec
    advance subroutineDec

    valid = validate_type [:keyword, 'void']
    advance subroutineDec

    validate_and_advance(subroutineDec, :identifier) #subroutine name
    validate_and_advance(subroutineDec, :symbol, "(")

    compile_parameter_list subroutineDec

    validate_and_advance(subroutineDec, :symbol, ")")

    compile_subroutine_body subroutineDec
    binding.pry
    [:ok]
  end

  def compile_parameter_list scope
    nest scope, :parameterList
  end

  def compile_subroutine_body scope
    nest scope, :subroutineBody
  end

  def advance scope
    scope << @input.current_token
    @input.next
  end

  def validate type, value = nil
    token = @input.current_token

    unless token.values.first == type
      return [ :wrong_type, "Expected #{type} but was #{token.to_s}" ]
    end

    if value and token.keys.first != value
      return [ :wrong_value, "Expected #{value} for #{type} but was #{token.to_s}" ]
    end

    [:ok]
  end
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
    @current_token = 0
    @tokens = []
    tokenize
  end

  def has_more_tokens
    @current_token < @tokens.size
  end

  def current_token
    @tokens[@current_token]
  end

  def next 
    @current_token = @current_token + 1
    @tokens[@current_token]
  end

  def peek
    @tokens[@current_token+1]
  end

  private

  def remove_comments lines
    lines.map! { |l| l.split('//').first }

    while lines.any?{ |l| l.index('/*') } do
      comment_start = lines.find{ |l| l.index('/*')}
      comment_end = lines.find {|l| l.index('*/')}

      raise "Unmatched comment found! starting at line #{lines.index(comment_start)}" unless comment_end

      start_index,end_index =lines.index(comment_start),lines.index(comment_end)

      if start_index == end_index
        lines[start_index] = lines[start_index].gsub(/\/\*.*\*\//, "")
        next
      end

      #remove everything after block comment start
      lines[start_index] = comment_start.split('/*').first
      #remove everything before block comment end
      lines[end_index] = comment_end.split('*/').last

      next if start_index+1 == end_index #there's nothing between the lines

      #remove lines between block comment start and end
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

    return :stringConstant if str.match /^"[^\n]*"$/
    return :integerConstant if str.match(/^\d+$/) and (0..32767).include?(str.to_i)
    return :identifier if str.match /^[a-zA-Z_]+[\w\d]*$/
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
