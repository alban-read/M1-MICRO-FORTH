## dumb [as an especially dumb rock] interpeter

Inspired by FORTH, not a new invention, since only fools invent new languages.

With .. tradeoffs..

This was written from scratch, starting with a blank editor page in VS code, CLANG Assembler is used.



### purpose

Learn ARM64, have some fun, create useful things.


### approach

I am being machine specific, e.g. ARM64 not INTEL.

create small machine code primitive words 

 .. allow them to be tested interactively

 .. allow new words to be composed, mainly by concatenation.

Get an interactive interpreter running from Day 1, and then build it out.

The process is incremental, and interactive from the start, as soon as the outer text interpreter said OK, it was used to test the next features added.

Use the computer against itself (Use the computer as a tool for using the computer).



### expedience

It is ok to start by using some functions from the standard C library to get up and running.

Later I may migrate to only use system calls and internal system functions.

ASCII text is used for function names and vaiables, not Unicode

Unicode may be supported only for Unicode strings if they are added


### Origin

Greenspans 10th rule

Any sufficiently complicated C or Fortran program contains an ad hoc, informally-specified, bug-ridden, slow implementation of half of Common Lisp.



Albans Nth rule

Any sufficiently simple assembly language program contains a half-arsed implementation of FORTH.




#### Memory management

None.

Memory management is Static, really it is organized as a number of stacks and pools.

- The program contains a few tables of fixed sizes.

- If you blow past a limit you will get an error message.

- If your program exceeds a limit, just change that limit and rebuild.


### Memory - literal pools

The compiler uses literal pools, that is a deviation from most FORTH implementations, that use a single dictionary.

A literal pool fits in better with the whole RISC, rigid alignment, fixed length words, load/store, seperate code and data, computer model we have going on post intel.



### goals

Create an interactive environment open to introspection and exploration.

Do not use 64 bit values all over the place just because it is a 64bit processor

Use 32bit values when 32 bit values will do.

Use words or bytes where words or bytes will do.

Support integer and decimal and matrix maths

Support connecting to C (as I need to talk to OS graphics library)


Use ASCII

Support Strings of Unicode Runes in a safe and sensible way (later)


### Week off November 2021 : the big push, kick off.

I took a week off (leave/PTO) to work on whatever I liked and spent time on this.

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

At compile time IF compiles (IF)) with a slot for the offset.

At compile time ENDIF compiles a value into the offset of the matching zbranch or branch.

ENDIF should skip compiling itself, it shows up below due to a bug, at runtime ENDIF is a NOOP.

e.g. 


```FORTH

1 TEST => 
AB 
     
0 TEST => B


SEE TEST
SEE WORD :4340062016 TEST        
       0 :4339055954 		^TOKENS 
       8 :4338935500 		PRIM RUN
      16 :       0 		ARGUMENT 2
      24 :       0 		PRIM COMP
      32 :       0 		Extra DATA 1
      40 :       0 		Extra DATA 2
      48 :TEST        		NAME
		TOKEN COMPILED FAST

4339055954 : [     3] (IF)        
4339055956 : [    46] *
4339055958 : [   374] CR          
4339055960 : [     1] #LITS       
4339055962 : [    65] *
4339055964 : [   547] EMIT        
4339055966 : [   546] ENDIF       
4339055968 : [     1] #LITS       
4339055970 : [    66] *
4339055972 : [   547] EMIT        
4339055974 : [     0] (NULL)      
4339055976 : END OF LIST
 
```


 

At runtime (IF), and (ELSE) adds the offset to the IP (X15) or not, depending on the value on the stack.



Added ELSE as in 

IF ... ELSE  ... ENDIF 

```FORTH
: TEST IF CR 65 EMIT ELSE CR 66 EMIT ENDIF 67 EMIT ;
```

e.g. 

1 TEST => AC
0 TEST => BC 

I first added SEE to help me add ELSE.

At compile time :-
ELSE looks for IF
ENDIF looks for ELSE or IF.


