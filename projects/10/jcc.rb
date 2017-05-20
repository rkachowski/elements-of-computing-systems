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

    if options[:tokenize_only]
      filename = options[:token_output] || "#{source}Tok.xml"
      File.open(filename,"w") {|f| f << t.to_xml }
      return
    end

    p = Parser.new t
    p.compile
    binding.pry

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

  def validate_and_advance(scope, type, value=nil,throw_error=true)
      result, error = validate type, value

      if result != :ok
        if throw_error then raise error else return [result, error] end
      end

      advance scope
      [:ok]
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
      result, *_ = step.call
      puts result
    end
  end

  def nest scope, sym
    result = []
    scope << {sym =>result }
    result
  end

  def compile_var_dec scope
    valid = find_valid [:keyword, 'var']
    return unless valid and valid[0] == :ok

    varDec = nest scope, :varDec
    advance varDec

    find_valid [:keyword, 'int'], [:keyword, 'char'],[:keyword, 'boolean'],[:identifier]
    advance varDec

    #varname
    validate_and_advance(varDec, :identifier)

    zeroOrMany -> {
      validate_and_advance(varDec, :symbol, ',',false) 
      validate_and_advance(varDec, :identifier, nil,false)
    }

    validate_and_advance(varDec, :symbol, ';')

    [:ok]
  end

  def compile_class_var_dec scope
    valid = find_valid [:keyword, 'static'], [:keyword, 'field']
    return unless valid and valid[0] == :ok
    varDec = nest scope, :classVarDec
    advance varDec

    find_valid [:keyword, 'int'], [:keyword, 'char'],[:keyword, 'boolean'],[:identifier]
    advance varDec

    validate_and_advance(varDec, :identifier)

    zeroOrMany -> do 
      validate_and_advance(varDec, :symbol, ',',false)
      validate_and_advance(varDec, :identifier,nil, false)
    end

    validate_and_advance(varDec, :symbol, ';')

    [:ok]
  end

  def compile_subroutine_dec scope
    valid = find_valid [:keyword, 'constructor'], [:keyword, 'function'],[:keyword, 'method']
    return unless valid[0] == :ok
    subroutineDec  = nest scope, :subroutineDec
    advance subroutineDec

    find_valid [:keyword, 'int'], [:keyword, 'char'],[:keyword, 'boolean'],[:identifier],[:keyword, 'void']
    advance subroutineDec

    validate_and_advance(subroutineDec, :identifier) #subroutine name
    validate_and_advance(subroutineDec, :symbol, "(")
    compile_parameter_list subroutineDec
    validate_and_advance(subroutineDec, :symbol, ")")

    compile_subroutine_body subroutineDec
    [:ok]
  end

  def compile_parameter_list scope
    valid = find_valid [:keyword, 'int'], [:keyword, 'char'],[:keyword, 'boolean'],[:identifier]
    return unless valid[0] == :ok
    parameterList = nest scope, :parameterList
    advance parameterList

    validate_and_advance(parameterList, :identifier)

    zeroOrMany -> do
      validate_and_advance(parameterList, :symbol, ',')
      find_valid [:keyword, 'int'], [:keyword, 'char'],[:keyword, 'boolean'],[:identifier]
      advance parameterList
      validate_and_advance(parameterList, :identifier)
    end

    [:ok]
  end

  def compile_subroutine_body scope
    valid = find_valid [:symbol, '{']
    return unless valid[0] == :ok
    body = nest scope, :subroutineBody
    advance body

    zeroOrMany -> { compile_var_dec body }

  
    compile_statements body

    validate_and_advance body, :symbol, '}'

    [:ok]
  end

  def compile_statements scope
    statements = nest scope, :statements

    zeroOrMany -> do
     compile_statement statements
    end

    [:ok]
  end

  def compile_statement scope

    case @input.current_token.keys.first
    when 'let'
      compile_let_statement scope
    when 'if'
      compile_if_statement scope
    when 'while'
      compile_while_statement scope
    when 'do'
      compile_do_statement scope
    when 'return'
      compile_return_statement scope
    else 
      return [:unknown_statement, "couldn't identify statement"]
    end

    [:ok]
  end

  def compile_let_statement scope
    let = nest scope, :letStatement
    advance let
    
  end

  def compile_if_statement scope
    if_s = nest scope, :ifStatement
    advance if_s
    
  end
  def compile_while_statement scope
    while_s = nest scope, :whileStatement
    advance while_s
    
  end

  def compile_do_statement scope
    do_s = nest scope, :doStatement
    advance do_s
    
  end

  def compile_return_statement scope
    return_s = nest scope, :returnStatement
    advance return_s

    zeroOrMany -> { compile_expression return_s }

    validate_and_advance(return_s, :symbol, ';')
    
  end

  def compile_expression scope
    exp = nest scope, :expression
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
