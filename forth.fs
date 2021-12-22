// forth.fs is loaded when FORTH starts.


TICKS VALUE start_ticks

// : SQUARE DUP * ;

// : QUADRATIC  ( a b c x -- n )   >R SWAP ROT R@ *  + R> *  + ;

PAGE

.VERSION

WORDS CR

.' forth.fs loaded in '  TICKS start_ticks - s>f TPMS s>f f/ f.  .'  ms.'  

 