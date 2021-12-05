### Benchmark

// Tests measure speed
// FIB measures the inner interprers call overhead really well.

: FIB ( n -- n1 )  DUP 1> IF  1- DUP 1- FIB SWAP FIB + THEN ;

: t1 25 0 DO 34 FIB LOOP ; // run many


: FAC DUP 1> IF DUP 1- FAC * ELSE DROP 1 ENDIF ;


: t2 100 FAC ;


TIMEIT t1

// 27th November 2021
TIMEIT t1
9781  : ms to run ( 97813  ) ns 

// 29th November 2021 - more reasonable.
FASTER FIB // not traceable
TIMEIT t1
3864  : ms to run ( 38647  ) ns 
 
// PRIME SIEVE benchmark

8192 CARRAY FLAGS   

0 VARIABLE EFLAG 

8190 FLAGS EFLAG ! 

 

: PRIMES  ( -- n )  1 FILLARRAY FLAGS 0 3  EFLAG @ 0 FLAGS
  DO   I C@
       IF  DUP I + DUP EFLAG @ <
           IF    EFLAG @ SWAP
                 DO  0 I C! DUP  +LOOP
           ELSE  DROP  THEN  SWAP 1+ SWAP
           THEN  2+
       LOOP  DROP ;

: BENCHMARK  0 1000 0 DO  PRIMES NIP  LOOP ;

: t2 25 0 DO 8190 FLAGS EFLAG ! BENCHMARK LOOP ;



// 432 ms Sat 4th December
// t2 10357  : ms to run ( 103577  ) ns 

// After adding FILLARRAY word.
// t2 7895  : ms to run ( 78951  ) ns 

