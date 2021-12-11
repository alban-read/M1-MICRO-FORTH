### This is a non standard VARIANT of FORTH

This FORTH is implemented mainly (entirely so far) in AARCH64 assembly language (main.asm), and runs hosted under OSX on the Apple M1.

The compiler compiles words to tokens, which are then executed by a simpler interpreter.

It is going to be quite specific to features of the ARM V8 64 bit processor, such as wordsizes.

FORTH primitives are implemented as assembly language functions, the compiler converts high level FORTH words into list of tokens for the token interpreter(s) to execute.

This is not a standard implementation, I am aiming to provide a reasonable but small set of FORTH like words that improve comfort, safety and convenience for the user of the language.

Untyped - Storage has no type, words are aware of the size of storage cells but not what they contain.

The syntax follows FORTH closely, including reverse polish notation, composition of functions by word concatenation, very similar control flow etc.

The inner (token) interpreter is not running all of the time in this implementation.

It only runs when a high level word is executing, otherwise the interpreter and compiler are just running machine code, the interpeter and compiler are not written in FORTH.

Each high level word invokes an interpreter to run itself, multiple different versions of the interpreter exist, and they can be selected after the word has been compiled.


### Values

Values are preferred to VARIABLES, as they are much safer to use, and simpler to access.

A value is created with the VALUE word.

A value has no type, it could be used to represent an int, float, char etc.

A value has only a size in bits, the base VALUE is 64 bits.

199 VALUE myvalue

A value is read

myvalue .

A value is changed

200 TO myvalue

The default cell size for values is 8 (64 bits) each element can store a large integer value or a double float, they are untyped other than bit length.

An array of values is created with the VALUES plural word.

128 VALUES myvalues 

The VALUES are allotted from memory that is zero filled, so all values will read as 0.

To change every value.

1 FILLVALUES myvalues

Every entry in myvalues becomes 1.

To change one entry use TO


1000 7 TO myvalues 

7 myvalues .

Value entry 7 in myvalues becomes 1000.



### Special values

Some special values are built in.


#### LOCALS and WLOCALS

These are not FORTH standard words.


LOCALS provide each word with eight (64bit) local variables.

LOCALS is a VALUES of length 8 (0..7) that provide some local memory storage for each word invocation. 

LOCALS backing memory is implemented as a stack, allowing about 250 levels of depth.

On entry to a word LOCALS are erased, all values will be read as zero.

LOCALS cease to exist and are reused when a word ends.

WLOCALS use the same memory as LOCALS providing word sized access (32bits) to 16 (0..15) Values.

If it is more convenient to have 16 smaller values use WLOCALS instead of LOCALS

These are both just views over the same 64 bytes of memory in the local memory stack.

To recap locals are valid between : and ; 

e.g.

: t1 127 FILLVALUES WLOCALS  15 WLOCALS 14 WLOCALS + . ;

Should return 254, every high level word, normally gets its own fresh set of LOCALS.

They are not normally shareable.

After t1 runs type 14 WLOCALS . and it will be zero, the command line level has its own set of LOCALS as well.


#### advanced LOCALS use cases

You may have a recursive word you do not want to eat into the LOCALS stack.

You can declare the word is FLAT like this.

FLAT word.

: FIB ( n -- n1 )  DUP 1> IF  1- DUP 1- FIB SWAP FIB + THEN ; FLAT FIB

This makes FIB a very, very, tiny fraction faster, LOCALS are not slow.


##### LOCAL Accessor words.

A FLAT word sees the locals of its parent word, the word that called it, or the command line.

Using the standard local access can be cumbersome, the name LOCALS does not mean much.

FLAT words can be used to create words for accessing the parents locals, in the simplest case this just lets you give local variables some sensible names.


```FORTH

// allocate a local to speed.

: set-speed 0 TO LOCALS ; FLAT set-speed 

: speed 0 LOCALS ; FLAT speed


: test 10 set-speed  speed . ;

```



set-speed and speed are working on the LOCALS shared with test.

Obviously accessor words could do a lot more, like checking the speed is valid etc.




#### TOKENS

Is a VALUES view over the HW (half/word 16 bit) token space, this is where the compiler stores tokens for words it compiles.

#### LITERALS

Is a VALUES view over the (64 bit) long literal space, where large integers, double floats and addresses are stored by the compiler.


### Floating point support

Floating point words begin with f e.g. f.

Numbers containing a . are taken to be floating point numbers.

The same parameter stack is used, which may hold 64 bit (double) floats or 64 bit (quad) integers.

A small set of floating point operations are implemented.





