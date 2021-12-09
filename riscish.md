### This is a non standard VARIANT of FORTH

This FORTH is implemented mainly in AARCH64 assembly language (main.asm), and runs under OSX on the Apple M1.

FORTH primitives are implemented as assembly language functions, the compiler converts high level FORTH words into list of tokens for the token interpreter(s) to execute.

This is not a standard implementation, I am aiming to provide a reasonable set of non standard words that improve comfort, safety and convenience for the user of the language.




