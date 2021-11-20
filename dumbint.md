## dumb [as an especially dumb rock] interpeter

Inspired by FORTH, not a new invention, since only idiots invent new languages.

With .. tradeoffs..

This was written from scratch, starting with a blank editor page in VS code, CLANG Assembler is used.


### Incomprehension about Documentation

I am stunned by projects in GITHUB that have complex software and no documentation 

Mine are simple projects,  with documentation, I guess you can't have everything.


### purpose

Learn ARM64, have some fun, create useful things.


### approach

create small machine code primitive words 

 .. allow them to be tested interactively

 .. allow new words to be composed, mainly by concatenation.

Get an interactive interpreter running from Day 1, and then build it out.

The process is incremental, and interactive from the start, as soon as the outer text interpreter works, it is used to test the next features added.

Use the computer as the tool for using the computer.



### expedience

It is ok to start by using some functions from the standard C library to get up and running.

Later may migrate to only use system calls and internal system functions.

ASCII text is used for function names and vaiables, not Unicode

Unicode may be supported only for Unicode strings if they are added


### Origin

Greenspans 10th rule

Any sufficiently complicated C or Fortran program contains an ad hoc, informally-specified, bug-ridden, slow implementation of half of Common Lisp.

Albans Nth rule

Any sufficiently simple assembly language program contains a half-arsed implementation of FORTH.

e.g. As soon as you start writing a program in Assembler, if you want to test it, and retain your sanity, you need to implement at least half of the things that FORTH provides.

But no more that that, or it becomes FORTH, and that is not the end objective of working in Assembler.

Just enough FORTH to test the assembler words and string them together is the trick.


#### Memory management

None.

Memory management is Static.

People sometimes forget that static memory allocation is viable.

The program contains a few tables of fixed sizes.

If you blow past a limit you will get an error message.

If your program exceeds a limit, just change that limit and recompile.

This does waste some memory, although you can also decrease the fixed sizes. right?

The machine stack can grow since the operating system does that.

Otherwise the dictionary size and the literal pools are fixed size.

The fixed sizes are reasonable for what I want to do, the machine I am using has eight gigabytes of ram, it is a low cost entry model...




### goals

Do not use 64 bit values all over the place just because it is a 64bit processor

Use 32bit values when 32 bit values will do.

Use words or bytes where words or bytes will do.

Support integer and decimal maths


Use ASCII

Support Strings of Unicode Runes in a safe and sensible way (later)


### Milestones

#### Tuesday 16th November 2021

First 'compiled' word. (token compiled)

```FORTH
: test DUP * . ;

5 test => 25 
```

The compiler is compiling into a token list, tokens are still interpreted, but unlike the outer interpreter they are no longer parsed from text.

This inner interpreter is only a few instructions long, in runintz.

It is more complicated than typical threaded FORTH because of the token expansion, and due to the words data being passed over in X0.  

For runintz the data is the address of the tokens.

The functions are all 'called', rather than jumping through next.

I feel this might make it easier to change the compiler to use subroutine threading later.


#### Wednesday Morning

Implemented IF and ENDIF allowing conditional logic.

If the stack is 0 IF skips to ENDIF

```FORTH

: TEST IF CR 65 EMIT ENDIF 66 EMIT ;
```

At compile time IF compiles zbranch and and undefinded offset

At compile time ENDIF compiles the offset into the closest zbranch or branch.

e.g. 

1 TEST => 
AB 
     
0 TEST => B

```FORTH
WORD AT :4345127232 TEST        
       0 :4345127264 		^TOKENS 
       8 :TEST        		NAME
      24 :4344297796 		TOKEN COMPILED

      32 : [     3] #ZBRANCH    
      34 : [    10] *
      36 : [   369] CR          
      38 : [     1] #LITS       
      40 : [    65] *
      42 : [   541] EMIT        
      44 : [   540] ENDIF       
      46 : [     1] #LITS       
      48 : [    66] *
      50 : [   541] EMIT        
      52 : [     0] (NULL)      
      54 : END OF LIST


```


Note ENDIF is a no-op at run time so uses no token space.

At runtime zbranch adds the offset to the IP or not, depending on the value on the stack.



Added ELSE as in 

