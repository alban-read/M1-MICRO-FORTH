

: ?DAY  DUP 1 <  SWAP 31 > +  IF .' No way ' ELSE .' Looks good ' THEN ;

: RECT 255 0 DO I 16 MOD 0= IF  CR  THEN .' *' LOOP ;

: TABLE  CR 11 1 DO  11 1 DO  I J *  .  SPACE LOOP CR LOOP ;


// no longer compiles !!!! 
// 14th JAN 2022
// I thought this related to string pool changes but not the case.
// some problem with multiple IF, ELSE, THEN ?

: eggtest  
   DUP 18 < IF  .' reject '     ELSE 
   DUP 21 < IF  .' small '       ELSE  
   DUP 24 < IF  .' medium '      ELSE 
   DUP 27 < IF  .' large '       ELSE  
   DUP 30 < IF  .' extra large ' ELSE
      .' error ' 
   THEN THEN THEN THEN THEN DROP ; 

// no longer compiles !!!! 
// 14th JAN 2022
: eggtest  
   DUP 18 < IF  0    ELSE 
   DUP 21 < IF  1      ELSE  
   DUP 24 < IF  2      ELSE 
   DUP 27 < IF  3      ELSE  
   DUP 30 < IF  4 ELSE
      5
   THEN THEN THEN THEN THEN DROP ; 



: BOXTEST ( length width height -- )
   6 >  ROT 22 >  ROT 19 >  AND AND IF .' Big enough ' THEN ;

: QUADRATIC  ( a b c x -- n )   >R SWAP ROT R@ *  + R> *  + ;


10 VALUE BASE
: U.             
   BASE /MOD      
      ?DUP IF          
      U.        
   THEN
   DUP 10 < IF
      CHAR 0        
   ELSE
      10 -           
      CHAR A
   THEN
   +
   EMIT
   ;