```FORTH
SEE TEST
SEE WORD :4379973504 TEST        
       0 :4378967328 		^TOKENS 
       8 :4378846924 		PRIM RUN
      16 :       0 		ARGUMENT 2
      24 :       0 		PRIM COMP
      32 :       0 		Extra DATA 1
      40 :       0 		Extra DATA 2
      48 :TEST        		NAME
		TOKEN COMPILED FAST

4378967328 : [     3] (IF)        
4378967330 : [    48] *
4378967332 : [   374] CR          
4378967334 : [     1] #LITS       
4378967336 : [    65] *
4378967338 : [   547] EMIT        
4378967340 : [     4] (ELSE)      
4378967342 : [    46] *
4378967344 : [   374] CR          
4378967346 : [     1] #LITS       
4378967348 : [    66] *
4378967350 : [   547] EMIT        
4378967352 : [   546] ENDIF       
4378967354 : [     1] #LITS       
4378967356 : [    67] *
4378967358 : [   547] EMIT        
4378967360 : [     0] (NULL)      
4378967362 : END OF LIST
```



#### Thursday morning

- Fixed a mysterious error.

- Added a little (not a lot of) safety to variable access.

- Added some tests and fixed nested IF ..

- Fixed a spurious and annoying error.

- Start with the return stack, for loops.

- Implemented and tested words for LOOP

= Updated tracing to not crash.


#### Friday morning

- Improved tracing, delegated tracing to run time words.

- Improved design of LOOP

- Improved SEE, distributed tracing, made trace a macro.


#### Saturday morning

- Added .S .R for tracing the stack.

- Fixed issues with LOOP.

- Fixed issues with IF caused by fixing issues with LOOP.



#### Sunday morning

Created token space, shrunk word headers, compiler now compiles into token space.


#### Week off conclusiom

I think the core work needed is done and can now be extended.

The whole experience has been completely interactive from the moment the interpreter first said OK to me.

Did encounter some annoying bugs, rewrote the tracing function a couple of times, cursed the computer.

- Typical stack juggling words implemented.

- Integer maths.

- Interpreter works.

- Compiler works.

- Variables and Constants work.

- Compiler supports fixed loops and conditional code.

- Tracing WORDS works 

- Decompiling WORDS works.

TODO NEXT: Implement below

I expect to do some work filling these gaps in over the next few weekends and some evenings.

- Conditional (indefinite) loop words

- add `<DOES` to fill in the compile time code; this will allow compiler helper words to be written using high level code.  

- Floating point words.

- Strings

- Missing Common and Useful FORTH WORDS

- Local variables

TODO LATER: 

- Profiling words (not too worried about speed presently) since I will use Assembler for anything that seems slow.

- Benchmarks, curious how fast or slow this is.


THEN (over this winter)

- Integrate with a graphics window, using a C library.

- Start writing Moonbugs with it.



-----------------------------------------------------------------------



### Dictionary

A dictionary provides a way to name objects.

The dictionary contains word headers, these contain a pointer to a function and a small amount of data uses as function arguments.

A header has a pointer to the words two functions (runtime and compile time), and space for small quantities of data belonging to the word.

Important point that there are two pointers, for runtime and compile time, as FORTH words are called by the compiler at compile time, to compiler themselves, this is why the compiler loop is small and simple.

Having two pointers will allow for '''FORTH <DOES ''' to be supported.

The dictionary is 'full of holes' for user defined words, spread throughout it.


' WORD     - ( -- word address)

NTH        - ( word address -- token )

ADDR       - ( token -- word address)    


NTH and ADDR provide a way of representing the address of the word in less than 16 bits (its position in the dictionary), rather than 64 bits (the full address)

To make token expansion simple, the dictionary contains fixed size words.

Standard FORTH splits a dictionary into many vocabularies, I am not doing this, the search is sped up based on the first letter of each word rather than doing anything clever.



#### Compiled word

A 'compiled' word is simply a list of tokens, some of which are branch instructions to control the flow.

The header points to a list of tokens in the seperate token space.

Some words take the next token as an inline argument, things like branch addresses and literals.

When a compiled word runs it calls the token interpreter with the address of its tokens.

The token interpeter expands tokens to addresses and calls the words which may also be interpreted or which may be native (primitive) functions.

X15 is the IP pointing at the next token, which can be modified by words, this is persisted in DP.

The word is run to completion by the token interpreter, which returns to the command line.


When typing commands in the outer interpreter command line, and when compiling new words, the token interpreter is NOT even running, the outer interpreter and token compiler are written in Assembler (objecive learn ARM64, not learn FORTH), this provides some benefits to the design.

