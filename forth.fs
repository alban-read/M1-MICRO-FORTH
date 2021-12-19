// forth.fs is loaded when FORTH starts.


: SQUARE DUP * ;

: QUADRATIC  ( a b c x -- n )   >R SWAP ROT R@ *  + R> *  + ;


PAGE

.VERSION

WORDS CR

.' forth.fs completed..'