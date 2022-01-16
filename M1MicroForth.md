### M1 MICRO FORTH

This FORTH is non standard but should be familiar.

This FORTH is implemented mainly in AARCH64 assembly language (main.asm), and runs hosted under OSX on the Apple M1.

- A few C library functions are used, the program is linked against the C library, it is possible to call C functions (from assembler), which will be useful, in order to talk to the operating system.

- The implementation is specific to features of the ARM V8 64 bit processor, such as wordsizes.

- FORTH primitives are implemented as assembly language functions, the compiler converts high level FORTH words into list of tokens for the token interpreter(s) to execute.

This is not a standard implementation, I am aiming to provide a *very small* set of practical FORTH like words that improve comfort, safety and convenience for the user of the language (such as me.) 

- Throwing in 'everything and the kitchen sink in case it may some day be useful' is contrary to FORTH principles.

- I expect to extend the ASM file as I write my own apps, I plan to test and script my apps in FORTH and assembly language, with C to connect with the OS.


Untyped - Storage has no type, words are only aware of the *size of storage cells* not what they contain.

The syntax follows FORTH closely, including reverse polish notation, composition of new words *(functions)* by word concatenation, very similar control flow constructs etc.

**Inner interpreter**

The compiler compiles words to tokens, which are then executed by a simpler interpreter.

The inner interpreter:-

- is not running all of the time in this implementation.

- only runs when a high level word is executing, otherwise the interpreter and compiler are just running machine code, the interpeter and compiler are not written in FORTH.


Each high level word invokes an interpreter to run itself, multiple different versions of the interpreter(s) exist, and they can be selected after the word has been compiled or while it is being compiled.

I am using a certain ammount of *brute force and ignorance* in the current design of this program, which may not scale, but which works for the moment, in the spirit of getting up and running.  


### Startup

The forth.forth file is loaded when the application starts.

This file should contain any high level FORTH words you want to add to your program.

It is presently set up to clear the screen, and display the words, before entering the interactive session.

### Values

Values are preferred to VARIABLES, as they are much safer to use, and simpler to access.

- A value is created with the VALUE word.

- A value has no type, it could be used to represent an int, float, char etc.

- A value has only a size in bits, the base VALUE is 64 bits.


```FORTH
199 VALUE myvalue
```

A value is read and printed with dot.
```FORTH
myvalue .
```
A value is changed with the TO word
```FORTH
200 TO myvalue
```
The default cell size for values is 8 (64 bits) each element can store a large integer value or a double float, they are untyped other than bit length.

An array of values is created with the VALUES plural word.
```FORTH
128 VALUES myvalues 
```
The VALUES are allotted from pools of memory that are zero filled, so all values will initially read as 0.

To change every value.
```FORTH
1 FILLVALUES myvalues
```
Every entry in myvalues becomes 1.

To change one entry use TO

```FORTH
1000 7 TO myvalues 

7 myvalues .
```

Value entry 7 in myvalues becomes 1000.



### Special values

Some special values are built in.


#### LOCALS and WLOCALS

These are not FORTH standard words.

LOCALS provide each word with eight (64bit) local variables.

- LOCALS is a special array of values of length 8 (0..7) that provide some small local memory storage for each word invocation. 

- LOCALS backing memory is implemented as a stack, allowing about 250 levels of depth.

On entry to a word LOCALS are erased, all values will be read as zero.

- LOCALS cease to exist and are reused when a word ends.


Storage for WLOCALS

- WLOCALS use the same memory as LOCALS providing word sized access (32bits) to 16 (0..15) Values.

- If it is more convenient to have 16 smaller values use WLOCALS instead of LOCALS

- These are both just views over the same 64 bytes of memory in the local memory stack.

To recap locals are recreated between **:** and **;** 

e.g.

```FORTH
: t1 
	127 FILLVALUES WLOCALS 
	// filled the 16 values with 127
	15 WLOCALS 
	14 WLOCALS 
	+ . 
	;
```

Should return 254, every high level word, normally gets its own fresh set of LOCALS when it starts.

They are not normally shareable between words.

After t1 runs type 14 WLOCALS . and it will be zero, the command line level has its own set of LOCALS as well.

There is no need to use LOCALS but if you write a word and think it would be handy to have some where else to briefly store a value that is not a global value or the stack, they serve that purpose.


#### Advanced LOCALS usage

You may have a recursive word that you do not want to eat into the LOCALS stack.

- You can declare that a word is **FLAT** like this.

**FLAT** *word*.

```FORTH
: FIB ( n -- n1 ) [ FLAT FIB ] DUP 1> IF  1- DUP 1- FIB SWAP FIB + THEN ;
```
This makes FIB a very, very, tiny fraction faster, since the LOCALS are not slow.


##### LOCAL Accessor words.

A **FLAT** word has no locals of its own so it sees the locals of its parent word, that is the word that called it, or the command line.

- Using the standard local access can be cumbersome, the name LOCALS does not mean much.

- **FLAT** words can be used to create words for accessing the parents locals, in the simplest case this just lets you give local variables some sensible names.


```FORTH
// allocate a local to our speed.

: set-speed [ FLAT set-speed ]
	0 TO LOCALS ;

: speed [ FLAT speed ] 
	0 LOCALS ; 

: test 
	10 set-speed  
	speed . ;

```

set-speed and speed are working on the LOCALS shared with test.

Accessor words *could* do a lot more, like checking that the given speed is valid etc.

Without **FLAT**, set-speed and speed would each read their own LOCALS a level above test and test would not work.


#### Simple LOCALS access

You can read LOCALS also using some predefined accessors called a..h 
And set them with *n* a..h! 
e.g.

```FORTH
10 a! a .
```
Prints 10.

There is a handy accessor for just counting.

It is much easier and faster to use an incrementing local than to add a counter to the stack and juggle it.

```FORTH 
a++
```

The **a** is set to zero when the word starts, **a++** adds one.

Be mindful that this is just another name for **0 LOCALS.**


### use LOCALS as parameters ###

You can feed up to 8 parameters from the stack into LOCALS with the PARAMS word.

```FORTH
: sq 1 PARAMS a a * ;
```

`1 PARAMS` loads the argument into a.

If there are not enough parameters on the stack this will cause an error.

The LOCALS are available in several way
For example they can be accessed with a .. h

