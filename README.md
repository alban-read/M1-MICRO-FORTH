# 👾 M1 MICRO FORTH 0.73 TOKEN THREADED 2021
 
### Inspiration

Inspired by FORTH.

### purpose

Learn ARM64, have some fun, create useful things.

###  M1 MICRO FORTH is a small non standard VARIANT of FORTH


#### Unsusal or odd features that deviate from Standard FORTH.

- Strings are completely different:-
    - ASCII zero terminated in this version.
    - string storage has its own pool, the string literal looks like  `' a string '`. 
    - string words often include $ e.g ```$.``` prints a string.
    - strings are zero terminated.
    - There are words to make strings
    - ```' Hello World' STRING hello_world```
    - There are words to build strings (from substrings)
        - ```FORTH ${ ' ${ starts ' , ' appending ' , ' $} finishes ' , $} STRING appender ```
    - I detest the way standard FORTH handles strings, I always crash my programs when using them, so I am thinking hard about making them safe for use by humans.
- The dictionary is simplified into a single array for the headers :-
    - There are no vocabularies, few hundred words are defined not thousands.
    - Headers are seperate from 'code' (tokens), literals, and data.
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
    - The LOCALS storage comes from a stack.
    - There is an 8 item and 16 item VALUE view over the block.
    - The data is zero on entry to a word.
    - A FLAT word may share the LOCALS of its parent to provide accessor functions.
    - A FLAT word is useful for recursive words.
    - Predefined local accessor words a..h access the same storage
- Introspection
    - Running words can look up their own dictionary entry with SELF^  
    - This allows words to look up their own name, data, and code.
- LOOPS
    - There is a simpler faster definite loop `n TIMESDO word` also available in the interpreter and compiler.
- DO LOOP
    - higher lower DO ... LOOP 
    - higher lower DO ... +LOOP
    - higher lower DOWNDO ... LOOP
    - higher lower DOWNDO ... -LOOP
    - LEAVE is limited, because
        - The typical use case is garbage.  
        - And (honestly) it is difficult to compile.
- Indefinite loops
    - BEGIN f UNTIL
    - BEGIN .. f WHILE .. REPEAT
    - BEGIN .. LEAVE .. AGAIN 
- I/O
    - Unix terminal KEY, EMIT, KEY?, NOECHO, RETERM (restore terminal)
    - Simplified ACCEPT to read lines
    - ``` $'' STRING user_name  ACCEPT TO user_name .' Hi ' user_name $. CR ```
- The interpretor
    - is mostly implemented in ARM64 assembly language.
    - every word has a slot for run time and compile time actions.
    - compiles words to a token list using half-word (16 bit tokens)
    - literals are shared accross words and refer to literal pools.
    - often the compile time word compiles in a helper function named (nnnnn), see allwords.
    - every high level word calls its own machine code interpreter there are several versions.
- Introspection
    - There are words to SEE words, and to trace word execution.
    - There are values that are views over the various storage pools.
    - It is possible to STEP through words.

### Selfie
![Selfie](selfie.png)


### Details

[M1MicroForth.md](M1MicroForth.md)

### Project rules

This is open source, feel free to fork and improve.

This project does not accept pull requests.



