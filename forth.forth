// startup
TICKS 

// this is the token space
4 1024 2 * * HEAPSIZE
HEAP^ ALIGN8 DUP TO HERE^ TO HLAST^ 

// this is the locals stack
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
3 SHIFTSL 8* 3 SHIFTSR 8/


// -------------------------------------------------------
// print numbers

10 VALUE BASE

: U.             
   BASE /MOD      
      ?DUP IF          
      U.        
   THEN
   DUP 10 < IF
      CHAR 0        
   ELSE
      10 -           
      CHAR A
   THEN
   +
   EMIT
   ;

// copy number to string. 
: U,             
   BASE /MOD      
      ?DUP IF          
      U,        
   THEN
   DUP 10 < IF
      CHAR 0        
   ELSE
      10 -           
      CHAR A
   THEN
   +
   ,
   ;


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

//  allows 'A' rather than CHAR A  

16 STRING _left
16 STRING _right

: _alias_letters
	2 PARAMS
	126 32 DO  
		a >LAST 0 a 40 + !
		CHAR ' , I , CHAR ' ,
		b >LAST 0 b 40 + !
		I U, 
		_right _left (ALIAS)
	LOOP ;		
 
` _left ` _right _alias_letters


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
		I >NAME C@ DUP '_' <> SWAP lastword <> AND IF
		 	I >NAME $. SPACE countword
			I >NAME $len _words_margin 
			_reset? IF CR _words_reset THEN   
		 THEN 
	wordsize +LOOP 
	CR wordcount . SPACE .' - Counted words. '
	;

: WORDS FINAL^ `` (  _words ;

: ALLWORDS FINAL^ `` (EXIT)  _words ;

UNALIAS	countword 	 
UNALIAS	wordcount  
UNALIAS lastword	 
UNALIAS wordsize	 

// -------------------------------------------------------
// displays key codes until Q

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

UNALIAS pausetime

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
 
UNALIAS countit 
UNALIAS counted

// redefine  ^
// ^ is predefined without any action.

:: ^ 
   OVERSWAP 1 ?DO OVER * LOOP NIP ; 

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

: Hi 
	// PAGE
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

 