For a word that takes lots of parameters this can be helpful.

The example above really did not need to do this :)

e.g. 

```FORTH 
: sq DUP * ;
```

is much nicer.


This feature is not necessary most of the time, but if you do have more than three arguments it can make life simpler.


#### Self reference

A word can refer to it self in its own definition (recursion) like FIB above.

Also a word has pointers to itself available.

There are two special **LOCAL** variables that allow a word to see it is own address.

These are 

- **CODE^** which points to the words token code.

- **SELF^** which points to the words dictionary header.

In a **FLAT** word, these usefully both point at the parent words CODE and HEADER.

An odd way to make a word repeat itself is to do this.

```FORTH
CODE^ 2 - IP! 
```

Using a flat word we can use this information to create a new control flow word.

```FORTH
: TAIL [ FLAT TAIL ] CODE^ 2 - IP! ;
```

- This sets the instruction pointer to just above the parent words code.

- The interpreters next step will be to start running the parent word again from the top.


SELF^ may be more useful, as a word can use it to look inside its own dictionary header.

A word can print its own name for example with 

```FORTH
SELF^ 48 + $. 
```

Again a new flat word could be created to print its parents name

```FORTH

48 ADDS >NAME

: .name [ FLAT .name ] SELF^ >NAME $. ;

```

These two values are stored on the LOCALS stack, below the locals.


#### TOKENS

Is a VALUES view over the HW (half/word 16 bit) token space, this is where the compiler stores tokens for words it compiles.

#### LITERALS

Is a VALUES view over the (64 bit) long literal space, where large integers, double floats and addresses are stored by the compiler.


### Strings 

Strings are non standard.

Strings are zero-terminated because that is the world we have lived in ever since UNIX was invented. To emphasize the *very major* differences, string literals here use single quotes.


A string is created with an initial text value like this.
```FORTH
' This is my initial value '  STRING myString
```
A string returns the address of its data.

```FORTH
myString $. 
```
Given the address $. will print the string.

```FORTH

$'' STRING myEmptyString 

```

Is how to create an initially empty string.


- A string should not normally be mutated, each unique string exists only once in the string pool, changing one would impact all usages everywhere in a program.

- Strings can be compared with $= and $== which check if they are same and $COMPARE wich checks if one is equal, greater, or less than the other.

-  In terms of storage the strings content is stored in the string pool with all the rest, the STRING word just points to the storage and gives it a name.

Just as you can create a STRING you can also create a number of strings.

```FORTH
10 STRINGS myStrings
```

Will create 10 strings.

To set the value of a string you use TO, e.g.

```FORTH
' string zero ' 0 TO myStrings

Ok
0 myStrings $.
string zero 
```

0 myStrings returns the address of the 0th string.

$. is a word that prints a string.

The storage for the strings text lives in the string pool a STRING word just points a name at it.


### Little defining words

- As this is an interpeter it is almost always slower to use two words when one word will do.

- It is also faster if each word *does more*, the overhead of the interpreter is calling each word in the first place.


The compiler also *does not optimize*, so it is often up to the programmer to choose to use a faster optimal word not up to the compiler to invent them on the fly.

A good example is that `1 + ` is slower than `1+` so if your word does `1 +` millions of times, this will have a performance impact.

For this reason FORTH interpreters often come with dozens of little optimized words.

The approach in this implementation is to provide a few words for defining those little words, so you can define the words your specific program actually benefits from.

Shifting left and right

You can define words that perform left and right shifts for faster multiplication and division.

```FORTH
3 SHIFTSL 8*
```
Defines the new word 8* that SHIFTS the top of stack left 3 times, effectively multiplying by 8.  SHIFTSR is the opposite word that does division.


```FORTH
1 ADDS 1+
```

Defines a fast little word for adding 1 to the top of the stack, the opposite word is SUBS.

Take a look though your app and if you find some common patterns, define some of these to speed it up.



### Appending/building strings

Often a string needs to be built from smaller parts

These words are meant to help make it less error prone.

```FORTH

${ ' ${ starts ' , ' appending ' , ' $} finishes ' , $} $.  

```

The string is composed between the ${ Start building and $} end building words.

Each element of text is added by the comma that follows after it.

At the end the combined text is stored and its address is returned, so it can be named.


```FORTH

${ ' ${ starts ' , ' appending ' , ' $} finishes ' , $} 
STRING appender 

```

In line with general FORTH principles the , is a word not a separator, and comes after the text being appended.  The single quote is a word and must be followed by a space. This reads text until the next single quote.


### Slicing a string

```FORTH 

' this is the age of the train' 23 5 $slice $. 

```
Prints 'train'

Slicing uses a slice buffer, and the string pool for storage.

To avoid cluttering the string pool with never to be collected slices you can use the appender function.

To save the result from a slice send it somewhere, such as to a STRING e.g. 

```FORTH 
$'' STRING vehicle
' this is the age of the train' 23 5 $slice 
TO vehicle
```

Slices can be appended to a string with $slice followed by a comma inside of an append list.


```FORTH 

' British Rail in the 1970s ' STRING br
' This is the age of the train ' STRING trains
// taking a slice in the appender.
${ 
    ' Back ' ,
    br 13 13 $slice ,
    br 0 8 $slice ,
    ' said it was "' ,   
    trains 8 10 $slice ,
    ' " the "' ,
    trains 23 5 $slice , ' " - yeah right.' , 
$}
$.
```

Example of appending with $slice between ${ and $}.

This has the advantage of not spewing garbage into the string pool when interpeting.
Although if compiled the strings still need to live somewhere.

 

#### Storage used when appending

The BUFFER$ and APPEND$ storage is used while appending.

When used in the interpreter, only the final result is placed in the string pool, the literals being available from the interpreted text.

When used in the compiler any literal text parts have to be stored in the string pool (since these also need somewhere to live.)

While building (appending) strings, APPENDER^ points to the next byte address.



### Stacks

FORTH has a parameter (or data) stack; used for evaluating expressions, and passing arguments to words.  This has a rich set of words that operate on it, such as SWAP, ROT, OVER, PICK etc.

There is also a return stack that is used in this implementation for some of the control flow constructs, for various loops, exposed by the R> >R words.

There is a hardly visible stack used for the local variables made available to each word.

#### Stack values

We also have stack values, these are extremely simple, and only allow values to be pushed or popped. There are none of the features of the main parameter stack.

