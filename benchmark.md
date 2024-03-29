### Benchmark

// Tests measure speed
// FIB measures the inner interpreters call overhead really well.
// it is a benchmark of call speed.

: FIB ( n -- n1 ) [ FLAT FIB ]
  DUP 1> IF  1- DUP 1- FIB SWAP FIB + THEN ; 

: FIB34 [ FLAT FIB34 ] 34 FIB DROP ; 

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


// 26th December
TIMEIT t1
3397  : ms to run ( 33978  ) ns 

// Jan 16th
FLOAD FIB.forth
3413  : ms to run ( 34136  ) ns 


// PRIME SIEVE benchmark
// tests variety of features.
 
CREATE FLAGS 8190 ALLOT
0 VARIABLE EFLAG
FLAGS 8190 + EFLAG !

: PRIMES  ( -- n )  [ FLAT PRIMES ]
  FLAGS 8190 1 FILL  0 3  EFLAG @ FLAGS
  DO   I C@
       IF  DUP I + DUP EFLAG @ <
           IF    EFLAG @ SWAP
                 DO  0 I C! DUP  +LOOP
           ELSE  DROP  THEN  SWAP 1+ SWAP
           THEN  2+
       LOOP  DROP ;

: BENCHMARK FLAGS 8190 + EFLAG ! 0 1000 0 DO  PRIMES NIP  LOOP ;

: t2 25 TIMESDO  BENCHMARK  ;

// 432 ms Sat 4th December
// t2 10357  : ms to run ( 103577  ) ns 
// t2 8043 ms // after adding FILL.

// 26th December
// t2 7851  : ms to run ( 78510  ) ns 
// t2 (FLAT) 6978  : ms to run ( 69781  ) ns 


// 16th January
FLOAD PRIME.forth
7953  : ms to run ( 79535  ) ns 
 
8295  : ms to run ( 82956  ) ns 
8299  : ms to run ( 82998  ) ns 

4463  : ms to run ( 44630  ) ns 
4344  : ms to run ( 43442  ) ns 


 