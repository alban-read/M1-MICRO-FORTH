## dumb [as an especially dumb rock] interpeter

Inspired by FORTH.

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

Support Strings of Unicode Runes in a safe and sensible way



### Dictionary

The dictionary contains word headers, a pointer to the words functions (runtime and compile time), and an element of data for the word.

There are two dictionaries.

1 Single byte word names.

A single letter word can be located using the letter as an index into the dictionary that contains 256 words.

The single letter name is essentially a byte code as far as the interpeter is contained.


2 Multi byte word names (up to 15).

The multi byte dictionary has 27 entry points, based on the starting letter A..Z, and all other.

It is not sorted other than by the first letter of each word.

The dictionary is 'full of holes' for user defined words, spread throughout it.




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

### still thinking about how many levels of indirection are needed to run composed words.

immediate mode
find word, fetch code pointer (to primitive word), fetch word data, and call it.
    if number push

compiling mode
create new word, store docol, semi.
    find word, store code pointer
        if number store dolit, number

docol, pushes IP, sets IP to next cell, 
calls every function in the word (which may modify IP); terminates at semi, pops IP.