Like most stacks, the last thing added is the first thing removed LIFO (last in first out)

To declare a user stack just use the STACK creation word.

```FORTH

\\ create a stack of file handles, of depth 18.

18 STACK file_handles

\\ add some values

0 TO file_handles 
1 TO file_handles
2 TO file_handles

\\ remove and print the values

file_handles .

2

```

- To take a value from a STACK just use its name, the value on the top of the stack is read.

- To push a value use the TO word, with just the value to push.

- The storage of a stack is taken from the ALLOTMENT and is all zeros.

- A STACK resembles a VALUES object, but maintains a reference internaly to the last item pushed.

file handles are a good use case, when opening a file, push the file handle, when closing the file, pop the file handle.


### Floating point support

Floating point words begin with f e.g. f.

Numbers containing a decimal point . are taken to be floating point numbers.

The same parameter stack is used, which may hold 64 bit (double) floats or 64 bit (quad) integers.

A small set of floating point operations are implemented, typical comparison and math operations that the CPU directly supports are found starting with f, such as f+ and f.

e.g. 
```FORTH
22.0 7.0 f/ f.
```

#### LOOPS

Most of the LOOPing words, only work inside a compiled word definition between **:** and **;**

##### Non Standard Looping in the interpreter

A loop that works anywhere is the very simple n TIMESDO *word* loop.

```FORTH 

: DOT-DASH CHAR . EMIT CHAR - EMIT ;

\\ TIMESDO works in the interpreter

32 TIMESDO DOT-DASH
.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-
Ok

```

n TIMESDO  - executes the word that follows it, n times.

It is simpler than other LOOPS and less powerful, it is also faster at doing the simple thing it does.

It also works in a compiled word e.g. 

```FORTH 

\\ Also works in a compiled word.

: DASHED-LINE CR 32 TIMESDO DOT-DASH CR ;

```


#### Compiled Loops

These loops work only inside of compiled words.

DO LOOP counts between Finish and Start 

A LOOP can be nested and has an index value *accessed by depth* called I, J, K.


```FORTH

: RECT 255 0 DO I 16 MOD 0= IF  CR  THEN .' *' LOOP ;

: TABLE  CR 11 1 DO  11 1 DO  I J *  .  SPACE LOOP CR LOOP ;

```



#### Loop limitations

- I, J, K work within a word, but NOT across words.
- LEAVE is supported ONCE in a word inside loops.
- You can not have multiple LEAVES.
- Partly because multiple loop termination is a garbage idea anyway.
  - But mainly because it is horrible to code.


#### Recursion

Recusion is always an option for loops as well.

Just call yourself in a word, a word knows its own name.

Recursion uses space on the machine code stack and (typically) on the locals stack.

**Iteration**

Any repeating word can also be expressed using **BEGIN** .. **EXIT** .. **AGAIN**  

### Input and output.

The IO is presently set for the UNIX terminal.

The interpreter accepts lines from the terminal, with buffering, the input is often STDIN, although the input can sometimes be a file, as it is at startup.

The various printing words, `. $. f. .' hey'` etc print to STDOUT, and they buffer for terminal efficiency.

- 
  KEY - reads a user key press from STDIN

- EMIT - writes the char to STDOUT, without delay.

- KEY really needs NOECHO to be set
  - After using NOECHO use RETERM to return the terminal to its normal state.
- KEY? returns true if a key is pending, it can be used in a LOOP like this.
- FLUSH - flushes output.


```FORTH
: .keys 
  NOECHO 
  BEGIN 
	 	KEY? IF
		  KEY DUP DUP EMIT CHAR = 
		  EMIT . 32 EMIT FLUSH 
		  81 = IF RETERM EXIT THEN
		THEN 
		100 MS 
	AGAIN
 ;
```

*This will display key pressed and its multiple ASCII value(s).*

Terminals accept a wide variety of commands.

FORTH typically only implements `PAGE` to clear the screen and `AT-XY` to place the cursor.


The input normally just uses UNIX getline, which is not very nice from a user perspective, but doed have the advantage that is redirectable to a file.
So loading a file is the same as just opening it and running the interpreter loop.

You can load another file with FLOAD filename (from the ok prompt)

##### Line input

You can accept a line of text from the user with ACCEPT e.g.

```FORTH

\\ Empty String
$'' STRING myInput

Ok
ACCEPT TO myInput
Test this then <- Typed in 

Ok
myInput $.
Test this then
```
Exciting interactions become possible

```FORTH
$'' STRING yourName
: ask-name? .' What is your name ? ' 
 CR ACCEPT TO yourName 
 CR .' Hello :' yourName $. ;


ask-name?
What is your name ? 
Alban

Hello :Alban


```


#### Thoughts

- Having the interpreter and token compiler implemented in assembly language does provide some benefits, such as testing the token compiled code, since the interpeter is not made out of the same token compiled code being tested.

- The interpreter in assembler, also means it is not as open to high level FORTH as it would be if it was written in FORTH.

- High level FORTH does have a lot of access to the system still, various interrnal objects are also exposed as VALUES to FORTH.

- The implementation misses some of the self-extending awesome powers of standard FORTH.
  - The various compile time words are frozen forever (until you edit them) in the assembly language file.
- Hiding the gubbins, gizards, and guts of the interpreter in the ASM file, offers the possibility of providing users with useful and safe words with which to write applications.



### Performance

This implementation is using a simple token interpreter that is mostly written in assembly language.

I have paid some attention to the performance of the inner loop, it is easy to test as you can try out different versions and time the results.

I chose to use 16bit tokens to represent words, rather than 64 bit addresses, the addresses would probably be faster, but that would be a different implementation, as lots of words are tuned for the token memory layout. 64 bit addresses felt.. wastefull ..  

Forth words typically use dozens of tokens, very large words may use a few hundred.

It is a simple interpreter but FORTH is also a simple and lean language.

The relationship appears much the same as ever, simple interpreters are 10 times slower,
Simple machine code is ten or more times faster, optimized machine code is 100 or many more times faster if you can tap into the huge and increasingly complex capabilities of the CPU and GPU..

There are commercial FORTH compilers that generate code that is closer in speed to machine code.


### C integration

The intention is to write as much as reasonbly possible in Assembler.

