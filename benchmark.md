### Benchmark

// Tests measure speed
// FIB measures the inner interpreters call overhead really well.
// it is a benchmark of call speed.

: FIB ( n -- n1 )  DUP 1> IF  1- DUP 1- FIB SWAP FIB + THEN ; FLAT FIB

: FIB34 34 FIB DROP ; FLAT FIB34

: t1 25 TIMESDO FIB34 ;

TIMEIT t1

// 27th November 2021
TIMEIT t1
9781  : ms to run ( 97813  ) ns 

// 29th November 2021 - more reasonable.
FASTER FIB // not traceable
TIMEIT t1
3864  : ms to run ( 38647  ) ns 
 

// 23rd December
TIMEIT t1
3574  : ms to run ( 35741  ) ns 

// just for comparison, FFIB is a fast iterative assembler version.
// not useful as a benchmark.
: FFIB34 [ FLAT ] 34 FFIB DROP ;
: t2 10000 10000 * TIMESDO FFIB34 ;
TIMEIT t2
245  : ms to run ( 2458  ) ns 


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