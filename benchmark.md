### Benchmark

Tests show that the interpreter is very slow.
Good, speeding it up will be interesting.
FIB measures the inner interprers call overhead really well.

 
: FIB 
  DUP 1> IF
  1- DUP 1- FIB SWAP FIB + THEN
;
 
: t1 25 0 DO 34 FIB LOOP ;

TIMEIT t1


27th November 2021
TIMEIT t1
9781  : ms to run ( 97813  ) ns 
