
### Thoughts and ideas 

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


: V++ ` >DATA1 DUP @ 1+ SWAP ! ;

	;ADRP	X0, sp1@PAGE		
	;ADD		X0, X0, sp1@PAGEOFF
	;MOV 	X1, #0
	;MOV     X2, 512
	;LSL		X2, X2, #3

	;BL fill_mem

		;ADRP	X0, rp1@PAGE		
	;ADD		X0, X0, rp1@PAGEOFF
	;MOV 	X1, #0
	;MOV     X2, 512
	;LSL		X2, X2,#3ßß
	;BL fill_mem



; get len the dumb way
	LDRB 	W0,  [X2, #63]
	CBNZ	W0,  2010f
	SUB 	X3,  X3, #15
	B 		2000f
2010:
	LDRB 	W0,  [X2, #62]
	CBNZ	W0,  2011f
	SUB 	X3,  X3, #14
	B 		2000f
2011:
	LDRB 	W0,  [X2, #61]
	CBNZ	W0,  2012f
	SUB 	X3,  X3, #13
	B 		2000f
2012:
	LDRB 	W0,  [X2, #60]
	CBNZ	W0,  2013f
	SUB 	X3,  X3, #12
	B 		2000f
2013:
	LDRB 	W0,  [X2, #59]
	CBNZ	W0,  2014f
	SUB 	X3,  X3, #12
	B 		2000f
2014:
	LDRB 	W0,  [X2, #58]
	CBNZ	W0,  2015f
	SUB 	X3,  X3, #11
	B 		2000f
2015:
	LDRB 	W0,  [X2, #57]
	CBNZ	W0,  2016f
	SUB 	X3,  X3, #10
	B 		2000f
2016:
	LDRB 	W0,  [X2, #56]
	CBNZ	W0,  2017f
	SUB 	X3,  X3, #9
	B 		2000f
2017:
	LDRB 	W0,  [X2, #55]
	CBNZ	W0,  2018f
	SUB 	X3,  X3, #8
	B 		2000f
2018:
	LDRB 	W0,  [X2, #54]
	CBNZ	W0,  2019f
	SUB 	X3,  X3, #7
	B 		2000f
2019:
	LDRB 	W0,  [X2, #53]
	CBNZ	W0,  2020f
	SUB 	X3,  X3, #6
	B 		2000f
2020:
	LDRB 	W0,  [X2, #52]
	CBNZ	W0,  2021f
	SUB 	X3,  X3, #5
	B 		2000f
2021:
	LDRB 	W0,  [X2, #51]
	CBNZ	W0,  2022f
	SUB 	X3,  X3, #4
	B 		2000f
2022:
	LDRB 	W0,  [X2, #50]
	CBNZ	W0,  2023f
	SUB 	X3,  X3, #3
	B 		2000f
2023:
	LDRB 	W0,  [X2, #49]
	CBNZ	W0,  2024f
	SUB 	X3,  X3, #2
	B 		2000f
2024:
	LDRB 	W0,  [X2, #48]
	CBNZ	W0,  2025f
	SUB 	X3,  X3, #1
  	B 		2000f 

2025:
	B 		2030f

2000:

	CMP 	W3, #0
	B.gt	2030f
	MOV 	W3, #80
	save_registers
	BL		saycr
	restore_registers
 

2030:

  : reset [ FLAT reset ]
	RMARGIN 1 TO LOCALS ;
  
  : -margin ( n -- ) [ FLAT -margin ]
	1 LOCALS SWAP - 1 TO LOCALS ;

 : reset? ( n -- ) [ FLAT reset? ]
	1 LOCALS 0< ;

 : first `` (END) ;
	

  : .countwords
	reset 
	LAST first DO 
		I >NAME C@ DUP 0> SWAP 255 <> AND IF
		 	I >NAME $. SPACE a++
			I >NAME $len -margin
			reset? IF CR reset THEN   
		 THEN 
	64 +LOOP 
	CR a . SPACE .' - Counted words. '
	;


	
: t1 NOECHO 
     BEGIN 
	 	KEY? IF
		  KEY DUP DUP EMIT CHAR = EMIT . 32 EMIT FLUSH 
		  81 = IF RETERM EXIT THEN
		THEN 
		100 MS 
	AGAIN
 ;

: STARS
  10000 1 DO 
  	500 RND + TFCOL 
  	20 RND 120 RND AT CHAR * EMIT
  LOOP ;


: $occurs ( substr str -- count )  
	 BEGIN
		OVER SWAP $find  
		DUP 0= IF 
			 DROP DROP DROP a EXIT
		ELSE
			a++
			1+ ROT DROP 
		 THEN
	AGAIN 
  ;

: test 
  ' test '
  ' this is a test word to test the test for that test '
  $occurs  ;

: check test 4 = IF .' Ok ' ELSE .' Err ' THEN ;

 
