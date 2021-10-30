## dumb interpeter

nnn      convert number and push it

a-z      fetch 64bit variable address and push it

@        fetch value from stacked address

!        store 2nd into tos

.        pop and display tos

compile a new word

: new-word 
  word word word ;


immediate mode
find word, fetch code pointer (to primitive word), call it.
    if number push

compiling mode
create new word, store docol, semi.
    find word, store code pointer
        if number store dolit, number

docol, pushes IP, sets IP to next cell, 
calls every function in the word (which may modify IP); terminates at semi, pops IP.








