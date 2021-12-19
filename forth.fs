// forth.fs is loaded when FORTH starts.
// add any extension words here.
// the words here are just test words.

// dumb fib

: FIB ( n -- n1 )  DUP 1> IF  1- DUP 1- FIB SWAP FIB + THEN ;

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

: PRIMETEST 25 0 DO FLAGS 8190 + EFLAG ! BENCHMARK LOOP ;

: SQUARE DUP * . ;

: ?DAY  DUP 1 <  SWAP 31 > +  IF .' No way ' ELSE .' Looks good ' THEN ;

: RECT 255 0 DO I 16 MOD 0= IF  CR  THEN .' *' LOOP ;

: TABLE  CR 11 1 DO  11 1 DO  I J *  .  SPACE LOOP CR LOOP ;

: EGGSIZE
   DUP 18 < IF  .' reject '     ELSE
   DUP 21 < IF  .' small '      ELSE
   DUP 24 < IF  .' medium '     ELSE
   DUP 27 < IF  .' large '      ELSE
   DUP 30 < IF  .' extra large' ELSE
      .' error '
   THEN THEN THEN THEN THEN DROP ;

: BOXTEST ( length width height -- )
   6 >  ROT 22 >  ROT 19 >  AND AND IF .' Big enough ' THEN ;

: QUADRATIC  ( a b c x -- n )   >R SWAP ROT R@ *  + R> *  + ;



PAGE

.VERSION

WORDS CR

.' forth.fs completed..'