
### Thoughts and ideas for a safer, saner, practical FORTH for Aarch64 desktops.


Using getline for terminal input is a bit weak.
But do I want to be in a terminal anyway?
I would like up arrow to at least work.




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

: HIDE 0 ` 0 48 + C! ;

x0 0
x1 save state
tcgetattr 

bl	_tcgetattr
and	x8, x8, #0xfffffffffffffeff
and	x8, x8, #0xfffffffffffffff7

    mov x0, #0
    mov x1, chbuff
	mov	x2, #1
	bl	_read

    x0 0
x1 0
x2 save_state
tcgetattr 

tcsetattr(0, 0, &oldstate);


struct termios {
	tcflag_t        c_iflag;        /* input flags */  long
	tcflag_t        c_oflag;        /* output flags */ long
	tcflag_t        c_cflag;        /* control flags */ long
	tcflag_t        c_lflag;        /* local flags */ long < change 
	cc_t            c_cc[NCCS];     /* control chars */ 20 bytes
	speed_t         c_ispeed;       /* input speed */  long
	speed_t         c_ospeed;       /* output speed */ long
};


Things that crash 
[ without ] because ] lacks a space like [ that]
