// forth.fs - this file is loaded when FORTH starts.
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



: $empty? 0= IF TRUE ELSE C@ 0= THEN  ;

// Add common constants
3.14159265359   CONSTANT PI

 
// Add the very common fast add and subtract words
1 ADDS 1+ 1 SUBS 1-
2 ADDS 2+ 1 SUBS 2-

// Add the very common fast shifts 
1 SHIFTSL 2* 2 SHIFTSL 4* 3 SHIFTSL 8*
1 SHIFTSR 2/ 2 SHIFTSR 4/ 3 SHIFTSR 8/



// announce ourselves
// PAGE 
.' Small FORTH for Apple Silicon '
.VERSION WORDS CR
.' forth.fs  loaded in '  UPTIME 
 
