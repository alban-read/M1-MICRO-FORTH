// forth.fs - this file is loaded when FORTH starts.
// 
TICKS VALUE start_ticks

// Conceal words, used in implementations
48 ADDS >NFA : HIDE 0 ` >NFA C! ; 

// avoid being annoyed by Ok prompt
: LOUD FALSE TO BEQUIET ; 
: QUIET TRUE TO BEQUIET ;  HIDE BEQUIET

// Display time spent in the program
: UPTIME TICKS 
    start_ticks - s>f TPMS s>f f/ f.  .'  ms.'  ;
HIDE start_ticks


// hide words under development still.
HIDE DECR
HIDE INCR
HIDE MAP

// Add common constants
3.14159265359   CONSTANT PI

// Add the very common fast add and subtract words
1 ADDS 1+ 1 SUBS 1-

// Add the very common fast shifts 
1 SHIFTSL 2* 2 SHIFTSL 4* 3 SHIFTSL 8*
1 SHIFTSR 2/ 2 SHIFTSR 4/ 3 SHIFTSR 8/

: SQUARE DUP * ;

: QUADRATIC  ( a b c x -- n )   
    >R SWAP ROT R@ *  + R> *  + ;


// announce ourselves
PAGE .VERSION WORDS CR
.' forth.fs for Apple Silicon loaded in '  UPTIME 
 
 