This makes the token interpeter highly inspectable, I plan to add single stepping for example.


```FORTH
0     [pointer to tokens] (in token space)
8     [word name ]

tokens: (example)

24    [runint]  --> code that runs the interpreter for tokens

32    [token]   <-- small half word sized tokens (16 bits)

00    [token]

02    [token]

04    [#LITS]  <-- LITS is the small literal follows token 
06    [small number]
..    etc

32   [token]
34   [exit]  <- return from word >
``` 

The use of tokens with literal pools is a form of compression for the high level forth code, we do not want to use 64 bits for each word.

The cost is the token lookup see NTH and the token expansion see ADDR.

The token lookup is simplified by the dictionary headers being a fixed size and seperate from the token space.

You can use the decompiler SEE to look at words created by the token compiler.



#### Decompiler

If you are writing a compiler, it helps to see what is going on.

In FORTH the decompiler is traditionally called SEE.

Often it tries to return the source code of the word, not here, I am more interested in what the compiler did, and how each word is layed out in memory, I do have the source of the word already..

```FORTH
: TEST IF 65 EMIT ELSE 66 EMIT ENDIF 67 EMIT ;
 34 half word cells used, compiler Finished
  
Ok
SEE TEST     
SEE WORD :4302952320 TEST        
       0 :4301946144 		^TOKENS 
       8 :4301825740 		PRIM RUN
      16 :       0 		ARGUMENT 2
      24 :       0 		PRIM COMP
      32 :       0 		Extra DATA 1
      40 :       0 		Extra DATA 2
      48 :TEST        		NAME
		TOKEN COMPILED FAST

4301946144 : [     3] (IF)        
4301946146 : [    46] *
4301946148 : [     1] #LITS       
4301946150 : [    65] *
4301946152 : [   547] EMIT        
4301946154 : [     4] (ELSE)      
4301946156 : [    44] *
4301946158 : [     1] #LITS       
4301946160 : [    66] *
4301946162 : [   547] EMIT        
4301946164 : [   546] ENDIF       
4301946166 : [     1] #LITS       
4301946168 : [    67] *
4301946170 : [   547] EMIT        
4301946172 : [     0] (NULL)      
4301946174 : END OF LIST
 


```

SEE displays the words header; and then for high level words, it also looks at the token space the word points at.

As you can see the decompiler is aimed at displaying the tokens layout in memory, geared towards helping me write and test the compiler, rather than re-creating source code.

The compiler lays down things like tokens for branch instructions and instructions to load or fetch literal values.


This shows the word and word type.

A literal is marked with a * 

A token is displayed in brackets.

The name of the word the token represents is displayed.

Tracing the flow

```FORTH
TRON

```


### More primitive

The concept is to write the application in assembler and script/test it

the interpreter is a way to call words written in regular assembler, new words are added to the asm files in assembly.

high level words are collections of word tokens, the tokens are converted to word addresses by the token interpreter, and the word at that address in the dictionary is then called.



#### LITERALs
 
An implementation difference from typical FORTH is that literal values are stored in tables and not stored in the dictionary.

In the token space the word is stored to look up the literal.

This makes the token space simpler, it is made up of 16 bit (half-word) tokens and nothing else.

In theory it should save space since a literal need only be defined once even if many words use it.

It also creates a program wide limit of 64000 instances of each thing.

This will require pools for various primitive types to be added, essentially anything longer than 16 bits needs to have a pool.


Literals

literals are stored inline for small values, and as an index into literal pools for long values.

