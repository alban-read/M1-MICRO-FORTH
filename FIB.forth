// FIB measures the inner interpreters call overhead really well.
// it is a benchmark of call speed.

: FIB ( n -- n1 ) [ FLAT FIB ]
  DUP 1> IF  1- DUP 1- FIB SWAP FIB + THEN ; 

: FIB34 [ FLAT FIB34 ] 34 FIB DROP ; 

: t1 25 TIMESDO FIB34 ;

TIMEIT t1