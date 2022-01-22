// batball

// -------------------------------------------------------
// Terminal Brick Out.
// a dumb game on the terminal using ansi escape codes.
// 

8 STRING coff 
	27 , '[' , '?' , '2' , '5' , 'l' ,  0 ,	 

8 STRING con
	27 , '[' , '?' , '2' , '5' , 'h' ,  0 ,	 

8 STRING cln
	27 , '[' , '2' , 'K' , 0 ,
 

: curoff coff $. ;
: curon con $. ;
: clrln cln $. ;

4 STRING ballone 
	0xE2 , 0x97 , 0xAF , 0 , 

4 STRING balltwo 
	0xE2 , 0x8D , 0x9F , 0 ,

4 STRING ballthree
	0xE2 , 0x8A , 0x9B , 0 ,

4 STRING ballfour
	0xE2 , 0x8A , 0x9A , 0 ,


4 STRING ballfive
	0xE2 , 0x9A  , 0xAB , 0 ,

4 STRING ballsix
	0xE2 , 0x9A , 0xAA , 0 ,


4 STRING badfall1
	0xE2 , 0x98 , 0xA2 , 0 ,

4 STRING badfall2
	0xE2 , 0x98 , 0xA3 , 0 ,

4 STRING badfall3
	0xE2 , 0x98 , 0xA0 , 0 ,

4 STRING goodf01
	0xE2 , 0x98 , 0xAE , 0 ,

4 STRING goodf02
	0xE2 , 0x9A , 0x9B , 0 ,

4 STRING goodf03
	0xE2 , 0x9A , 0x9A , 0 ,

4 STRING goodf04
	0xE2 , 0x9A , 0x98 , 0 ,

24 STRING smallbat 
	0xE2 , 0x97 , 0x96 ,
	0xE2 , 0x96 , 0xA0 ,
   	0xE2 , 0x96 , 0xA0 ,
 	0xE2 , 0x96 , 0xA0 ,
	0xE2 , 0x97 , 0x97 ,
	0 ,


24 STRING widebat 
	0xE2 , 0x97 , 0x96 ,
	0xE2 , 0x96 , 0xA0 ,
   	0xE2 , 0x96 , 0xA0 ,
 	0xE2 , 0x96 , 0xA0 ,
	0xE2 , 0x96 , 0xA0 ,
 	0xE2 , 0x96 , 0xA0 ,
	0xE2 , 0x97 , 0x97 ,
	0 ,
 
: makesixl 
  2 PARAMS       
  240  a C! 159 a 1+ C! 172 a 2+ C! b a 3 + C!  
 ;
 

0 VARIABLE sixls 256 ALLOT 
 
: makesxls 
	128 a!
	640 0 DO 
		a sixls I + makesixl 
		a++
	8 +LOOP 
;
 
: .sixl ( n )
	8* sixls + $.
;

 
// so we can pick one
: .sixls 64 0 DO I .sixl '=' EMIT I . SPACE LOOP ;

: .brick 
	56 48 48 48 52
	5 TIMESDO .sixl
;

: .bricks 
	9 0 DO 
	  .brick SPACE SPACE
	LOOP 
;

: .wall 
	6  10 AT 
	TCOL.cyan FCOL .bricks  
	8  10 AT 
	TCOL.magenta FCOL .bricks  
	10 10 AT 
	TCOL.yellow FCOL .bricks  
	12 10 AT 
	TCOL.green FCOL .bricks  
	14 10 AT
	TCOL.blue FCOL .bricks  
	16 10 AT
	TCOL.red FCOL .bricks  
;
 


2  VALUE batminx
80 VALUE batmax

40 §x!
30 §y!


0  VALUE batxdir
TCOL.green VALUE batclr
 
43 VALUE ballx
29 VALUE bally
FALSE VALUE ballfree
TCOL.red VALUE ballclr

0  VALUE ballxdir
-1 VALUE ballydir
0 VALUE movetime

0 VALUE keypresses

: atbat ( x y  --- )
	batclr FCOL 
	§y §x AT clrln
	§y §x AT smallbat $. 	
;

: atball ( x y  --- )
    x! y!
	ballclr FCOL 
	ballfree 0= IF 	x y AT clrln THEN
	x y AT ballone $. 	
;

: batsball 
	FALSE TO ballfree
	 §x 2 + TO ballx 
	 §y 1- TO bally
;

: showbat ( ) 
	atbat ;
 
: showball ( ) 
	ballx bally atball ;

: ballmove 
		bally ballx AT 32 EMIT
		ballx ballxdir + TO ballx 
		bally ballydir + TO bally	
		bally 1 < IF 
			batsball
		THEN
		showball 
;


: batmove 
		 §x batxdir + §x! 
		 §x batmax > IF -1 TO batxdir THEN
		 §x batminx < IF 1 TO batxdir THEN
		showbat
		ballfree 0= IF
			 §x 2 + TO ballx 
			showball
		THEN 
;


// move bat when keys pressed.

// 
: batballxdir ( n -- )
	ballfree 0= IF 
		TO ballxdir
	ELSE DROP THEN 
 ;


: batleft 
	 §x batminx > IF 
		batxdir 1 = IF 
			0 TO batxdir
			0 batballxdir
		ELSE 
			-1 TO batxdir
			-1 batballxdir
		THEN
	THEN
;
: batright 
	 §x batmax < IF 
		batxdir -1 = IF 
			0 TO batxdir
			0 batballxdir
		ELSE 
			1 TO batxdir
			1 batballxdir
		THEN
	THEN
;


: batkeys  
batsball
TICKS TO movetime
NOECHO curoff
showbat showball
BEGIN
  KEY? IF 
	
	keypresses 1+ TO keypresses
	ballfree 0= keypresses 4 MOD 0= AND IF 
		 0 TO ballxdir
	THEN 

	KEY 
 
	DUP 'z' = IF 
		batleft
	THEN
	
	DUP 'x' = IF 
		batright
	THEN 
	
	DUP 32 = IF 
		 TRUE TO ballfree
	THEN 

	DUP 'q' = IF 
		curon DROP
		TCOL.reset FCOL 
		RETERM
		EXIT 
	THEN 
  
  THEN // key?

  FLUSH  

  // only update bat and ball at set rate
  TICKS movetime - 984000 > IF 
	 .wall
  	 TICKS TO movetime
	 ballfree IF ballmove THEN
	 batmove
  THEN
  
  1 MS // do not use 100% CPU

AGAIN
;

 

: START 
	PAGE
	makesxls 
	.wall
	batkeys
	;