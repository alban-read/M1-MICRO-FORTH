### Benchmark

// Tests measure speed
// FIB measures the inner interprers call overhead really well.

: FIB ( n -- n1 )  DUP 1> IF  1- DUP 1- FIB SWAP FIB + THEN ;

: t1 25 0 DO 34 FIB LOOP ; // run many


TIMEIT t1

// 27th November 2021
TIMEIT t1
9781  : ms to run ( 97813  ) ns 

// 29th November 2021 - more reasonable.
FASTER FIB // not traceable
TIMEIT t1
3864  : ms to run ( 38647  ) ns 
 
// PRIME SIEVE benchmark
// tests variety of features.
 
CREATE FLAGS 8190 ALLOT
0 VARIABLE EFLAG
FLAGS 8190 + EFLAG !

: PRIMES  ( -- n )  FLAGS 8190 1 FILL  0 3  EFLAG @ FLAGS
  DO   I C@
       IF  DUP I + DUP EFLAG @ <
           IF    EFLAG @ SWAP
                 DO  0 I C! DUP  +LOOP
           ELSE  DROP  THEN  SWAP 1+ SWAP
           THEN  2+
       LOOP  DROP ;

: BENCHMARK  0 1000 0 DO  PRIMES NIP  LOOP ;

: pt2 25 0 DO FLAGS 8190 + EFLAG ! BENCHMARK LOOP ;

// 432 ms Sat 4th December
// t2 10357  : ms to run ( 103577  ) ns 
// t2 8043 ms // after adding FILL.


: FAC DUP 1> IF DUP 1- FAC * ELSE DROP 1 ENDIF ;
: t3 100 FAC ;