- The assembler code can call into C code and does so for a few functions.
- This is necessary otherwise using only system calls would be limiting even in the terminal.
- You can add C functions to addons.c and call them from your assembler code.
- Some existing use of C will be replaced with assembler over time.

Over time I have added a bit more C code to the project, and used more c functions.

Writing C code is not always easier than writing assembler.



### Interactivity

FORTH (like BASIC and LISP) is an interactive experience.  

This interactivity is what makes it fun (in my experience.)

### Development notes and implementation

I started this in November 2021, with a reasonable recollection of how FORTH works, no experience with AARCH64 (although I do like ARM32) and a blank screen in Visual Code.

I have not based this on any particular FORTH design template, so it has some original ideas, for good or ill, although it is essentially the same.

I wanted to get some practice in with the ARM64 so I wrote this in assembler,  FORTH is allegedly written in FORTH normally.

First thing I did was get the outer interpreter to work, that is the interpreter that recognizes the difference between a word and a number, pushes a number to the stack and calls a word.

This gave me an interactive experience straight away, so I could test each new word I added.

I then added a bunch of standard FORTH words, and tested them.

The outer interpreter in FORTH is very simple, all it does is read words from the input, where a word is just something followed by a space, it then needs to find the word in a dictionary, check if it is a number or print an error.

The FORTH dictionary is a collection of WORDS, usually several lists of WORDS, to keep things simple I created a dictionary that was really just a fixed size array of word headers.

I decided initially to store everything in these headers, I created dictionary words that were 128 bytes in length, to give me room for (very) small compiled words. Later I added TOKENS space for words to store tokens, and the ALLOTMENT for data.

I decided to use tokens to look up words in the dictionary, a token is essentially an index into the dictionary.

The compiler is just like the interpreter but instead of recognizing and running words, it recognizes words, and stores the token for each word in the compiled word.

Right away this allows the compilation of straightline words like square 

```FORTH
: sq DUP * ;
```

In order to see what the compiler was doing, I implemented SEE.

```FORTH
SEE sq
SEE WORD :4375017216 sq          
       0 :4370506944 		^TOKENS 
       8 :4370320908 		PRIM RUN   
      16 :       0 		ARGUMENT 2
      24 :       0 		PRIM COMP
      32 :       0 		Extra DATA 1
      40 :       0 		Extra DATA 2
      48 :sq          		NAME
		TOKEN COMPILED FAST

4370506944 : [        1373] DUP         
4370506946 : [        7732] *           
4370506948 : END OF LIST

```

In this implementation a compiled word is just a list of tokens.

The PRIM RUN for a compiled word, is the address of an interpreter that knows how to handle the list of tokens.

1373 happens to be the TOKEN for DUP at the moment.

```FORTH
` DUP NTH .
1373
Ok

```

The word NTH looks up a TOKEN given a words ADDRESS, I use backtick rather than ' because I use ' for text strings.

To begin with I compiled TOKENS right into the word, later I added the separate TOKENS space, and shrunk the dictionary elements to just be the current header and data elements, 64 bytes.

As SEE shows a word in the dictionary has a PRIM RUN, that is pointer to a function that executes at run time.

This is what the outer interpreter calls, and what the compiler tokenises into a word.

Every word also has a PRIM COMP pointer, these are primitive functions that are *called by the compiler when it is compiling that word.

The FORTH compiler is very simple and small, and can be built up over time because it calls lots of little helper words.

Although this implementation only uses native code primitive words in the compiler, the overall pattern is the same as other FORTH versions, words are expected to help compile themselves.

Something has to run the 'compiled' code, the secret is that every-thing a computer runs is machine code, and anything else is just data.

The thing that runs the code is the *inner interpreter*, faced with a list of TOKENS its only job is to find the machine code, and call it.

There are many ways to implement this, I settled on something simple:-

```assembly

