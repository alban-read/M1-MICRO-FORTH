// This file is loaded as FORTH starts.
// -------------------------------------------------------
// Set up the Dynamic Memory areas

// initially the stack is tiny. 
// parameter stack size (in 64 bit cells)
512 #DSTACK 

// set allotment size data
1024 1024 * HEAPSIZE
HEAP^ ALIGN8 DUP TO ALLOT^ TO ALLOT.LAST^ 
1020 1024 *  ALLOT^ + TO ALLOT.LIMIT^

// set tokens size 64k HW tokens
64 1024 2 * * HEAPSIZE
HEAP^ ALIGN8 DUP TO HERE^ TO HLAST^ 
HERE^ 64 1024 2 * * 0 FILL

// set locals stack depth (80 bytes)
80 256 * HEAPSIZE HEAP^ ALIGN8 TO LSP^
LSP^ 80 256 * 0 FILL


// set up a massive sparse short-strings pool 
// this is a temporary kludge, hopefully

8519680 HEAPSIZE HEAP^ ALIGN8 TO $^ 
8519680 256 - $^ + TO $LIMIT^
$^ 8519680 0 FILL

// -------------------------------------------------------
// now variables and words can be declared.

// save start time from here.
TICKS  VALUE start_ticks



// Offsets from a words header
8  ADDS >RUN
16 ADDS >ARG2  
24 ADDS >COMP
32 ADDS >DATA1  
40 ADDS >DATA2  
48 ADDS >NAME

// common constants 
-1 CONSTANT -1

: PRIVATE 0 ` >NAME C! ; 

: DELWORD  ` 64 0 FILL ; 

: VALDAT ` @ ;

// hide startup internal words
PRIVATE #DSTACK
PRIVATE #RSTACK
PRIVATE $^  PRIVATE $LIMIT^
PRIVATE LSP^
PRIVATE HERE^ PRIVATE HLAST^ 

// Display time spent in the program

: .UPTIME
	TICKS start_ticks - 
	s>f TPMS s>f f/ f.  .'  ms.'  ;

PRIVATE start_ticks

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

: list_alias
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

: .ALIAS ALIAS^ list_alias ;

PRIVATE spacepad
PRIVATE list_alias
 

// -------------------------------------------------------
// display and count public words

ALIAS	countword 	a++
ALIAS	wordcount 	a
ALIAS 	wordsize	64
ALIAS 	lastword	255

: reset [ FLAT reset ]
	RMARGIN 1 TO LOCALS ;
  
: -margin ( n -- ) [ FLAT -margin ]
	1 LOCALS SWAP 1+ - 1 TO LOCALS ;

: reset? ( n -- ) [ FLAT reset? ]
	1 LOCALS 0< ;
 
: _words
	reset 
     DO 
		I >NAME C@ DUP 0> SWAP lastword <> AND IF
		 	I >NAME $. SPACE countword
			I >NAME $len -margin
			reset? IF CR reset THEN   
		 THEN 
	wordsize +LOOP 
	CR wordcount . SPACE .' - Counted words. '
	;

: WORDS FINAL^ `` (  _words ;

: ALLWORDS FINAL^ `` (EXIT)  _words ;

CLRALIAS
PRIVATE _words
PRIVATE reset    
PRIVATE -margin 
PRIVATE reset? 


// -------------------------------------------------------
// ALLOT bytes to a variable

ALIAS 	padding	8

: ALLOT ( n -- )
    1 PCHK
	LAST ALLOT? IF
		ALLOT^ + padding + ALIGN8 TO ALLOT^ 
		ALLOT.LAST^ LAST !
		ALLOT^ TO ALLOT.LAST^
	ELSE
		CR LAST >NAME $. SPACE 
		.' is not allotable '
	THEN 
;

// private (predefined) allot words.
PRIVATE ALLOT^ 
PRIVATE ALLOT.LAST^ 
PRIVATE ALLOT.LIMIT^ 
PRIVATE ALLOT?
CLRALIAS

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

' #[?25l' STRING coff 27 VALDAT coff C!

' #[?25h' STRING con 27 VALDAT con C!

' #[2K' STRING cln 27 VALDAT cln C!

: curoff coff $. ;
: curon con $. ;
: clrln cln $. ;

PRIVATE coff
PRIVATE con 
PRIVATE cln

// UTF8 characters
10062562 	VARIABLE ballone 
9869282  	VARIABLE lhc
9934818		VARIABLE rhc
10524386	VARIABLE fullblock

0 VARIABLE smallbat 24 ALLOT

ALIAS batlen a

: addtobat ( n -- )
    0 DO
	  SWAP DROP fullblock SWAP CCCPYC 
	LOOP ;

: makebat ( n --- )
    1 PARAMS
	lhc smallbat CCCPYC
     batlen addtobat 
	SWAP DROP rhc SWAP CCCPYC 
	DDROP
;

4 makebat 

ALIAS x a 
ALIAS y b 

1  VALUE batminx
80 VALUE batmax

40 VALUE batx
30 VALUE baty
0  VALUE batxdir
TCOL.green VALUE batclr

43 VALUE ballx
29 VALUE bally
FALSE VALUE ballfree
TCOL.red VALUE ballclr
0 VALUE ballxdir
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
	batx 3 + TO ballx 
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
			batx 3 + TO ballx 
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
  	 TICKS TO movetime
	 ballfree IF ballmove THEN
	 batmove
  THEN
  
  1 MS // do not use 100% CPU

AGAIN
;

// announce ourselves

// define the UTF8 unicode monster
3197214704 0 VARIABLE monster 8 ALLOT monster !

: MSTR 
	monster $. ;

: bold.green 
	TCOL.green FCOL TCOL.bold FCOL
;

: colr.reset 
	TCOL.reset FCOL
;

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

PRIVATE monster
PRIVATE bold.green 
PRIVATE colr.reset 

// off we go

Hi 

FORGET