IF ... ELSE  ... ENDIF 

```FORTH
: TEST IF CR 65 EMIT ELSE CR 66 EMIT ENDIF 67 EMIT ;
```

e.g. 

1 TEST => AC
0 TEST => BC 

Added SEE to help add ELSE.

At compile time :-
ELSE looks for IF
ENDIF looks for ELSE or IF.


#### Thursday morning

Fixed a mysterious error.

Added a little (not a lot of) safety to variable access.

Added some tests and fixed nested IF ..

Fixed a spurious and annoying error.

Start with the return stack, for loops.

Implemented and tested words for LOOP

Updated tracing to not crash.





### Dictionary

A dictionary provides a way to name objects.

The dictionary contains word headers.

A headers has pointer to the words functions (runtime and compile time), and space for data belonging to the word.


The dictionary is 'full of holes' for user defined words, spread throughout it.


' WORD     - ( -- word address)

NTH        - ( word address -- token )

ADDR       - ( token -- word address)    


NTH and ADDR provide a way of representing the address of the word in less than 16 bits (its position in the dictionary), rather than 64 bits (the full address)

To make token expansion simple, the dictionary contains fixed size words.




### notes

nnn      convert text to integer number and push it

nn.nn    convert text to decimal number and push it TODO

a-Z      fetch address of fixed global variable

@        fetch value from stacked address see below.

!        store value into variable see below.

e.g. set variable

100 A !

get and print the variables value on a new line

CR A @ . 

primitive words

. + - * / etc

compile a new word

: new-word 

  word number word number ..    ;


The words and numbers between : and ; are compiled into tokens and stored in new-word.

e.g. 

: square 
  dup *  ;

6 square => 30





#### Compiled word

A 'compiled' word is just a list of tokens 

The token interpeter expands tokens and calls the words machine code.

X15 is the IP pointing at the next token, which can be modified by words.



0     [pointer to tokens]
8     [word name ]

tokens: (example)

24    [runint]  --> code that runs the interpreter for tokens

32    [token]   <-- small half word sized tokens (16 bits)

34    [token]

36    [token]

