// This file is part of www.nand2tetris.org
// and the book "The Elements of Computing Systems"
// by Nisan and Schocken, MIT Press.
// File name: projects/04/Fill.asm

// Runs an infinite loop that listens to the keyboard input. 
// When a key is pressed (any key), the program blackens the screen,
// i.e. writes "black" in every pixel. When no key is pressed, the
// program clears the screen, i.e. writes "white" in every pixel.

// Put your code here.

(LOOP)
    M=D
    @count
    M=-1
    @color
    M=0 //white by default

    //get key
    @24576
    D=M
    @FILL
    D;JEQ

    @color//keyboard isn't 0, so set black
    M=-1

(FILL)
    //increment counter
    @count
    M=M+1

    @SCREEN//find next vram destination
    D=A
    @count
    D=D+M
    @next_vram_dest
    M=D

    @color//set 16 bits of color at vram dest
    D=M
    @next_vram_dest
    A=M
    M=D

    @24575 //draw until max vram
    D=A
    @next_vram_dest
    D=D-M
    @FILL
    D;JGT

    @LOOP
    0;JMP
    //lol
