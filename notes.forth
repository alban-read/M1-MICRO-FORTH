 
// accessors 
: set-address [ FLAT set-address ]
    0 TO LOCALS ;
: address [ FLAT address ]
    0 LOCALS ;

: COMPILETIME
    ` set-address 
    address @ address >ARGUMENT2 !
    address >RUNTIME @ address >COMPTIME !
    0 address !
    0 address >RUNTIME !
    ;
 


// ---------------------------------------------------------------------
// CLEAR a STRINGs VALUE
// CLRSTRING myString
// Since strings are shared by all words you need to be sure about this
 

: CLR-STRING ( address)
    // get the address of the word.
    set-address 
    // strings always have 255 at extra DAT 1, so check that.
    address  >DATA1 @ 255 <>  IF EXIT THEN 
    // check for zero already on the storage pointer
    address @ 0=  IF EXIT THEN 
    // brutally clear the strings backing storage 
    255 0 address @ FILL 
    // point the string to nowhere. 
    0 address ! 
    ;

// command
: CLRSTR 
    ` CLR-STRING ;
 
// use when compiled 
// `` stringname CLR-STRING
