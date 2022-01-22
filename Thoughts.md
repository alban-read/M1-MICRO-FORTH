
### Thoughts and ideas 
 
Can I use X6 as 64 flags rather than one, and get rid of some
variables in the ASM code? And still be quick? - Yes



Should BUFFER$ be renamed as B$ yes
Should APPEND$ be renamed as A$ yes

Can I append a character to the end of the literal strings to control what happens to them

' this goes in the literal pool ' and returns an address

' This stays in the buffer '$  and lives in B$

' This is added to the append buffer '+ added to A$  yes

' this is copied to the last alloted memory ',


Can the predefined dictionary word names be elevated into the string pool at startup

So the 16 bytes get replaced by one eight byte pointer.
The words are then matched by one compare, and can have (new user words at least) names of any length.

Can the dictionary be sorted and then binary searched using an index of pointers to the new pooled name pointers.

Can the long literal pool be sorted, so access remains fast for very large programs.

Are there some words that would be *useful* for the little locals to make more use of the LOCALS stack.

e.g. 
B>[A++] might be an inner cycle in a fill where B is copied to [A] with increment.

[A++]>[B++] might be an inner cycle in a copy where the content of A is copied to the content of B.

A>B might move A to B.

A=B might compare A with B
[A]=[B]

[A]=0
[A++]=0

0>[A]

A bit endless; I like words that are 'little machines'.



Should the STACK words just cycle around when they get to the end? 

Should there be a STACKRESET word, and where would the data live ib the header to enable it.





I really want to have a floating DO LOOP fDO? now 
  
 

: ITERFIB 1 1 BEGIN .. dup rot rot + dup 1e9 > until ;



Optimization thoughts

Very few machine code instructions are needed to compile WORDS to machine code.

The prologue and epilog is always the same.

Get the address of the word in the dictionary relative to dend
Set up X0, X1
BL to word 


LITERALS 
Need to understand how to use MOVK to build those directly rather than using the pool.

Branch forward on Zero
Branch back

And the call sequence 


