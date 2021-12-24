// forth.fs - this file is loaded when FORTH starts.
 
TICKS VALUE start_ticks

: HIDE 0 ` 48 + C! ;
: LOUD FALSE TO BEQUIET ; : QUIET TRUE TO BEQUIET ; 
HIDE BEQUIET QUIET

// words under development still.
HIDE DECR
HIDE INCR



3.14159265359   CONSTANT PI

// common fast add and subtract
1 ADDS 1+ 1 SUBS 1-

// common fast shifts 
1 SHIFTSL 2* 2 SHIFTSL 4* 3 SHIFTSL 8*
1 SHIFTSR 2/ 2 SHIFTSR 4/ 3 SHIFTSR 8/



// : SQUARE DUP * ;

// : QUADRATIC  ( a b c x -- n )   >R SWAP ROT R@ *  + R> *  + ;

PAGE

.VERSION

WORDS CR

.' forth.fs loaded in '  TICKS start_ticks - s>f TPMS s>f f/ f.  .'  ms.'  
 
 