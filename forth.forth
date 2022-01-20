// startup


// this is the token space
4 1024 2 * * HEAPSIZE
HEAP^ ALIGN8 DUP TO HERE^ TO HLAST^ 

// this is the locals stack
80 256 * HEAPSIZE HEAP^ ALIGN8 TO LSP^
 
// --------------------------------------------- 
// everything below here is optional 


// save start time from here.
 TICKS  VALUE _start_ticks

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
	TICKS _start_ticks - 
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

: HEX 16 TO BASE ;

: _U.             
   BASE /MOD      
      ?DUP IF          
      _U.        
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

: UWIDTH	 
	BASE /	 
	?DUP IF		 
		UWIDTH 1+	 
	ELSE
		1
	THEN
;

: U.R		 
	SWAP	 
	DUP		 
	UWIDTH		 
	ROT		 
	SWAP -		 
	SPACES
	_U.
;


: .R		 
	SWAP DUP 0< IF
		NEGATE		 
		1		 
		SWAP		 
		ROT		 
		1-		 
	ELSE
		0 SWAP ROT		 
	THEN
		SWAP DUP UWIDTH		 
		ROT	SWAP - SPACES	 
		SWAP	 
	IF			 
		CHAR - EMIT
	THEN
	_U.
;

: U. _U. SPACE ;

:: . 0 .R SPACE ;

// -------------------------------------------------------
// Misc 
 


: MAX 2DUP > IF DROP ELSE NIP THEN ;
: MIN 2DUP > IF SWAP THEN DROP ;
: LIMIT ROT MIN MAX ;
: ODD 1 AND ;
: EVEN 1 AND  0= ;
: UM/MOD 2DUP / a! MOD a ;
: UNDER >R DUP R> ;
: WITHIN OVER - a! - a  < ;
 


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

'' ALIAS 0 	

// -------------------------------------------------------
// handy shell commands

: ls ' ls -l ' SYSTEM ;


// -------------------------------------------------------
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
// display and count public words

ALIAS	countword 	a++
ALIAS	wordcount 	a
ALIAS 	wordsize	64
ALIAS 	lastword	255


// colour in some broad classes of word

// word class 
: WC 1 PCHK 
	` DUP 0= IF 
		CR .' Word Class Error' EXIT 
	ELSE 
		>RUN @ 
	THEN ;

WC .UPTIME  CONSTANT _interp_word
WC APPEND^  CONSTANT _value_word
WC APPEND$ CONSTANT _variable_word
WC _left CONSTANT _string_word 


// word classes
32 STACK _cmp_only
TRUE      TO _cmp_only
WC IF 	  TO _cmp_only	
WC ?IF 	  TO _cmp_only	
WC UNTIL  TO _cmp_only	
WC THEN   TO _cmp_only	
WC WHILE  TO _cmp_only	
WC REPEAT TO _cmp_only	
WC AGAIN  TO _cmp_only	
WC BEGIN  TO _cmp_only	
WC LOOP   TO _cmp_only	
WC +LOOP  TO _cmp_only	
WC -LOOP  TO _cmp_only	
WC ENDIF  TO _cmp_only	
WC DO  	  TO _cmp_only	
WC ?DO    TO _cmp_only	 
WC LEAVE  TO _cmp_only	 
WC ELSE   TO _cmp_only	  
WC EXIT   TO _cmp_only	
WC I   	  TO _cmp_only	
WC J      TO _cmp_only	
WC K      TO _cmp_only	
WC PCHK   TO _cmp_only	
 
32 STACK _locals_only
TRUE	TO _locals_only
WC a	TO _locals_only	
WC b	TO _locals_only	
WC c	TO _locals_only	
WC d	TO _locals_only	
WC e	TO _locals_only	
WC f	TO _locals_only	
WC g	TO _locals_only	
WC h	TO _locals_only	
WC a!	TO _locals_only	
WC b!	TO _locals_only	
WC c!	TO _locals_only	
WC d!	TO _locals_only	
WC e!	TO _locals_only	
WC f!	TO _locals_only	
WC g!	TO _locals_only	
WC h!	TO _locals_only	
WC a++	TO _locals_only	
WC b++	TO _locals_only	
WC c++	TO _locals_only	
WC d++	TO _locals_only	
WC PARAMS TO _locals_only	 
WC LOCALS TO _locals_only	
WC WLOCALS TO _locals_only	
 
: _locals_word? 
  b!
  32 `` _locals_only >ARG2 !  
  BEGIN 
	_locals_only a!
	a TRUE = IF FALSE EXIT THEN 
	b a = IF TRUE EXIT THEN 
  AGAIN 
;

: _comp_word? 
  b!
  32 `` _cmp_only >ARG2 !  
  BEGIN 
	_cmp_only a!
	a TRUE = IF FALSE EXIT THEN 
	b a = IF TRUE EXIT THEN 
  AGAIN 
;

: _colour_word ( a -- )

	b! b >RUN @ a!

	a _interp_word = IF
		TCOL.bold FCOL TCOL.yellow FCOL 
		b >NAME $. EXIT 
	THEN 

	a _value_word = IF 
		TCOL.cyan FCOL 
		b >NAME $. EXIT 
	THEN 

	a _variable_word = IF 
		TCOL.magenta FCOL 
		b >NAME $. EXIT 
	THEN 

	a _string_word  = IF 
		TCOL.green FCOL 
		b >NAME $. EXIT 
	THEN 

	a _comp_word? IF 
		TCOL.red FCOL 
		b >NAME $. EXIT    
	THEN 

	a _locals_word? IF 
		TCOL.bold  FCOL  TCOL.green FCOL 
		b >NAME $. EXIT    
	THEN 

	// otherwise 

	TCOL.blue FCOL
	b >NAME $.
;

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
		 	I _colour_word SPACE countword
			I >NAME $len _words_margin 
			_reset? IF CR _words_reset THEN   
		 THEN 
	wordsize +LOOP 

	TCOL.reset FCOL
	CR wordcount . SPACE .' - Counted words. '
	;

// shows compiler and hidden words
: _words_ 
	_words_reset 
     DO 
		I >NAME C@ lastword <>  IF
		 	I _colour_word SPACE countword
			I >NAME $len _words_margin 
			_reset? IF CR _words_reset THEN   
		 THEN 
	wordsize +LOOP 

	TCOL.reset FCOL
	CR wordcount . SPACE .' - Counted words. '
	;


:: WORDS FINAL^ `` (  _words ;

: ALLWORDS FINAL^ `` (EXIT)  _words_ ;

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

// A..C$ are raw character buffers 
// A is the append target used by $+
// B is the general buffer
// C is just free space 

: CLR.A$ 0 A$ C! ;
: CLR.B$ 0 B$ C! ;
: CLR.C$ 0 C$ C! ;

// copy zero term A to C
: A$>C$
    A$ C$
	BEGIN 
		CPYC
	OVER C@ 0= 	UNTIL 
;

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


// announce ourselves

// define the UTF8 unicode monster
8 STRING _mstr 0xF0 , 0x9F , 0x91 , 0xBE , 0 , 

: MSTR 
	_mstr $. ;

: bold.green 
	TCOL.green FCOL TCOL.bold FCOL
;

: colr.reset 
	TCOL.reset FCOL
;

: Hi 
	PAGE
	CR bold.green 
	MSTR SPACE .VERSION 
	colr.reset 
	TCOL.blue FCOL
	WORDS CR
	.' forth.forth  loaded in '  .UPTIME 
	colr.reset 
;


// off we go 

Hi 

 