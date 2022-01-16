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

: BENCHMARK FLAGS 8190 + EFLAG ! 0 1000 0 DO  PRIMES NIP LOOP ;

: primetime 25 TIMESDO BENCHMARK  ;

TIMEIT primetime