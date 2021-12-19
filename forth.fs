// forth.fs is loaded when FORTH starts.

TICKS 0 TO LOCALS // start time

: SQUARE DUP * ;

: QUADRATIC  ( a b c x -- n )   >R SWAP ROT R@ *  + R> *  + ;

PAGE

.VERSION

WORDS CR

.' forth.fs loaded in '  TICKS 0 LOCALS - s>f TPMS s>f f/ f.  .' ms'  