38    [#LITS]  <-- LITS is the small literal follows token 
39    [small number]
..
124   [token]
126   [0]  <-- end token interpreter.

The tokens compress the high level forth code, we do not want to use 64 bits for each word.

The cost is the token lookup see NTH and the token expansion see ADDR.

The token lookup is simplified by the dictionary being a fixed size.

You can use the decompiler to look at words.



#### Decompiler

If you are writing a compiler, it helps to see what is going on.

In FORTH the decompiler is traditionally called SEE.

: TEST IF 65 EMIT ELSE 66 EMIT ENDIF 67 EMIT ;

Compiler Finished

Ok

```FORTH

: TEST IF 65 EMIT ELSE 66 EMIT ENDIF 67 EMIT ;
Ok

 66 half word cells uses, compiler Finished
  
SEE TEST
WORD AT :4341489984 TEST        
       0 :4341490016 		^TOKENS 
       8 :TEST        		NAME
      24 :4340660540 		TOKEN COMPILED

      32 : [     3] #ZBRANCH    
      34 : [    16] *
      36 : [   369] CR          
      38 : [     1] #LITS       
      40 : [    65] *
      42 : [   541] EMIT        
      44 : [     4] #BRANCH     
      46 : [    10] *
      48 : [   369] CR          
      50 : [     1] #LITS       
      52 : [    66] *
      54 : [   541] EMIT        
      56 : [   540] ENDIF       
      58 : [     1] #LITS       
      60 : [    67] *
      62 : [   541] EMIT        
      64 : [     0] (NULL)      
      66 : END OF LIST

```

This shows the word and word type.

A literal is marked with a * 

A token is displayed in brackets.

The name of the word the token represents is displayed.

Tracing the flow

```FORTH
TRON
1 TEST
1 TEST

4341490016 : [     3] #ZBRANCH    S : [     1] : [    67] : [     0] R : [     0] : [     0] : [     0] 
4341490018 : [    16] #16         S : [    67] : [     0] : [     0] R : [     0] : [     0] : [     0] 

4341490020 : [   369] CR          S : [    67] : [     0] : [     0] R : [     0] : [     0] : [     0] 
4341490022 : [     1] #LITS       S : [    67] : [     0] : [     0] R : [     0] : [     0] : [     0] 
4341490024 : [    65] ????????    S : [    65] : [    67] : [     0] R : [     0] : [     0] : [     0] A
4341490026 : [   541] EMIT        S : [    67] : [     0] : [     0] R : [     0] : [     0] : [     0] 
4341490028 : [     4] #BRANCH     S : [    67] : [     0] : [     0] R : [     0] : [     0] : [     0] 
4341490030 : [    10] #10         S : [    67] : [     0] : [     0] R : [     0] : [     0] : [     0] 
4341490038 : [   541] EMIT        S : [    67] : [     0] : [     0] R : [     0] : [     0] : [     0] 
4341490038 : [   541] EMIT        S : [    67] : [     0] : [     0] R : [     0] : [     0] : [     0] 
4341490042 : [     1] #LITS       S : [    67] : [     0] : [     0] R : [     0] : [     0] : [     0] 
4341490044 : [    67] ????????    S : [    67] : [    67] : [     0] R : [     0] : [     0] : [     0] C
4341490046 : [   541] EMIT        S : [    67] : [     0] : [     0] R : [     0] : [     0] : [     0] 
```






### More primitive

The concept is to write the application in assembler and script/test it

the interpreter is a way to call words written in regular assembler, new words are added to the asm files in assembly.

high level words are collections of word tokens, the tokens are converted to word addresses by the token interpreter, and the word at that address in the dictionary is then called.



#### More primitive than FORTH
 

Literals

literals are stored inline for small values, and as an index into literal pools for long values.

numeric literals small 
[#lits][short literal]

numeric literals large 
[#litl][index] --------->  literal pool



Long literals are held in the LITBASE

A compiled dictionary word just refers to the LITBASE using a halfword index

Look up literal N in the LITBASE

LITBASE n 8* + @ .

The litbase




## TESTS 

: TESTNEST IF 65 EMIT IF 66 EMIT ELSE 67 EMIT ENDIF ENDIF 68 EMIT ;

Test nested IF ELSE ENDIF 

expected 

1 0 TESTNEST => D
1 1 TESTNEST => ABD
0 1 TESTNEST => ACD
0 0 TESTNEST => D



### TRACING

If tracing is set to 1 then words will be traced, which means printing the name of
each word as it is executed.

: TEST DUP * . ;

TROFF

5 TEST => 25

TRON

5 TEST 

5 TEST
DUP         
*           
.           
 25

Tracing does add overhead even if switched off.

So you can disable it in RUNINTZ



: TEST 10 1 DO CR 10 1 DO 35 EMIT LOOP LOOP ;


### Testing LOOPs

The words (DO) (DOER) (LOOP) (+LOOP) (-LOOP) are not normally displayed as they are not user words, and I have aspirations to make the interpreter safe for people to use without crashing.


The word ALLWORDS will display all the words, including words compiled by the compiler.

The words are used by the compiler to construct loops and control stuctures.

The interpreter in this implementation, is straight assembler language.

This provides a benefit that the compile only words can be tested in the interpreter, since in a sense FORTH is not active at that point.

e.g. 

10 1 (DO) I . CR (LOOP)  

Will single step a loop.

Allowing (DO), I, J, K, and (LOOP) to be tested interactively.





### LOOP Improvements 

The LOOP control statement in FORTH does confusing things.

In this implentation the DO .. LOOP is designed to do what any reasonable person would expect it to do, before they used FORTH. 

Normal loop

: t0 10 1 DO I . CR LOOP ;

Sanity is aided by the addition of DOWNDO (inspired by PASCAL) and -LOOP


: t1 10 2 DO I . CR 2 +LOOP ;

: t3 2 10 DOWNDO I . CR 2 -LOOP ;


Summary

It is very clear if the LOOP counts up or down, and very obvious if a LOOP should end or not, if it includes the start and finish (it does).
This LOOP is not at all likely to repeat 65536 times (or in this case billions of times ) by mistake.

This is not compatible 

I do not expect to be able to compile ANSI FORTH, nor do I have some large source of ANSI code somewhere I can reuse.

