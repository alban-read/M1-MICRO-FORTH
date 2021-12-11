### This is a non standard VARIANT of FORTH

This FORTH is implemented mainly in AARCH64 assembly language (main.asm), and runs under OSX on the Apple M1.

It is going to be quite specific to features of the ARM processes, such as wordsizes.

FORTH primitives are implemented as assembly language functions, the compiler converts high level FORTH words into list of tokens for the token interpreter(s) to execute.

This is not a standard implementation, I am aiming to provide a reasonable but small set of FORTH like words that improve comfort, safety and convenience for the user of the language.



### Values

A value is created 

199 VALUE myvalue

A value is read

myvalue .

A value is changed

200 TO myvalue

An array of values is created

128 VALUES myvalues 

The VALUES are filled with 1

1 FILLVALUES myvalues








### Floating point support

Floating point words begin with f e.g. f.

Numbers containing a . are taken to be floating point numbers.

The same parameter stack is used, which may hold 64 bit (double) floats or 64 bit (quad) integers.

A small set of floating point operations are implemented.





