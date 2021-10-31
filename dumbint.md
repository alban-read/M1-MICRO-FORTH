## dumb [as an especially dumb rock] interpeter

### purpose

Learn ARM64, have some fun.


### approach

create small machine code words 

and allow them to be tested interactively

and allow them to be combined by composition into larger words.


### expedience

It is ok to start by using the standard C library to get up and running.

Later may migrate to only use system calls.

ASCII text


### goals

Do not use 64 bit values all over the place just because it is a 64bit processor

Use 32bit values 32 bit values will do.

Use bytes if bytes will do.


### notes

nnn      convert number and push it

a-Z      fetch  

@        fetch value from stacked address
!        store 2nd into tos

primitive words

. + - * / etc

compile a new word

: new-word 
  word word word ;

### still thinking about how many levels of indirection are needed to run composed words.

immediate mode
find word, fetch code pointer (to primitive word), call it.
    if number push

compiling mode
create new word, store docol, semi.
    find word, store code pointer
        if number store dolit, number

docol, pushes IP, sets IP to next cell, 
calls every function in the word (which may modify IP); terminates at semi, pops IP.








