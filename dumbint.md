## dumb [as an especially dumb rock] interpeter

Inspired by FORTH, not a new invention, since only idiots invent new languages.

With .. tradeoffs..

This was written from scratch, starting with a blank editor page in VS code.


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


### expedience

It is ok to start by using some functions from the standard C library to get up and running.

Later may migrate to only use system calls and internal system functions.

ASCII text is used for function names and vaiables, not Unicode

Unicode may be supported only for Unicode strings if they are added


#### Memory management

None.

Memory management is Static.

People sometimes forget that static memory allocation was always there.

The program contains a few tables of fixed sizes.

If you blow past a limit you will get an error message.

If your program exceeds a limit, just change that limit and recompile.

This does waste some memory, although you can also decrease the fixed sizes. right?

The machine stack can grow since the operating system does that.

Otherwise the dictionary size and the literal pools are fixed size.

The fixed sizes are reasonable for what I want to do, the machine I am using has 

eight gigabytes of ram, it is a low cost entry model...




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

: test DUP * . ;

5 test => 25 

The compiler is compiling into a token list, tokens are still interpreted, but unlike the outer interpreter they are no longer parsed from text.

This inner interpreter is only a few instructions long, in runintz.
It is more complicated than typical threaded FORTH because of the token expansion, and due to the words data being passed over in X0.  

For runintz the data is the address of the tokens.

The functions are all 'called', rather than jumping through next.

I feel this might make it easier to change the compiler to use subroutine threading later.


#### Wednesday Morning

Implemented IF and ENDIF allowing conditional logic.

If the stack is 0 IF skips to ENDIF

: TEST IF CR 65 EMIT ENDIF 66 EMIT ;

At compile time IF compiles zbranch and and undefinded offset

At compile time ENDIF compiles the offset into the closest zbranch or branch.

e.g. 

1 TEST => 
AB 
     
0 TEST => B

In memory the layout of Test looks like 

+

0   Point to tokens at +32

8   Name of word .....

16  runintz address 

24  0

32  token for zbranch         <= TOKENS fed to runintz

34  offset value

36  token for CR

38  token for small literal

40  value 65 

42  token for EMIT

44  token for small literal

46  value 66

48  token for EMIT

50  token for end of word 0



Note ENDIF is a no-op at run time so uses no token space.

At runtime zbranch adds the offset to the IP or not, depending on the value on the stack.



Added ELSE as in 

IF ... ELSE  ... ENDIF 


: TEST IF CR 65 EMIT ELSE CR 66 EMIT ENDIF 67 EMIT ;

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



#### Decompiler

If you are writing a compiler, it helps to see what is going on.

For visibility it is good to have a decompiler.

In FORTH the decompiler is traditionally called SEE.



: TEST IF 65 EMIT ELSE 66 EMIT ENDIF 67 EMIT ;

Compiler Finished

Ok

SEE TEST

WORD AT :4330433600

       0:4330433632             ^TOKENS 

       8:TEST                   NAME

      24:4329880276             TOKEN COMPILED

      32:[     3]#ZBRANCH    

      34:[    12]*

      36:[     1]#LITS       

      38:[    65]*

      40:[   246]EMIT        

      42:[     4]#BRANCH     

      44:[    12]*

      46:[     1]#LITS       

      48:[    66]*

      50:[   246]EMIT        

      52:[     1]#LITS       

      54:[    67]*

      56:[   246]EMIT        

      58:

This shows the word and word type.

A literal is marked with a *

A token is displayed in brackets.

The name of the word the token represents is displayed.



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














