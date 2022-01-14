// startup
TICKS 

64 1024 2 * * HEAPSIZE
HEAP^ ALIGN8 DUP TO HERE^ TO HLAST^ 
 
80 256 * HEAPSIZE HEAP^ ALIGN8 TO LSP^
 
// save start time from here.
 VALUE start_ticks

// Offsets from a words header
8  ADDS >RUN
16 ADDS >ARG2  
24 ADDS >COMP
32 ADDS >DATA1  
40 ADDS >DATA2  
48 ADDS >NAME

// common constants 
-1 CONSTANT -1

: DELWORD  ` 64 0 FILL ; 

: VALDAT ` @ ;


// Display time spent in the program

: .UPTIME
	TICKS start_ticks - 
	s>f TPMS s>f f/ f.  .'  ms.'  ;

// Add common float constants
3.14159265359   CONSTANT PI


// Add the very common fast add and subtract words
 1 ADDS 1+ 1 SUBS 1-
 2 ADDS 2+ 1 SUBS 2-
16 ADDS 16+
32 ADDS 32+

// add the common shift words
1 SHIFTSL 2* 1 SHIFTSR 2/
2 SHIFTSL 4* 2 SHIFTSR 4/


// -------------------------------------------------------
// list ALIAS words 

: _list_alias
	1 PARAMS
	CR 
	BEGIN
		a @ -1 = IF EXIT THEN
		a @ 0> IF
			a $. .' =[' a 16+ DUP $. .' ]'  CR
		THEN
		a 32+ a!
	AGAIN
	CR
;

: .ALIAS ALIAS^ _list_alias ;


// -------------------------------------------------------
// display and count public words

ALIAS	countword 	a++
ALIAS	wordcount 	a
ALIAS 	wordsize	64
ALIAS 	lastword	255

: _words_reset [ FLAT _words_reset ]
	RMARGIN 1 TO LOCALS ;
  
: _words_margin  ( n -- ) [ FLAT _words_margin  ]
	1 LOCALS SWAP 1+ - 1 TO LOCALS ;

: _reset? ( n -- ) [ FLAT _reset? ]
	1 LOCALS 0< ;
 
: _words
	_words_reset 
     DO 
		I >NAME C@ DUP 95 <> SWAP lastword <> AND IF
		 	I >NAME $. SPACE countword
			I >NAME $len _words_margin 
			_reset? IF CR _words_reset THEN   
		 THEN 
	wordsize +LOOP 
	CR wordcount . SPACE .' - Counted words. '
	;

