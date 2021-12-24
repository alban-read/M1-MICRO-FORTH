
### Thoughts and ideas for a safer, saner, practical FORTH for Aarch64 desktops.


VALUES not VARIABLEs

A decent STRING type value for strings

Use a string builder to build strings



PAIRS fit into the arch64 architecture well.
A pair being two items that always travel to and from the stack together and are
stored together in memory, with LDP and STP.


```FORTH

' Cats ' 3 PAIR myCats

myCats $. . 

```

Prints how may Cats I have.

```FORTH

10 PAIRS myAnimals

myCats 0 TO myAnimals

```




INCR and DECR for values, possibly created by INCREMENTS and DECREMENTS defining words, that increment and decrement by more than 1.

To increment a value 

```FORTH
myValue 1+ TO myValue
```

Instead 

```FORTH

1 +TO value 

```

OR 

```FORTH
INCR myValue
```

Where 1 is implicit


RANGES 

```FORTH
12 6 2 RANGE myRange
```
Range from 6 to 12 in steps of 2.


f WHENDO word 

WHEN f is TRUE DO word.

A fast IF for the next word only that works in the interpreter.


Fast LOCALS

Consider making number of LOCALS a word can have dynamic.

```FORTH

: mydumbword 32 ALLOCATEDLOCALS ... ;

```





