// misc FORTH words

: ?DAY  DUP 1 <  SWAP 31 > +  IF .' No way ' ELSE .' Looks good ' THEN ;

: RECT 255 0 DO I 16 MOD 0= IF  CR  THEN .' *' LOOP ;

: TABLE  CR 11 1 DO  11 1 DO  I J *  .  SPACE LOOP CR LOOP ;

: eggtest  
   DUP 18 < IF  .' reject '     ELSE 
   DUP 21 < IF  .' small '       ELSE  
   DUP 24 < IF  .' medium '      ELSE 
   DUP 27 < IF  .' large '       ELSE  
   DUP 30 < IF  .' extra large ' ELSE
      .' error ' 
   THEN THEN THEN THEN THEN DROP ; 


: BOXTEST ( length width height -- )
   6 >  ROT 22 >  ROT 19 >  AND AND IF .' Big enough ' THEN ;

: QUADRATIC  ( a b c x -- n )   >R SWAP ROT R@ *  + R> *  + ;


// this does not work, which means something is wrong 
// so one of these words is probably incorrect.
// ...

: U/MOD ( N D -- R Q )
    ?DUP 0= IF .' DIVISION BY ZERO ' EXIT THEN
    0 >R 2>R		 
    0 1 BEGIN ?DUP WHILE DUP 2* REPEAT
    R> 0 BEGIN		 
      2*		 
      R@ 0< IF 1+ THEN	 
      R> 2* >R		 
      2DUP > IF ROT DROP ELSE  
        OVER -		     
        ROT R> R> ROT + >R >R  
      THEN
      2>R ?DUP 2R> ROT 0= UNTIL
    NIP R> DROP R> ;