: WORDS FINAL^ `` (  _words ;

: ALLWORDS FINAL^ `` (EXIT)  _words ;


// -------------------------------------------------------
// displays key codes until Q

ALIAS 'Q' 81
ALIAS 'q' 113
ALIAS '=' 61
ALIAS pausetime 100

: .keys NOECHO 
	 CR .' Press keys to see the key codes.'
	 CR .' press Q - to quit ' CR
     BEGIN 
	 	KEY? IF
		  KEY DDUP EMIT '=' EMIT . SPACE FLUSH 
		  DUP 'Q' = SWAP 'q' = OR IF RETERM EXIT THEN
		THEN 
		pausetime MS 
	AGAIN
 ;

CLRALIAS

 
// -------------------------------------------------------
// STRINGS 

// is this is an empty string?
: $empty? 1 PCHK 0= IF TRUE ELSE C@ 0= THEN  ;


// how many times is substr in str

ALIAS countit a++
ALIAS counted a 

: $occurs ( substr str -- count )  
	2 PCHK
	 BEGIN
		OVERSWAP $find  
		DUP 0= IF 
		DDROP DROP countit EXIT 
		ELSE 
			counted
			1+ ROT DROP 
		 THEN 
	AGAIN  
  ;
 
CLRALIAS

// make exponent word and assign to ^
// ^ is predefined without any action.

: exp ( x y -- x^y )
   OVERSWAP 1 ?DO OVER * LOOP NIP ; 

` exp ` ^ CCPY DDROP  DELWORD exp

// basic terminal colours 

ALIAS TCOL.reset 	0
ALIAS TCOL.bold 	1
ALIAS TCOL.under 	2
ALIAS TCOL.reverse  3
ALIAS TCOL.black 	30
ALIAS TCOL.red 		31
ALIAS TCOL.green 	32
ALIAS TCOL.yellow 	33
ALIAS TCOL.blue 	34
ALIAS TCOL.magenta 	35
ALIAS TCOL.cyan 	36
ALIAS TCOL.white 	37


// -------------------------------------------------------
// Terminal Brick Out.
// a dumb game on the terminal using ansi escape codes.
// 

8 STRING coff 
	27 , CHAR [ , CHAR ? , CHAR 2 , CHAR 5 ,
	CHAR l ,  0 ,	 

8 STRING con
	27 , CHAR [ , CHAR ? , CHAR 2 , CHAR 5 ,
	CHAR h ,  0 ,	 

8 STRING cln
	27 , CHAR [ , CHAR 2 , CHAR K, 0 ,
 

: curoff coff $. ;
: curon con $. ;
: clrln cln $. ;

4 STRING ballone 
	0xE2 , 0x97 , 0xAF , 0 , 

4 STRING balltwo 
	0xE2 , 0x8D , 0x9F , 0 ,

4 STRING ballthree
	0xE2 , 0x8A , 0x9B , 0 ,

4 STRING ballfour
	0xE2 , 0x8A , 0x9A , 0 ,


4 STRING ballfive
	0xE2 , 0x9A  , 0xAB , 0 ,

4 STRING ballsix
	0xE2 , 0x9A , 0xAA , 0 ,


4 STRING badfall1
	0xE2 , 0x98 , 0xA2 , 0 ,

4 STRING badfall2
	0xE2 , 0x98 , 0xA3 , 0 ,

4 STRING badfall3
	0xE2 , 0x98 , 0xA0 , 0 ,

4 STRING goodfall1
	0xE2 , 0x98 , 0xAE , 0 ,

4 STRING goodfall2
	0xE2 , 0x9A , 0x9B , 0 ,

4 STRING goodfall3
	0xE2 , 0x9A , 0x9A , 0 ,

4 STRING goodfall4
	0xE2 , 0x9A , 0x98 , 0 ,

24 STRING smallbat 
	0xE2 , 0x97 , 0x96 ,
	0xE2 , 0x96 , 0xA0 ,
   	0xE2 , 0x96 , 0xA0 ,
 	0xE2 , 0x96 , 0xA0 ,
	0xE2 , 0x97 , 0x97 ,
	0 ,


24 STRING widebat 
	0xE2 , 0x97 , 0x96 ,
	0xE2 , 0x96 , 0xA0 ,
   	0xE2 , 0x96 , 0xA0 ,
 	0xE2 , 0x96 , 0xA0 ,
	0xE2 , 0x96 , 0xA0 ,
 	0xE2 , 0x96 , 0xA0 ,
	0xE2 , 0x97 , 0x97 ,
	0 ,
 
: makesixl 
  2 PARAMS       
  240  a C! 159 a 1+ C! 172 a 2+ C! b a 3 + C!  
 ;
 
0 VARIABLE sixls 256 ALLOT 
 
: makesxls 
	128 a!
	512 0 DO 
		a sixls I + makesixl 
		a++
	8 +LOOP 
;
 
 3 SHIFTSL 8* 

: .sixl ( n )
	8* sixls + $.
;

// so we can pick one
: .sixls 64 0 DO I .sixl CHAR = EMIT I . SPACE LOOP ;

: .brick 
	56 48 48 48 52
	5 TIMESDO .sixl
;


: .bricks 
	9 0 DO 
	  .brick SPACE SPACE
	LOOP 
;

: .wall 
	6  10 AT 
	TCOL.cyan FCOL .bricks  
	8  10 AT 
	TCOL.magenta FCOL .bricks  
	10 10 AT 
	TCOL.yellow FCOL .bricks  
	12 10 AT 
	TCOL.green FCOL .bricks  
	14 10 AT
	TCOL.blue FCOL .bricks  
	16 10 AT
	TCOL.red FCOL .bricks  
;
 

ALIAS x a 
ALIAS y b 

2  VALUE batminx
80 VALUE batmax

 
40 VALUE batx
30 VALUE baty
0  VALUE batxdir
TCOL.green VALUE batclr
 
43 VALUE ballx
29 VALUE bally
FALSE VALUE ballfree
TCOL.red VALUE ballclr

0  VALUE ballxdir
-1 VALUE ballydir

0 VALUE movetime

0 VALUE keypresses

: atbat ( x y c --- )
	3 PARAMS
	c FCOL 
	x y AT clrln
	x y AT smallbat $. 	
;

: atball ( x y c --- )
	3 PARAMS
	c FCOL 
	ballfree 0= IF 	x y AT clrln THEN
	x y AT ballone $. 	
;

: batsball 
	FALSE TO ballfree
	batx 2 + TO ballx 
	baty 1- TO bally
;

: showbat ( ) 
	batclr batx baty atbat ;
 
: showball ( ) 
	ballclr ballx bally atball ;

: ballmove 
		bally ballx AT 32 EMIT
		ballx ballxdir + TO ballx 
		bally ballydir + TO bally	
		bally 1 < IF 
			batsball
		THEN
		showball 
;

: batmove 
		batx batxdir + TO batx 
		batx batmax > IF -1 TO batxdir THEN
		batx batminx < IF 1 TO batxdir THEN
		showbat
		ballfree 0= IF
			batx 2 + TO ballx 
			showball
		THEN 
;


ALIAS 'z' 122 // left
ALIAS 'x' 120 // right
ALIAS 'q' 113 // quit game
ALIAS 'c' 99 // stop

// move bat when keys pressed.

// 
: batballxdir ( n -- )
	ballfree 0= IF 
		TO ballxdir
	ELSE DROP THEN 
 ;

: batleft 
	batx batminx > IF 
		batxdir 1 = IF 
			0 TO batxdir
			0 batballxdir
		ELSE 
			-1 TO batxdir
			-1 batballxdir
		THEN
	THEN
;
: batright 
	batx batmax < IF 
		batxdir -1 = IF 
			0 TO batxdir
			0 batballxdir
		ELSE 
			1 TO batxdir
			1 batballxdir
		THEN
	THEN
;


: batkeys  
batsball
TICKS TO movetime
NOECHO curoff
showbat showball
BEGIN
  KEY? IF 
	
	keypresses 1+ TO keypresses
	ballfree 0= keypresses 4 MOD 0= AND IF 
		 0 TO ballxdir
	THEN 

	KEY 
 
	DUP 'z' = IF 
		batleft
	THEN
	
	DUP 'x' = IF 
		batright
	THEN 
	
	DUP 32 = IF 
		 TRUE TO ballfree
	THEN 
	
	DUP 'q' = IF 
		curon DROP
		TCOL.reset FCOL 
		RETERM
		EXIT 
	THEN 
  
  THEN // key?

  FLUSH  

  // only update bat and ball at set rate
  TICKS movetime - 984000 > IF 
	 .wall
  	 TICKS TO movetime
	 ballfree IF ballmove THEN
	 batmove
  THEN
  
  1 MS // do not use 100% CPU

AGAIN
;

: START 
	PAGE
	makesxls 
	.wall
	batkeys
	;

// announce ourselves

// define the UTF8 unicode monster
8 STRING mstr 0xF0 , 0x9F , 0x91 , 0xBE , 0 , 

: MSTR 
	mstr $. ;

: bold.green 
	TCOL.green FCOL TCOL.bold FCOL
;

: colr.reset 
	TCOL.reset FCOL
;

: ?DAY  DUP 1 <  SWAP 31 > +  IF .' No way ' ELSE .' Looks good ' THEN ;


: Hi 
	PAGE
	bold.green 
	MSTR SPACE .VERSION 
	colr.reset 
	TCOL.blue FCOL
	WORDS CR
	.' forth.forth  loaded in '  .UPTIME 
	colr.reset 
;


// off we go

Hi 

