## dumb [as an especially dumb rock] interpeter

Inspired by FORTH, but more primitive.


### purpose

Learn ARM64, have some fun, create useful things.


### approach

create small machine code primitive words 

 .. allow them to be tested interactively

 .. allow new words to be composed, mainly by concatenation.


### expedience

It is ok to start by using the standard C library to get up and running.

Later may migrate to only use system calls.

ASCII text is used for function names and vaiables, not Unicode

Unicode will be supported only in strings when they are added


### goals

Do not use 64 bit values all over the place just because it is a 64bit processor

Use 32bit values 32 bit values will do.

Use bytes if bytes will do.

Support integer and decimal maths


Use ASCII

Support Strings of Unicode Runes in a safe and sensible way (later)



### Dictionary

A dictionary provides a way to name objects.

The dictionary contains word headers.

A headers has pointer to the words functions (runtime and compile time), and space for data belonging to the word.


The dictionary is 'full of holes' for user defined words, spread throughout it.


' WORD     - ( -- word address)
NTH        - ( word address -- pos )
ADDR       - ( pos -- word address)    


NTH and ADDR provide a way of representing the address of the 
word in 16 bits (its position in the dictionary), rather than 64 (the full addres)



### notes

nnn      convert text to integer number and push it

nn.nn    convert text to decimal number and push it

a-Z      fetch address of global variable

@        fetch value from stacked address
!        store 2nd into tos

e.g. set variable

100 A !

get and print the variables value on a new line

CR A @ . 

primitive words

. + - * / etc

compile a new word

: new-word 
  word word word ;

  
### More primitive

The concept is to write the application in assembler and script/test it

the interpreter is a way to call words written in regular assembler, new words are added to the asm files in assembly.

high level words are collections of word tokens, the tokens are converted to word addresses by the token interpreter, and the word at that address in the dictionary is then called.



#### More primitive than FORTH

High level words need to be short, they MAY not contain text literals.

literals are stored in their own words and then used elsewhere.

A high level word starts with : and ends with ;

e.g. 

: PRINTSQUARE DUP * . ;

In the interpreter you can type

20345 PRINTSQUARE 
=> 413919025
 
The compiled high level words do not contain literals.
 
Instead other words must be defined to contain the literals

e.g. Literal text

Literal text is displayed by defining a test display word for each text item.

e.g.  :." WELL?  Well hello how are you feeling today ?\n ";
          -----  -----------------------------------------
          Word   Text, up to 96 chars.

:."  - means display string 
- stores text until "; when called prints it.

Literal text may be stored with 

:" HEYJUDE Hey Jude! ";

This word returns the address of the text when invoked.

HEYJUDE TYPEZ would print 'Hey Jude!'



























