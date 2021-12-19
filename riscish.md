### This is a non standard VARIANT of FORTH

This FORTH is implemented mainly in AARCH64 assembly language (main.asm), and runs hosted under OSX on the Apple M1.

A few C library functions are used, the program is linked against the C library, it is possible to call C functions, which will be useful, in order to talk to the operating system.

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


```FORTH
199 VALUE myvalue
```

A value is read
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
The VALUES are allotted from memory that is zero filled, so all values will initially read as 0.

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

LOCALS is a special array of values of length 8 (0..7) that provide some small local memory storage for each word invocation. 

LOCALS backing memory is implemented as a stack, allowing about 250 levels of depth.

On entry to a word LOCALS are erased, all values will be read as zero.

LOCALS cease to exist and are reused when a word ends.

WLOCALS use the same memory as LOCALS providing word sized access (32bits) to 16 (0..15) Values.

If it is more convenient to have 16 smaller values use WLOCALS instead of LOCALS

These are both just views over the same 64 bytes of memory in the local memory stack.

To recap locals are only valid between : and ; 

e.g.

```FORTH
: t1 127 FILLVALUES WLOCALS  15 WLOCALS 14 WLOCALS + . ;
```

Should return 254, every high level word, normally gets its own fresh set of LOCALS.

They are not normally shareable.

After t1 runs type 14 WLOCALS . and it will be zero, the command line level has its own set of LOCALS as well.


#### advanced LOCALS usage

You may have a recursive word that you do not want to eat into the LOCALS stack.

You can declare that a word is FLAT like this.

FLAT word.
```FORTH
: FIB ( n -- n1 )  DUP 1> IF  1- DUP 1- FIB SWAP FIB + THEN ; FLAT FIB
```
This makes FIB a very, very, tiny fraction faster, LOCALS are not slow.


##### LOCAL Accessor words.

A FLAT word sees the locals of its parent word, that is the word that called it, or the command line.

Using the standard local access can be cumbersome, the name LOCALS does not mean much.

FLAT words can be used to create words for accessing the parents locals, in the simplest case this just lets you give local variables some sensible names by creating accessor words.


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

A string is created with an initial text value like this.
```FORTH
' This is my initial value ' STRING myString
```
A string returns the address of its data.
```FORTH
myString $. 
```
Will print the string.

A string should not be mutated, each unique string exists only once in the string pool, 
changing one would impact all usages everywhere in a program.

Strings can be compared with $= and $== which check if they are same and $COMPARE wich checks if one is equal, greater, or less than the other.

In terms of storage the strings content is stored in the string pool with all the rest, the word just points it and gives it a name.

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

$. is a word that prints a string.

Again the storage for text lives in the string pool.

The string pool can be accessed using the VALUE $$

e.g. 

```FORTH

0 $$ $. 

```

### Appending/building strings

Often a string needs to be built from smaller parts

These words are meant to help make it less error prone.

```FORTH

${ ' ${ starts ' , ' appending ' , ' $} finishes ' , $} TYPEZ  

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



### Floating point support

Floating point words begin with f e.g. f.

Numbers containing a decimal point . are taken to be floating point numbers.

The same parameter stack is used, which may hold 64 bit (double) floats or 64 bit (quad) integers.

A small set of floating point operations are implemented, typical comparison and math operations that the CPU directly supports are found starting with f, such as f+ and f.

e.g. 
```FORTH
22.0 7.0 f/ f.
```




