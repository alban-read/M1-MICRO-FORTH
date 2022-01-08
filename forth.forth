// This file is loaded as FORTH starts.
// -------------------------------------------------------
// Set up the Dynamic Memory areas

// initially the stack is tiny, set the new parameter stack size (in cells)
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
8 ADDS >RUN
16 ADDS >ARG2  
24 ADDS >COMP
32 ADDS >DATA1  
40 ADDS >DATA2  
48 ADDS >NAME

// common constants 
-1 CONSTANT -1

: PRIVATE 0 ` >NAME C! ; 

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
 1  ADDS 1+ 1 SUBS 1-
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
	CR .' ALIAS words '
	BEGIN
		a @ 0= IF EXIT THEN
		CR a $. SPACE .' ALIAS OF ' a 16+ $.
		a 32+ a!
	AGAIN
	CR
;

: .ALIAS ALIAS^ list_alias ;

PRIVATE list_alias
PRIVATE ALIAS^

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
: $empty? 0= IF TRUE ELSE C@ 0= THEN  ;


// how many times is substr in str

ALIAS countit a++
ALIAS counted a 

: $occurs ( substr str -- count )  
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

` exp ` ^ CCPY DDROP FORGET


// announce ourselves

PAGE 

32 TFCOL

MSTR SPACE .VERSION 

34 TFCOL

CR WORDS CR
.' forth.forth  loaded in '  .UPTIME 
 
33 TFCOL