numeric literals small 
[#lits][short literal]

numeric literals large 
[#litl][index] --------->  literal pool



Long (quad) literals are held in the LITBASE

A compiled dictionary word just refers to the LITBASE using a halfword index

Look up literal N in the LITBASE

```FORTH
LITBASE n 8* + @ .
```

The litbase




## TESTS 

```FORTH
: TESTNEST IF 65 EMIT IF 66 EMIT ELSE 67 EMIT ENDIF ENDIF 68 EMIT ;
```

Test nested IF ELSE ENDIF 

expected 

```FORTH
1 0 TESTNEST => D
1 1 TESTNEST => ABD
0 1 TESTNEST => ACD
0 0 TESTNEST => D
```



### TRACING

If tracing is set TRON each word is traced as it is executed.

```FORTH

: SQ DUP * . ;
 42 half word cells uses, compiler Finished
  
Ok
5 SQ

4296148192 : [   455] DUP         S : [     5] : [     5] : [     0] R : [     0] : [     0] : [     0] 
4296148194 : [  2006] *           S : [    25] : [     0] : [     0] R : [     0] : [     0] : [     0]  25
4296148196 : [  2010] .           S : [     0] : [     0] : [     0] R : [     0] : [     0] : [     0] 
Ok


```

Tracing does add overhead even if switched off.

I plan to switch to either switch to a non tracing code path or simply create a version with 
tracing ripped out.


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


### Compatability

In general WORDS defined in the language should behave as they would in FORTH, unless that behaviour is so annoying, I had to change it.



### LOOP Improvements 

The LOOP control statement in FORTH does confusing things.

In this implentation the DO .. LOOP is designed to do what any reasonable person would expect it to do, before they used FORTH. 

Normal loop

```FORTH
: t0 10 1 DO I . CR LOOP ;
```


Sanity is aided by the addition of DOWNDO (inspired by PASCAL) and -LOOP

Down loop

```FORTH
: t5 1 10 DOWNDO I . CR LOOP ;
```


LOOP gets its sense of direction from DO or DOWNDO.

```FORTH
: t1 10 2 DO I . CR 2 +LOOP ;

: t3 2 10 DOWNDO I . CR 2 -LOOP ;

```

Summary

It is very clear if the LOOP counts up or down, and very obvious if a LOOP should end or not, if it includes the start and finish (it does).
This LOOP is not at all likely to repeat 65536 times (or in this case billions of times ) by mistake.

This is not compatible 

I do not expect to be able to compile ANSI FORTH, nor do I have some large source of ANSI code somewhere I can reuse.

### The Token interpreter

ARM code takes 32 bits, the register lengths are natively 64 bits.

I assume that using 64 bit addresses for an interpreter would pointlessly waste memory and suck away bandwidth, so I am using tokens instead of addresses.

I assume this is also likely to be slower, I have not writen profiling WORDs yet.

An address based interpreter is much smaller, but this is not huge.



```ASM
 
10:		; next token

		.rept 	16
		LDRH  W1, [X15, #2]!

		CMP   W1, #24 ; (END) 
		B.eq  90f

		MADD  X1, X29, X1, X27

		LDR   X2, [X1, #8]
		LDR   X0, [X1]
		CBZ   X2, 10b

		BLR   X2 		; with X0 as data and X1 as address	 

		.endr

		b 		10b
```

Discussion of the token interpreter

This is small enough to discuss.

The main activity repeated for each token is between label 10 and the jump back to 10.

We increment IP, fetch the token,  multiply the token by 64 (the dictionary header), add to the dictionary base, this gets us the word address.

It helps to know that X29 holds the address of the dictionary and X27 is #64 going into MADD.

From that we collect the words code pointer, collect the words data pointer, call the word, the words code runs and returns.

This then repeats until the end of the word, it is a choice to compare the token with END or let END run and exit the function.

Not sure what is best, as no profiling is implemented yet.

The use of a data pointer for each word passed in X0 seems useful, it allows words to run with an argument.

Sending each word its own address in X1 is more general.



## History

## WEEK 47 (of 2021)

Improved tracing of words, added initial word entry to trace.

Formalized X1 as parameter to words, containing the address of current word.

Useful to look up any details stored in the words header.

Added DEPTH to check stack depth, led to a fix of underflow check.

Added depth check to (DOER) avoiding infinite loops when there are not two arguments.


### IF 

Updated to use the return stack during compilation.

IF          ---         ELSE                          --- ENDIF

Stack                 Read Location                   Read location 
Location              Update (IF)                     Update (ELSE)

Seeking around the word, seemed less reliable.

Added the timing words, ran a benchmark, did some work on making the interpreter less slow.




### Timing words

Premature optimization may be the root of all evil.

It is still important to measure your functions, as there are many ways to write the same thing.

Added TIMING words to assess the speed of the application.

These Tests show that the word token interpreter is very slow.

Good, speeding it up will be very interesting.

TIMEIT test1

Will time the word test1.

Timing words provide the ability to experimentally improve the performance of the program.

### Benchmark


```FORTH
// Tests show that the interpreter is very slow.
// Good, speeding it up will be interesting.
// FIB measures the inner interprers call overhead really well.

: FIB ( n -- n1 )
  DUP 1> IF
  1- DUP 1- FIB SWAP FIB + THEN
;

: t1 25 0 DO 34 FIB LOOP ; // run many

 

TIMEIT t1


// 27th November 2021
TIMEIT t1
9781  : ms to run ( 97813  ) ns 

// 29th November 2021 - more reasonable.
FASTER FIB  
FASTER t1
TIMEIT t1
3864  : ms to run ( 38647  ) ns 
 
```

Which may be interesting.


The FIB word is testing procedure call speed, which is a test of looking up token addresses and calling the words in the token interpreter.

Initially the inner interpreter looks something like this :- 


```ASM


runintz:; interpret the list of tokens at X0
		; until (END) #24

		; SAVE IP 

		STP   LR,  X15, [SP, #-16]!

		MOV   X15, X0
 		ADRP  X12, dend@PAGE	
		ADD   X12, X12, dend@PAGEOFF
		SUB   X15, X15, #2
		
10:		; next token
		ADD   X15, X15, #2
		LDRH  W1,  [X15]

		CMP   W1, #24 ; (END) 
		B.eq  90f
 
		LSL   W1, W1, #6	    ;  TOKEN*64 
		ADD   X1, X1, X12     ; + dend
	 
		 
		LDR   X0, [X1]		; words data
		LDR   X1, [X1, #24]	; words code

	 	CBZ   X1, dontcrash
 
		STP   LR,  X12, [SP, #-16]!
		BLR   X1 		
		LDP   LR, X12, [SP], #16	


		CBZ   X6, 10b

		do_trace
		 

dontcrash: ; treat 0 as no-op

		B		10b
90:
		; restore IP
dexitz:		 
		LDP   LR, X15, [SP], #16	
	 
		RET

```


The current version has evolved to look like this, based on tests.


```ASM


runintz:; interpret the list of tokens at X0
		; until (END) #24

		trace_show_word		

		; SAVE IP 
		STP	   LR,  X15, [SP, #-16]!
		SUB	   X15, X0, #2
		
		MOV     X29, #64

		; unrolling the loop here x16 makes this a lot faster,
10:		; next token

		.rept 	16
		LDRH  W1, [X15, #2]!

		CMP   W1, #24 ; (END) 
		B.eq  90f

		MADD  X1, X29, X1, X27

		LDR   X2, [X1, #8]
		LDR   X0, [X1]
		CBZ   X2, 10b

		BLR   X2 		; with X0 as data and X1 as address	 

		
		; this is why we are a little slower.
		do_trace

		.endr

		b 		10b
		  
90:
		LDP   LR, X15, [SP], #16	
		RET


dexitz: ; EXIT
	
	      RET

dexitc: ; EXIT compiles end

		MOV   X0, #5 ; (EXIT)
		STRH  W0, [X15]
		RET




```


This does the same thing, minor changes to placement of instructions impacts the speed of this loop.

I committed two more registers to the loop, one  X29 just to hold the value 64, and one X27 to hold the dictionary address, these speed up the MADD which replaced the shift and add in the first loop, because it was faster.

The major speed increase was unrolling the loop, unrolling the loop 8 times made a significant difference, sixteen times improved a little further, beyond that nothing.

Clearly any branch at all is a performance problem.

I reorganized the dictionary so the two words the interpreter fetches from the word are close to each other, the data word, and code address.

Using a LDP turns out to be slower in tests.

The tracing words, which look at X6 to see if we should print a trace also (being branches) slow down the loop.

I am suspicious that half word access is just slow, and of course expect the token access to be slower than a list of 64 bit addresses would be.

The interpreter is called by high level words.

It is easy to switch the interpreter in a word, I have implemented a fast and tracable version and provided the words FASTER and TRACEABLE to switch between them.

e.g. 

```FORTH
FASTER FIB
```
Tells FIB to now use the fast untracable version, TRACEABLE does the opposite.

The compiler also respects the state of TRON and TROFF, if tracing is on words are compiled as tracable.

The speed difference between FASTER and TRACEABLE is small.

Note the objective here is not to write a fast FIB, but to test the program. 

There is a fast FIB word (FFIB) just to make that point clear.
