## dumb [as an especially dumb rock] interpeter

Inspired by FORTH, but more primitive and trying to be compact.

With .. tradeoffs..

This is written from scratch, starting with a blank editor page.

### purpose

Learn ARM64, have some fun, create useful things.


### approach

create small machine code primitive words 

 .. allow them to be tested interactively

 .. allow new words to be composed, mainly by concatenation.

Get an interactive interpreter running from Day 1, and then build it out.

The process is incremental, and interactive from the start, as soon as the outer text interpreter works, it is used to test the next features added.


### expedience

It is ok to start by using some functions from the standard C library to get up and running.

Later may migrate to only use system calls and internal system functions.

ASCII text is used for function names and vaiables, not Unicode

Unicode will be supported only in strings when they are added


### goals

Do not use 64 bit values all over the place just because it is a 64bit processor

Use 32bit values when 32 bit values will do.

Use bytes if bytes will do.

Support integer and decimal maths


Use ASCII

Support Strings of Unicode Runes in a safe and sensible way (later)


### Milestones

Tuesday 16th November 2021

First 'compiled' word. (token compiled)

: test DUP * . ;

5 test => 25 

The compiler is compiling into a token list, tokens are still interpreted, but unlike the outer interpreter they are no longer parsed from text.

This inner interpreter is only a few instructions long, in runintz.
It is more complicated than typical threaded FORTH because of the token expansion, and due to the words data being passed over in X0.  

For runintz the data is the address of the tokens.

The functions are all 'called', rather than jumping through next.

I feel this might make it easier to change the compiler to use subroutine threading later.


### Dictionary

A dictionary provides a way to name objects.

The dictionary contains word headers.

A headers has pointer to the words functions (runtime and compile time), and space for data belonging to the word.


The dictionary is 'full of holes' for user defined words, spread throughout it.


' WORD     - ( -- word address)
NTH        - ( word address -- token )
ADDR       - ( token -- word address)    


NTH and ADDR provide a way of representing the address of the 
word in 16 bits (its position in the dictionary), rather than 64 bits (the full addres)

To make token expansion simple, the dictionary contains fixed size words.




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



#### Compiled word

A 'compiled' word is a list of tokens 
The token interpeter expands tokens and calls words.
X15 is the IP pointing at the next token, which can be modified by words.


0     [pointer to tokens]
8     [word name ]

tokens:

24    [runint]  --> code that runs the interpreter for tokens
32    [token]   <-- small half word sized tokens (16 bits)
34    [token]
36    [token]
..
124   [token]
126   [0]  <-- end token interpreter.

The tokens compress the high level forth code, we do not want to use 64 bits for each word.

The cost is the token lookup see NTH and the token expansion see ADDR.

The token lookup is simplified by the dictionary being a fixed size.


### More primitive

The concept is to write the application in assembler and script/test it

the interpreter is a way to call words written in regular assembler, new words are added to the asm files in assembly.

high level words are collections of word tokens, the tokens are converted to word addresses by the token interpreter, and the word at that address in the dictionary is then called.



#### More primitive than FORTH
 

Literals

literals are stored inline for small values, and as an index into literal pools for long values.

numeric literals small 
[lits][short literal]

numeric literals large 
[litl][index] --------->  literal pool



ARRAY lookup

Look up literal N in LITBASE

LITBASE n 8* + @ .
