10:	; next token
	
	.rept	16

		LDRH	W1, [X15, #2]!
		CBZ		W1, 90f
		LSL 	W1, W1, #6
		
		ADD		X1, X1, X27
		LDP		X0, X2, [X1]
		CBZ		X2, 10b
	
		BLR		X2		; with X0 as data and X1 as address	
 
	.endr

	b		10b

```

X15 is the IP, interpreter pointer.

This inner most part of the inner interpreter turns tokens back into addresses and calls the code at the address.

I keep the start of the dictionary in X27, and this code just multiplies the TOKEN by the dictionary element size.

I decided to pass the data pointer and the address of the word in the dictionary to each word.

This allows words to look themselves up easilly, and work on their own data.

The essential simplicity of FORTH is given this, you can then incrementally add and test the rest of the language by creating new words.

Note that the loop ends when it encounters 0,  Zero is also the TOKEN for the word (EXIT) which is also the first word in the dictionary.

### Adding IF

A major challenge with any programming language is that IF *can not just be a function*, it has to choose at runtime which path to follow.

```FORTH
SEE IF     
SEE WORD :4374851456 IF          
       0 :       0 		^TOKENS 
       8 :4370318884 		PRIM RUN
      16 :       0 		ARGUMENT 2
      24 :4370318892 		PRIM COMP
      32 :       0 		Extra DATA 1
      40 :       0 		Extra DATA 2
      48 :IF          		NAME
```

IF seen here has no tokens or data, it has a PRIM run and PRIM comp.

At the OK prompt type IF.

```FORTH
IF

Error: use of some words not allowed outside of definitions.
Ok

```

What you see here is what the PRIM RUN function does, it lets you know that you can only use IF inside a colon definition.

IF also has a PRIM COMP, and that code runs when the compiler sees IF.

Example of using IF

```FORTH
: t1 NOECHO 
     BEGIN 
	 	KEY? IF
		  KEY DUP DUP EMIT CHAR = EMIT . 32 EMIT FLUSH 
		  81 = IF RETERM EXIT THEN
		THEN 
		100 MS 
	AGAIN
 ;
```

This code checks if a key is pressed, and if it is pressed, displays it.

There are two IF statements, one is nested inside the other.

In FORTH an IF statement looks like 

```FORTH 
 f IF .. ELSE .. THEN 
```

Where f  means flag, this reads as IF the flag is true do this ELSE do that THEN carry on with the rest of the word.

SEE shows there is a lot of code

```FORTH
SEE t1
SEE WORD :4375034688 t1          
       0 :4370506952 		^TOKENS 
       8 :4370320908 		PRIM RUN
      16 :       0 		ARGUMENT 2
      24 :       0 		PRIM COMP
      32 :       0 		Extra DATA 1
      40 :       0 		Extra DATA 2
      48 :t1          		NAME
		TOKEN COMPILED FAST

4370506952 : [        4015] NOECHO      
4370506954 : [         840] BEGIN       
4370506956 : [        3232] KEY?        
4370506958 : [           3] (IF)        
4370506960 : [          78] *
4370506962 : [        3233] KEY         
4370506964 : [        1373] DUP         
4370506966 : [        1373] DUP         
4370506968 : [        1638] EMIT        
4370506970 : [           1] (LITS)      
4370506972 : [          61] *
4370506974 : [        1638] EMIT        
4370506976 : [        7736] .           
4370506978 : [           1] (LITS)      
4370506980 : [          32] *
4370506982 : [        1638] EMIT        
4370506984 : [        1930] FLUSH       
4370506986 : [           1] (LITS)      
4370506988 : [          81] *
4370506990 : [        7751] =           
4370506992 : [           3] (IF)        
4370506994 : [          42] *
4370506996 : [        5052] RETERM      
4370506998 : [        1639] EXIT        
4370507000 : [        5595] THEN        
4370507002 : [        5595] THEN        
4370507004 : [           1] (LITS)      
4370507006 : [         100] *
4370507008 : [        3755] MS          
4370507010 : [         576] AGAIN       
4370507012 : END OF LIST

```

What **IF** does at compile time is compile **(IF)** Token #3, followed by a number that is used to skip quickly to the matching **THEN**.

When the word runs **(IF)** checks the flag (top of stack), if it is not true it causes the instruction pointer (IP, X15) to skip to **THEN**.

So at compile time **IF** **ELSE** and **THEN**, create the logic in the word, at runtime, **(IF)** and **(ELSE)** executes the logic.

**THEN** literally does nothing at all at runtime, at compile time **THEN** does all the work to fixe up the branches for **IF** and **ELSE**.

Other than that **THEN** just helps us see where each **IF** ends.

**IF** essentially compiles a branch, that is based on conditionally changing the address of the next instruction to be run by the inner interpreter. 

**THEN** works out the address for **IF** to use.

The code for **(IF)** 

```assembly
; if top of stack is zero branch
dzbranchz:
	do_trace
	
dzbranchz_notrace:

	LDR		X1, [X16, #-8]!
	CBNZ	X1, 90f

; it is zero, branch forwards n tokens		
80:
	LDRH	W0, [X15, #2]	; offset to endif
	SUB		W0, W0, #32		;
	SUB		X0, X0, #2
	ADD		X15, X15, X0	; change IP
	RET

90:	
	ADD		X15, X15, #2	; skip offset
	RET  

```

**(IF)** Just checks the top of the stack and branches forward if it is zero (not true.)

It does this by changing the value of X15, which is the IP in the inner loop (above.)

**(IF)** reads the offset from the next token half word, and adds it to the IP, or just skips the token and continues.

There are a few other words defined that read the next token and use it as an argument.

These can be seen in the dictionary as the first 16 words, 0-15, not all are used.

```FORTH
    ; words that can take *inline* literals as arguments
		makeword "(END)", dexitz, 0,  0					; 0 - never runs
		makeword "(LITS)",  dlitz, dlitc,  0			; 1
		makeword "(LITL)",  dlitlz, dlitlc,  0			; 2
		makeword "(IF)", 	dzbranchz, 0,  0			; 3
		makeword "(ELSE)", dbranchz, 0,  0				; 4
		makeword "(5)", 0, 0,  0						; 5
		makeword "(6)", 0, 0,  0						; 6
		makeword "(7)", 0, 0,  0						; 7
		makeword "(8)", 0, 0,  0						; 8
		makeword "(WHILE)", dwhilez, 0,  0				; 9
		makeword "($S)",  dslitSz, 0,  0				; 10
		makeword "($L)",  dslitLz, 0,  0				; 11
		makeword "(.')", dslitSzdot, 0,  0				; 12
		makeword "(LEAVE)", dleavez, 0,  0				; 13
		makeword "(14)", 0, 0,  0						; 14
		makeword "(15)", 0, 0,  0						; 15

```

All the words enclosed in round brackets are used by the compiler, just like IF compiled in the (IF) token #3.

The first 16 tokens are reserved for words that take the next token after them as an argument.

All the round bracketed words are at a fixed position in the dictionary, the compiler, uses their unchanging token numbers.

The compiler itself has no idea what an IF statement, a DO .. LOOP or a BEGIN .. UNTIL loop actually are.

The compiler just knows that it needs to call any compile time functions when it finds them in a word, and the words all take care of themselves.

**What is the compiler?**

The compiler is another loop that runs inside of the interpreter loop, it compiles in the tokens for any words with a run time action, and it runs the words with compile time actions.  It also compiles in any literal values.

**Literal values**

When the compiler sees a number, it converts that into a literal value, which involves compiling in (LITS) or (LITL) depending on the size of the value, values that fit into a token (half word) slot are short, longer values are looked up in the longlits space.

A short literal

``` FORTH
: lits 989 . ;

SEE lits
..
		TOKEN COMPILED FAST

4370507016 : [           1] (LITS)      
4370507018 : [         989] *
4370507020 : [        7736] .   
```

Here we can literally see the literal in the tokens.

A long literal (could be a large number, a string or a float)

Here we have a word that prints a float.

```FORTH
: litl 3.13459 f. ;  
SEE litl
..
4370507026 : [           2] (LITL)      
4370507028 : [          12] *: [4614240887977997050] 
4370507030 : [        1909] f.          
4370507032 : END OF LIST

```

What is compiled into the word after (LITL) is just the index (12) in the LITERALS pool where this float is stored.

The same logic applies to large numbers, floats and strings etc.

Literals are stored in LITERALS.

``` FORTH
12 LITERALS f.
3.13
```

That entry was created for the word above.

Compiling in literals is literally the only clever thing the compiler does by itself, the rest is all defined in the words that compile themselves.

**Example printing a string**

Since there is also a pool for text strings, some string statements can just create an index into that.

The word **.'** compiles in **(.')** which is one of the words that takes the next token.

```FORTH
: hey-jude .' Hey Jude!' ;

SEE hey-jude 
..
4305626304 : [          12] (.')        
4305626306 : [        3584] *
4305626308 : END OF LIST
```

The STRINGS pool can be accessed using $$. 

A few words compile in literals, a function exists for that called **longlitit.**

```assembly

longlitit: ; COMPILE X0 into word as short or long lit

	; X0 is our literal 
	STP		X1, X3, [SP, #-16]!
	STP		X2, X4, [SP, #-16]!
	; halfword numbers ~32k
	MOV		X3, #4000
	LSL		X3, X3, #3  
	MOV		X1, x0
	CMP		X0, X3 
	B.gt	25f  ; too big to be

	MOV		X0, #1 ; #LITS
	STRH	W0, [X15]
	ADD		X15, X15, #2
	STRH	W1, [X15]	; value

	; short literal done
 	LDP		X2, X4, [SP], #16	
	LDP		X1, X3, [SP], #16	
	RET

25:	; long word
	; we need to find or create this in the literal pool.

	ADRP	X1, quadlits@PAGE	
	ADD		X1, X1, quadlits@PAGEOFF
	MOV		X3, XZR

10:
	LDR		X2, [X1]
	CMP		X2, X0
	B.eq	80f

	CMP		X2, #-1  
	B.eq	70f
	CMP		X2, #-2 ; end of pool ERROR  
	B.eq	exit_compiler_pool_full ; TODO: test
	ADD		X3, X3, #1
	ADD		X1, X1, #8
	B		10b	

70:
	; literal not present 
	; free slot found, store lit and return value

	STR		X0, [X1]
	MOV		X0, #2 ; #LITL
	STRH	W0, [X15]
	ADD		X15, X15, #2
	STRH	W3, [X15]	; value = index

	; long literal created and stored
	LDP		X2, X4, [SP], #16	
	LDP		X1, X3, [SP], #16	
	RET

80:
	; found the literal
	MOV		X0, #2 ; #LITL
	STRH	W0, [X15]
	ADD		X15, X15, #2
	MOV		X1, X3
	STRH	W1, [X15]	; value = index

	LDP		X2, X4, [SP], #16	
	LDP		X1, X3, [SP], #16	

	;LDP		LR, X0, [SP], #16
	RET

```



##### Optimization

There is no optimization by this compiler, the words that compile themselves can do some *specialization*, they can choose a more generic or a more specific function to fit the data they are working on, **TO** for example is a word that does this.

The compiler does nothing at all to look at expressions and implement them in an optimized way, it is as dumb as a rock.

It would be nice to add an **OPTIMIZE** word, that takes a TOKEN compiled word and just translates it to the simplest possible machine code, that would also be a good way of learning some of the nitty gritty detail of the ARM instruction set.

Although a dumb machine code word would probably be ten times faster at branches, you need to get into inlining code and analyzing the flow of data to and from the stack for FORTH to become very fast. 

MPE have commercial Forth products that produce fast code.


## Dictionary

FORTH words are stored in the dictionary.

Word names may be up to 15 characters in length.

FORTH names were originally only five characters in length, I thought eight might do, but later made the interpreter check both fields, which allows for 15 letters.

This is handy as I also decided to make words starting with _ private.

That just means they are hidden when listed.

The idea is to make words that only used to implement another word private.

You can also ALIAS words, which just means naming them with a different name.


------



### Glossary of user words (under development)

*List WORDS with WORDS, and look at the source code.*


>NAME >DATA2 >DATA1 >COMP >ARG2 >RUN 

Move to fields within a words dictionary entry.

e.g. ` DUP >NAME $.  prints the name of DUP, which is DUP


*:* 

Creates a new word 
e.g.
```FORTH
: SQ DUP * ;
```

*::* 

Redefines a word

e.g. 
```FORTH
:: SQ DUP * . ;
```
Will redefine an existing word created with : to have a new behaviour.

The new behaviour will apply to all existing words that call the redefined word.

The key point being the new word has the same TOKEN CODE as the old word that it over writes.



**ADDS** 

7 ADDS 7+ 

Create a word 7+ that adds 7 to the value on the stack.

**ALIAS**

Names a word with an additional ALIAS name

e.g. ALIAS ten 10

ten is now 10.

Using ALIAS a single word (or number) is aliased with a new name.
You can UNALIAS ten and ten will be undefined again.

ALIAS is just a *magic trick* that provides a new additional name for an existing word.

It does not create anything real in the dictionary and can not be used with a string literal for example.

CLRALIAS clears ALL ALIASes

Use .ALIAS to list all the aliases, they do not show up as WORDS in the dictionary.


**APPEND$** 

Storage used when appending by the string builder.

**APPEND^** 

Not zero if strings are being appended.

**ALLWORDS**

Lists all words, user and compiler words.

**ALLOT>**  

0 VARIABLE this_variable 
n ALLOT> this_variable

Adds n bytes of storage to a variable created earlier

**ALLOT**

0 VARIABLE room 200 ALLOT

Adds n bytes of storage to the LAST word created

**~~ALLOTMENT**~~ 

~~A view over the ALLOTMENT space, used to add data space to words.~~

**ARRAY**

n ARRAY myArray

Creates an ARRAY of size n 64bit words.

Sizes for ARRAY elements are defined by the name.

| Array Creator word | Size    |
| ------------------ | ------- |
| ARRAY              | 64 bits |
| WARRAY             | 32 bits |
| HWARRAY            | 16 bits |
| CARRAY             | 8 bits  |

**ADDR** 

If you have the token number (16bits) for a word
This calculates the address.

This is a similar function that is used by the inner interpreter.

**ACCEPT**

Gets a line from the user and interns it as a string, returning its address.

**AGAIN** 

Last part of a never ending indefinite loop in a compiled word.

e.g. BEGIN ... AGAIN will repeat forever unless something invokes EXIT.



**ABS** 

A maths function, applied to the top value on the stack.

**AND** 

A logical functon applied to the top two values on the stack.

**~~BEQUIET**~~

~~Stop saying OK all the time.~~

**ALLWORDS**

Lists all the public words, including words no one in their right mind should use.

**a++**

A local word that increments 0 LOCALS by 1. 

A super easy way to create a counter, since a is set to zero when a word starts, and this adds one to it.

*A disgraceful and shameful way to avoid the insane stack juggling we should cherish.*

The value is returned by **a** or 0 LOCALS.

**a** .. **h** exist as accessor words for 0 .. 7 LOCALS.

**AT**

Moves the cursor to a position on the terminal, great for video games, (from the 1970s.)

```FORTH
10 10 AT MSTR
```

Shame the unicode consortium are so *relentlessly boring in their mission* or we could have more fun in our terminals.



**BEGIN** 

The start of an indefinite loop in a compiled word.


Converts the token for a word to its address (see NTH)

**BUFFER$**

A storage space used by STRINGs

**BREAK**

Sends a break signal, that should result in a low level debugger or a crash.
Hazardous

**CHAR**

CHAR A .

Converts an ASCII letter to a number 
That prints 65.

**CARRAY** 

Like ARRAY one byte wide.
See ARRAY

**CVALUES**

Like VALUES one byte wide.
See VALUES

**C@** 

Reads one byte of memory from the address on the top of the stack.
Potential hazard. Use VALUES instead.

**C!**

Stores one byte of memory.
Potential hazard. 


**CLRALIAS**

CLEARS all ALIAS 

**CONSTANT** 

3.14159265359   CONSTANT PI

An alias for VALUE that expresses a promise to never use TO.

See VALUE.

Nothing is immutable but lets pretend.

**CPY** ( src dest -- src1 dest1 )

COPY 8 bytes from src to dest and increments src and dest by 8.

Can be used to create a fast copying word.

Hazardous, only copy memory you own.

**CCPY** ( src dest -- src1 dest1 )

Short for CPY CPY copies 16 bytes increments src and dest by 16.

**CREATE** 

Used to create a word header in the dictionary.
Not often used. Used a lot in standard FORTH.

**CR** 

Print a carriage return and line feed
Moving the cursor down and to the left hand start of the next line.

**DO**

Part of a compiled definite loop.

**DOWNDO**

Part of a descending definite loop.

**DUP**

Duplicates the top value on the stack.

**DDUP**

DUP and then DUP again, like DUP DUP and not like 2DUP.

**DROP**

Drops the top value on the stack.

**DDROP**

DROP and then DROP again, the same as 2DROP, but I like it.

**DEPTH** 

Returns the depth of the stack.

**EXECUTE**

Calls the words function, using the address at the top of the stack.

**ELSE**

Part of a compiled IF .. ELSE .. THEN control flow.

**ENDIF** 

Another name for THEN 

Part of a compiled IF .. ELSE .. ENDIF control flow.

**EMIT**

Prints the charachter that is the top value on the stack.

**EXIT**

Exits the current word, part of a compiled word.
Also used to crash if you are in the interpreter, as you can not execute that.

The F section lots of floating point maths words.

**FFIB** 

Calculates a FIB quickly, instead of being a benchmark.

**FASTER** 

Used to make a word run FASTER, the default interpreter.

**FLAT** 

Used to create LOCALS access words.

See LOCALS section.

**FALSE** 

Not TRUE, 0 in particular.



**FILLVALUES** 

Used to set all the elements in a VALUES to a value.

**FILLARRAY**

Used to set all the elements in an ARRAY to a value.

**FILL** 

A dangerouse but fast memory block filling word.
A potential hazard.
Copyrighted by ARM, Released as BSD licensed so at least no one will be sued when they accidentally write the same nice but still obvious code.

**FREE**

Dangerous word that frees memmory given a pointer as an argument.



**Floating point**

f<> f= f>=0 f<0 f<= f>= f< f> f. f+ f- f* f/ fsqrt fneg fabs s>f f>s 

Mainly the ARM floating point instructions.

**FFIB** 

Machine code FIB.

**FORGET** 

Forgets the LAST word created.

Handy if you just made a mistake and want to start a word over.

In standard FORTH, FORGET forgets all the words created after the word being forgotten, this is not the case in this implementation, only one word is removed by FORGET, and it is normally the LAST one you created.

The words header is removed, dynamic memory used by the word is reclaimed.

You can delete *any specific word* by making it LAST then forgetting it.

myword >LAST FORGET

If you just want to change a word, consider just redefining the word instead with :: 
 


**FINAL^** 

The final word in the dictionary

**FINDLIT** 

Find the literal 

**FILLVALUES** 

Fill a values

**FILLARRAY** 

Fill an array

**FILL** 

Fill a block of memory, hazardous.

**FLUSH** 

Flush output to the terminal

**HEAP**

Allocates some MALLOCed memory and leaves the address in HEAP^

Useful to set up various essential areas during startup.

Generally useful if you need a large lump of memory.

Memory is not initialized, FILL can help with that.

**HWARRAY**

This creates an array of Half Words, 16 bit values.
See ARRAY

**HWVALUES**

This creates a VALUES of Half Words, 16 bit values.
See VALUES

**HW!**

Used to dangerously store half words in memory.
A potential hazard.

**HW@**

Used to dangerously read half words from memory.

**HW@IP**

A word of limited use, that reads the token of the word under the instruction pointer, mainly useless as it typically reads itself.
Hazardous

**IP@** 

Returns the current value of the instruction pointer
May be useful when debugging a word.
Hazardous.

**IP!** 

Sets the current value of the instruction pointer.
May be useful when debugging a word.
Hazardous

**IP+**
Hazardous

**IN** 

The file we are reading from, probably STDIN most of the time.

**I** 

The index for the current LOOP in a compiled word.

This is an index into a relative position on the return stack.

I means the index of the current LOOP I am in.

If a LOOP is nested you can also use J to get the value of the parents LOOP.

And if you are nested again, you can use K to the value of the grandparents LOOP.

Its all relative.

**IF**

Part of f IF .. ELSE .. THEN in a compiled word.

```FORTH
: DoYou? 
  .' Do you like Forth '                 
  ' yes' ACCEPT $contains
  IF .' Good ' ELSE .' So sorry ' THEN ;
```

**INVERT**

Inverts the bits in the value on the top of the stack.

**IN**

The input file

**LAST**

The last word created, this is the only word we can FORGET without saying Bye.

It is the word that ALLOT will try to add more data bytes to.

```FORTH
LAST >NAME $.
```
prints the last words name.

You can change LAST with >LAST e.g. 
````FORTH 
` DUP >LAST
LAST >NAME $.
```

Would print "DUP"

This is useful if you want to use ALLOT and/or , to change a words data.

 

**LOCALS**

The locals array of VALUES that exists at every level, for every word.

When a word starts 0..7 LOCALS are all set to zero.

A  LOCALS value may be stored with TO, e.g. ' A string ' TO 7 LOCALS or 3.1459 TO 6 LOCALS.

Read the value with just 7 LOCALS.

A FLAT word sees the LOCALS of its parent word.

The interpreter at level zero, also has its own LOCALS.

See LOCALS above.

**LOOP**

Part of the magnificent definite DO .. LOOP

e.g. 10 1 DO I . .' Hello' CR LOOP ;

Within a LOOP you can get the LOOP index using **I**.

You can **EXIT** from a word and also by implication from any LOOPs.

You can **LEAVE** a LOOP and continue where LOOP ends, but only once.

**LIMIT**

Limits the steps a word can take, used to step through a word, while you attempt to understand how logic let you down again.

See the (not yet written) debugging section above.

**LSP^** 

Only really useful during startup to point the locals stack pointer at some HEAP.

**MOD**

Maths

**MS**

Delay for ms

**MSTR**

Print the unicode monster.

**NTH** 

Convert address to token number.

**NIP** 

Stack operation

**NOECHO** 

Disable terminal echo

**OR** 

Logical operation

**OVER**

Stack operation

**OVERSWAP**

Short for OVER SWAP.

**PI** 

A floating point constant

**PRIVATE** 

PRIVATE word, hides that word.

Avoids cluttering the dictionary with words only used in one other word.

Also hides words used only at startup, or that are so dangerous they should be banned.

**PAGE** 

Clears the terminal screen


**PARAMS** 

Copy N params from the data stack to the LOCALS stack

e.g. 
```FORTH
3 PARAMS 
```

Will load the LOCALS a, b and c from the stack.

You can only take up to 8 params (Locals run from a..h)

PARAMS also checks that the stack is deep enough so this word can also help with error detection.

It is also a fast way to load up to 8 arguments into the locals when a word starts up.


**PCHK** 

n PCHK 

Stops with an error if we dont have the number of params needed on the stack.

A good check to make words safer.


**PICK** 

A stack operation that picks the nth word from the stack.

*The fact that pick is actually super fast, is interesting.*

~~**QUIET**~~ 

~~Stop saying Ok all the time.~~

**RMARGIN** 

Terminal right margin

**REPEAT** 

Part of BEGIN f WHILE .. REPEAT loop



**RDEPTH** 

Depth of return stack

**ROT**

A stack operation

**R>** 

A return stack operation

**R@** 

A return stack operation

**RP@** 

A return stack operation

**RESET**

Reset and clear the parameter and return stacks and reset the terminal.

**RETERM**

Return terminal to standard settings.



**STRING** 

Create a name for a string, ' Hello ' STRING greeting

**STRINGS** 


Create a string array, 10 STRINGS messages

**SWAP** 

A stack operation

**SHIFTSL** 

Creates a shifting left word

**SHIFTSR** 

Creates a shifting right word

**SPACES** 

Displays spaces

**SPACE**

Displays a space

**SP@** 

A stack operation

**SP** 

The stack pointer

**SEE** 

SEE *word*

Displays what the compiler did to compile the word into tokens.

Shows details about a word.


**SELECTIT**

SELECTIT WORD 

Makes the word the last word.


**SELF^**

In a compiled word, points to the running words dictionary.


**SYSTEM**

Issues a system command

' ls -l ' SYSTEM 

Lists the files in the folder.



**TO** 

Sets a value, e.g. 10 TO thing.

**TIMEIT**

TIMEIT *word*, displays a words runtime.

That is it displays how long a word takes to run.

**TRACE**

TRACE word

Sets the words interpreter to the TRACEABLE one.

Used with TRON and TROF.

.e.g TRACE *WORD* TRON *WORD*

Should display a trace of the word running.

**TRUE** 

Not false, the same as -1 

**TFCOL**

Changes the text colour, using terminal escape codes, colours start at 30.

This also sets the background colour and if a character flashes its zany.

**TRACING?**

Are we tracing, perhaps the reams of code flying past should give us a clue.

This word may not be around much longer.. 

**TICKS** 

Ticks from the system timer

**TIMESDO**

Dumb and fast repeater, for a single word. 

10 TIMESDO word

**TPMS** 

Ticks per ms.

**TPS** 

Ticks per second

**TRON** 

Tracing on

**TROFF** 

Tracing off

**THEN** 

Ends the f .. IF ... ELSE ... THEN .. statment

**TUCK**

short for and faster than SWAP OVER

**UPTIME** 

Time since the program started


**UNALIAS**

UNALIAS word 

Will remove the alias name.

CLRALIAS  removes all alias names.

**UNTIL** 


Ends the BEGIN ... f UNTIL indefinite loop

**VALUE** 

Create a VALUE, 10 VALUE ten


create a VALUES array, 10 VALUES myValues 

**VARIABLE**

create a VARIABLE, 10 VARIABLE myThing

**WORDS** 

Lists the words but not all of them. 

**WARRAY**

**WVALUES** 

Create a VALUES array for word (32bit) length data

**WLOCALS** 

A word (32bit) values view over LOCALs storage.  

**WHILE** 

Part of BEGIN .. f WHILE .. REPEAT loop

**W!** 

32 bit word store

**W@**

32 bit word fetch

**$empty?**

Is the string empty

 **${    $}**

Begin / end building a string.

**$=** 

Are two strings the same

**$==** 

Are two strings content equal

**$find** ( sub str -- n )

find substring in larger string returns address where found.

' test ' ' this is a test of find' $find 

prints: test of find

**$compare** 

Is a string the same, less than or greater than another.

**$contains**  ( sub str -- f )

if str contains sub true, else false.

**$len** 

Find the length of a string.

**$occurs**  ( sub str -- n )

How many times does sub occur in string.

**$pos** 

Find the pos of char in string

**$slice** 

Take a slice from a string

**$''** 

The empty string, the same as 0.

**$intern** 

Take BUFFER$ and intern it into string storage

**$$** 

Access to string storage, not very useful, since it is sparse.

## General Learnings

Assembler code can be fragile, a mistake in a new feature can trash essential registers and blow up some part of the program, that is nowhere near the new change.

It is important to test after every single minor change to the ASM code.


