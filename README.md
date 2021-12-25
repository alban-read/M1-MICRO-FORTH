# riscish

## experiment


## Thoughts

AARCH64 is suprisingly different to ARM32.


### Inspiration

Inspired by FORTH.

### purpose

Learn ARM64, have some fun, create useful things.


### approach

create small machine code primitive words 

 .. allow them to be tested interactively

 .. allow new words to be composed, mainly by concatenation.



### This is a non standard VARIANT of FORTH


#### Unsusal or odd features that deviate from Standard FORTH.

- Strings are completely different:-
    - string storage has its own pool, the string literal is ' a string '. 
    - string words often include $ e.g $. not type
    - strings are zero terminated not counted as it is 2021.
    - There are words to make strings
    - ' Hello World' STRING hello_world
    - There are words to build strings (from substrings)
        - ```FORTH ${ ' ${ starts ' , ' appending ' , ' $} finishes ' , $} STRING appender ```
- The dictionary is simplified into a single array for the headers :-
    - There are no vocabularies, few words are defined not thousands.
- The token space for 16bit tokens (compiled words) is separate from data.
    - The token compiler creates tokens in token space and literals in literal pools.
    - There are long literals, for integers and floats.
- The data has its own space in the allotment.
- Values are used and several value sizes are supported.
    - Values are safer as you do not work with raw addressess.
    - Values are more convenient when mostly reading values.
    - Arrays of values are supported
- Locals 
    - A fixed sized 64 byte data block is available to every word.
    - The LOCALS storage comes form a stack.
    - There is an 8 item and 16 item VALUE view over the block.
    - The data is zero on entry to a word.
    - A FLAT word may share the LOCALS of its parent to provide accessor functions.
    - A FLAT word is useful for recursive words.
        - ```FORTH : test 100 0 TO LOCALS ; // plain locals access ```
        - ```FORTH : cat-count ( -- n ) [ FLAT ] 6 LOCALS ; // use 6 for cat-count ```
        - ```FORTH : set-cat-count ( n -- ) [ FLAT ] 6 TO LOCALS ; // set cat-count ```
- LOOPS
    - There is a simpler faster definite loop `n TIMESDO word` also available in the interpreter and compiler.
- DO LOOP
    - higher lower DO ... LOOP 
    - higher lower DO ... +LOOP
    - higher lower DOWNDO ... LOOP
    - higher lower DOWNDO ... -LOOP
    - LEAVE is limited, because
        - The typical use case is garbage.  
    - And it is difficult to compile.
- Indefinite loops
    - BEGIN f UNTIL
    - BEGIN .. f WHILE .. REPEAT
    - BEGIN .. LEAVE .. AGAIN 
- I/O
    - Unix terminal KEY, EMIT, unbuffered, flushed.
    - Simplified ACCEPT to read lines
    - ```FORTH 0 STRING user_name  ACCEPT to user_name .' Hi ' user_name $. CR ```
- The compiler
    - is implemented in assembly language.
    - every word has a slot for run time and compile time actions.
    - compiles words to a token list using half-word (16 bit tokens)
    - literals are shared accross words and refer to literal pools.
    - often the compile time word compiles in a helper function named (nnnnn), see allwords.
    - every high level word calls its own interpreter there are several versions.
- Introspection
    - There are words to SEE words, and to trace word execution.
    - There are values that are views over the various pools.
    - It is possible to STEP through words.

