# riscish

## experiment


## Thoughts

AARCH64 is suprisingly different to ARM32


### Inspiration

Inspired by FORTH.

### purpose

Learn ARM64, have some fun, create useful things.


### approach

create small machine code primitive words 

 .. allow them to be tested interactively

 .. allow new words to be composed, mainly by concatenation.

 

### This is a non standard VARIANT of FORTH

This FORTH is non standard.

This FORTH is implemented mainly in AARCH64 assembly language (main.asm), and runs hosted under OSX on the Apple M1.

A few C library functions are used, the program is linked against the C library, it is possible to call C functions (from assembler), which will be useful, in order to talk to the operating system.

The compiler compiles words to tokens, which are then executed by a simpler interpreter.

The implementation is specific to features of the ARM V8 64 bit processor, such as wordsizes.

FORTH primitives are implemented as assembly language functions, the compiler converts high level FORTH words into list of tokens for the token interpreter(s) to execute.

This is not a standard implementation, I am aiming to provide a *very small* set of practical FORTH like words that improve comfort, safety and convenience for the user of the language (me.) Throwing in 'everything and the kitchen sink in case it is useful' is very contrary to original FORTH principles.

I expect to extend the ASM file as I write my own Apps, I plan to test and script my Apps in FORTH.

Untyped - Storage has no type, words are aware of the size of storage cells but not what they contain.

The syntax follows FORTH closely, including reverse polish notation, composition of new words *functions* by word concatenation, very similar control flow etc.

The inner (token) interpreter is not running all of the time in this implementation.

It only runs when a high level word is executing, otherwise the interpreter and compiler are just running machine code, the interpeter and compiler are not written in FORTH.

Each high level word invokes an interpreter to run itself, multiple different versions of the interpreter exist, and they can be selected after the word has been compiled.

I am using a certain ammount of brute force and ignorance in the current design of this program, which may not scale, but which works presently, in the spirit of getting it all started.  


### Startup

The forth.fs file is loaded when the application starts.

This file should contain any high level words you want to add to the program.

It is set up to clear the screen, and display the words, there are some words defined in the file, they are just examples you can remove if your own app will not use them.

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
The VALUES are allotted from s pool of memory that is zero filled, so all values will initially read as 0.

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


Storge for WLOCALS

- WLOCALS use the same memory as LOCALS providing word sized access (32bits) to 16 (0..15) Values.

- If it is more convenient to have 16 smaller values use WLOCALS instead of LOCALS

- These are both just views over the same 64 bytes of memory in the local memory stack.

To recap locals are only valid between : and ; 

e.g.

```FORTH
: t1 127 FILLVALUES WLOCALS  15 WLOCALS 14 WLOCALS + . ;
```

Should return 254, every high level word, normally gets its own fresh set of LOCALS.

They are not normally shareable.

After t1 runs type 14 WLOCALS . and it will be zero, the command line level has its own set of LOCALS as well.

There is no need to use LOCALS but if you write a word and think it would be handy to have somewhere else to briefly store a value that is not global or the stack, they serve that purpose.


#### advanced LOCALS usage

You may have a recursive word that you do not want to eat into the LOCALS stack.

- You can declare that a word is FLAT like this.

FLAT word.
```FORTH
: FIB ( n -- n1 )  DUP 1> IF  1- DUP 1- FIB SWAP FIB + THEN ; FLAT FIB
```
This makes FIB a very, very, tiny fraction faster, LOCALS are not slow.


##### LOCAL Accessor words.

A FLAT word sees the locals of its parent word, that is the word that called it, or the command line.

- Using the standard local access can be cumbersome, the name LOCALS does not mean much.

- FLAT words can be used to create words for accessing the parents locals, in the simplest case this just lets you give local variables some sensible names by creating accessor words.


```FORTH

// allocate a local to speed.

: set-speed 0 TO LOCALS ; FLAT set-speed 

: speed 0 LOCALS ; FLAT speed


: test 10 set-speed  speed . ;

```

set-speed and speed are working on the LOCALS shared with test.

Obviously accessor words could do a lot more, like checking that the given speed is valid etc.

Without FLAT, set-speed and speed would each read their own LOCALS a level above test and test would not work.


#### TOKENS

Is a VALUES view over the HW (half/word 16 bit) token space, this is where the compiler stores tokens for words it compiles.

#### LITERALS

Is a VALUES view over the (64 bit) long literal space, where large integers, double floats and addresses are stored by the compiler.



### Strings 

Strings are non standard.

Strings are zero-terminated because that is the world we have lived in ever since UNIX was invented. To emphasize the *very major* differences, string literals here use single quotes.
 

A string is created with an initial text value like this.
```FORTH
' This is my initial value ' STRING myString
```
A string returns the address of its data.

```FORTH
myString $. 
```
Given the address $. will print the string.

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

The storage for the string text lives in the string pool a STRING word just points a name at it.

The string pool can be accessed using the special VALUE $$

e.g. 

```FORTH

0 $$ $. 

```

Looks up the first 0th string in the storage and $. types it to the terminal.


### Little defining words

As this is an interpeter it is almost always slower to use two words when one word will do.

It is also faster if each word *does more*, the overhead of the interpreter is calling each word in the first place.

The compiler also does not optimize, so it is often up to the programmer to choose to use a faster optimal word not up to the compiler to invent them on the fly.

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

Each element of text is added by the comma after it.

At the end the combined text is stored and its address is returned, so it can be named.


```FORTH

${ ' ${ starts ' , ' appending ' , ' $} finishes ' , $} STRING appender 

```

In line with general FORTH principles the , is a word not a separator, and comes after the text being appended.  The single quote is a word and must be followed by a space. This reads text until the next single quote.


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

Most of the LOOPing words, only work inside a compiled word.

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
It is simpler than other LOOPS and less powerful, it is also faster at doing the simple things it does.

It also works in a compiled word e.g. 

```FORTH 

\\ Also works in a compiled word.

: DASHED-LINE CR 32 TIMESDO DOT-DASH CR ;

```


### Input and output.

The IO is set for the UNIX terminal.

The interpreter accepts lines from the terminal, with buffering, the input is often STDIN, although the input can sometimes be a file, as it is at startup.

The various printing words, `. $. f. .' hey'` etc print to STDOUT, and they buffer for terminal efficiency.


KEY - reads a user key press from STDIN, waits for single key press, does not echo or buffer.

EMIT - writes the char to STDOUT, without delay, flushes STDOUT.

Terminals accept a variety of commands.

FORTH typically only implements `PAGE` to clear the screen and `AT-XY` to place the cursor.


#### Thoughts

Having the interpreter and token compiler implemented in assembly language does provide some benefits, such as testing the token compiled code easilly, since the interpeter is not made out of the same token compiled code being tested.

The interpreter in assembler, also means it is not as exposed to high level FORTH as it would be if it was written in FORTH.

High level FORTH does have a lot of access to the system still, various interrnal objects are also exposed as VALUES to FORTH.

In theory a version of the inner interpreter can be written in FORTH, I expect that would be far slower due to the high level loops, and the use of FORTH values instead of machine registers, very interesting to test.

### Performance

This implementation is using a simple token interpreter that is written in assembly language.
I have paid some attention to the performance of the inner loop, it is easy to test as you can try out different versions and time the results.

The design is a token interpreter, I chose to use 16bit tokens to represent words, rather than 64 bit addresses, the addresses would probably be faster, but that would be a different implementation, as lots of words are tuned for the token memory layout.

It is a simple interpreter but FORTH is also a simple and lean language.

The token interpreter is competitive with commonly used interpreted languages.


