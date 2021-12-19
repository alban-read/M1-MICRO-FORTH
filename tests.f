

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



 