### Benchmark

// Tests measure speed
// FIB measures the inner interprers call overhead really well.

: FIB ( n -- n1 )
  DUP 1> IF
  1- DUP 1- FIB SWAP FIB + THEN
;

: t1 25 0 DO 34 FIB LOOP ; // run many


TIMEIT t1

// 27th November 2021
TIMEIT t1
9781  : ms to run ( 97813  ) ns 

// 29th November 2021 - more reasonable.
FASTER FIB // not traceable
TIMEIT t1
3864  : ms to run ( 38647  ) ns 
 
