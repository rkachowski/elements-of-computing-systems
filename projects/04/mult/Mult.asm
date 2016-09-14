// This file is part of www.nand2tetris.org
// and the book "The Elements of Computing Systems"
// by Nisan and Schocken, MIT Press.
// File name: projects/04/Mult.asm

// Multiplies R0 and R1 and stores the result in R2.
// (R0, R1, R2 refer to RAM[0], RAM[1], and RAM[2], respectively.)

// Put your code here.

(SETUP)
    @count
    M=0
    @total
    M=0
(LOOP)
    @count //check exit condition
    D=M
    @R0
    D=D-M
    @END
    D;JEQ

    @count //inc counter
    M=M+1

    @total //inc total
    D=M
    @R1
    D=D+M
    @total
    M=D
    

    @LOOP
    0;JMP

(END)
    @total
    D=M
    @R2
    M=D
