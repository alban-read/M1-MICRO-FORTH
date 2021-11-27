

: ?DAY  DUP 1 <  SWAP 31 > +  IF .' No way ' ELSE .' Looks good ' THEN ;

: RECT 255 0 DO I 16 MOD 0= IF  CR  THEN .' *' LOOP ;

: TABLE  CR 11 1 DO  11 1 DO  I J *  .  SPACE LOOP CR LOOP ;

: FIB  
  DUP 2 < IF
   DROP 1
  ELSE
   DUP
   1- FIB
   SWAP 2 - FIB
   +
 THEN ;

 : run-fib 
 TICKS 
    25 0 DO 
        34 FIB DROP 
    LOOP 
 TICKS SWAP - TPMS / . ;