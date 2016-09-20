
A_COMMAND = "A_COMMAND"
C_COMMAND = "C_COMMAND"
L_COMMAND = "L_COMMAND"

class Parser
  def initialize file
    raise "File not found at #{file}" unless File.exists? file

    @code = File.open(file).read.lines.map{|l| l.chomp }.delete_if{|l| l.empty? or l.start_with?('//')}
    @current_index = -1
  end

  def commandType
    return nil unless @command

    return A_COMMAND if @command.start_with? '@'
    return C_COMMAND unless Code.parse(@command).flatten.empty?

  end

  def advance
    return unless has_more_commands

    @current_index++
    @command = @code[@current_index]
  end

  def has_more_commands
    @current_index + 1 < @code.length
  end

end

class Code
  @@comp_table ={
    # a = 0
    '0' => "0101010",
    '1' => "0111111",
    '-1' => "0111010",
    'D' => "0001100",
    'A' => "0110000",
    '!D' => "0001101",
    '!A' => "0110001",
    '-D' => "0001111",
    '-A' => "0110011",
    'D+1' => "0011111",
    'A+1' => "0110111",
    'D+1' => "0001110",
    'A-1' => "0110010",
    'D+A' => "0000010",
    'D-A' => "0010011",
    'A-D' => "0000111",
    'D&A' => "0000000",
    'D|A' => "0010101",

    #a = 1
    'M' => "1110000",
    '!M' => "1110001",
    '-M' => "1110011",
    'M+1' => "1110111",
    'M-1' => "1110010",
    'D+M' => "1000010",
    'D-M' => "1010011",
    'M-D' => "1000111",
    'D&M' => "1000000",
    'D|M' => "1010101"
  }

  @@dst_table = {
    'M' => "001", 
    'D' => "010", 
    'MD' => "011", 
    'A' => "100", 
    'AM' => "101", 
    'AD' => "110", 
    'AMD' => "111" 
  }
  @@jump_table = {
    'JGT' => "001", 
    'JEQ' => "010", 
    'JGE' => "011", 
    'JLT' => "100", 
    'JNE' => "101", 
    'JLE' => "110", 
    'JMP' => "111" 
  }

  def self.dest mnem
    dst, _, _ = parse mnem

    @@dst_table[dst] || "000"
  end

  def self.comp mnem

    _,comp, _ = parse mnem
    raise "Unknown comp sequence #{mnem} " unless @@comp_table[comp]
    @@comp_table[comp]
  end

  def self.jump mnem
    _,_,jmp_ = parse mnem
    @@dst_table[jmp] || "000"
  end

  def self.parse inst
    dst, comp, jmp = inst.scan(/^(\w=)?([^;\n]{0,3});?(J\w\w)?/).flatten

    dst = dst.split('=').first if dst
    [dst, comp, jmp]
  end
end

class SymbolTable
end

class Main
end

