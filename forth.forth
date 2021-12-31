// This file is loaded as FORTH starts.
TICKS VALUE start_ticks

// Offsets from a words header
8 ADDS >RUN
16 ADDS >ARG2  
24 ADDS >COMP
32 ADDS >DATA1  
40 ADDS >DATA2  
48 ADDS >NAME


: PRIVATE 0 ` >NAME C! ; 

// avoid being annoyed by the Ok prompt
: LOUD FALSE TO BEQUIET ; 
: QUIET TRUE TO BEQUIET ;  PRIVATE BEQUIET QUIET

// Display time spent in the program

: UPTIME TICKS 
    start_ticks - s>f TPMS s>f f/ f.  .'  ms.'  ;

PRIVATE start_ticks


// STRINGS 
: $empty? 0= IF TRUE ELSE C@ 0= THEN  ;

// Add common constants
3.14159265359   CONSTANT PI

 
// Add the very common fast add and subtract words
1 ADDS 1+ 1 SUBS 1-
2 ADDS 2+ 1 SUBS 2-



// ----------------------------------------------
// display and count public words
// respect the right margin

: reset [ FLAT reset ]
	RMARGIN 1 TO LOCALS ;
  
: -margin ( n -- ) [ FLAT -margin ]
	1 LOCALS SWAP 1+ - 1 TO LOCALS ;

: reset? ( n -- ) [ FLAT reset? ]
	1 LOCALS 0< ;
 
: _words
	reset 
     DO 
		I >NAME C@ DUP 0> SWAP 255 <> AND IF
		 	I >NAME $. SPACE a++
			I >NAME $len -margin
			reset? IF CR reset THEN   
		 THEN 
	64 +LOOP 
	CR a . SPACE .' - Counted words. '
	;

: WORDS FINAL^ `` (  _words ;

: ALLWORDS FINAL^ `` (END)  _words ;

PRIVATE _words
PRIVATE reset    
PRIVATE -margin 
PRIVATE reset? 


// ----------------------------------------------
// ALLOT space to variable or created word
// e.g. CREATE test 100 ALLOT
// applies to last word created.

	: ALLOT ( n -- )
	  LAST ALLOT? IF
		ALLOT^ + 16 + ALIGN8 TO ALLOT^ 
		ALLOT.LAST^ LAST !
		ALLOT^ TO ALLOT.LAST^
	  ELSE .' Not allotable ' 
	  THEN 
	;



// announce ourselves
PAGE 
.VERSION 
CR WORDS CR
.' forth.fs  loaded in '  UPTIME 
 
