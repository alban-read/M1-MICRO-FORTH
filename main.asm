;; reserved registers.
;; X18 reserved
;; X29 frame ptr
;; X30 aka LR
;; X28 data section pointer
;; this program links to the libc.

;; words are seperated by one or more spaces.
;; immediate words are capitalized and run as soon as they are seen
;; numeric values are converted to numbers and pushed to the stack.
;; 

.global main 

.align 4			 


 		; get line from terminal
getline:

		ADRP	X8, ___stdinp@GOTPAGE
		LDR		X8, [X8, ___stdinp@GOTPAGEOFF]
		LDR		X2, [X8]
	    ADRP	X28, zpadsz@PAGE	   
		ADD     X1, X28, zpadsz@PAGEOFF
		ADRP	X28, zpadptr@PAGE	
		ADD     X0, X28, zpadptr@PAGEOFF
		STP		LR, XZR, [SP, #-16]!	
		BL		_getline
		LDP		LR, XZR, [SP], #16	
		RET

   	    ; Ok prompt
sayok: 	
        ADRP	X28, ps2@PAGE	
		ADD		X0, X28, ps2@PAGEOFF
		B		sayit

saycr: 	
        ADRP	X28, ps6@PAGE	
		ADD		X0, X28, ps6@PAGEOFF
		B		sayit

saylb:
	 	ADRP	X28, ps7@PAGE	
		ADD		X0, X28, ps7@PAGEOFF
        B		sayit		

sayrb:
	 	ADRP	X28, ps8@PAGE	
		ADD		X0, X28, ps8@PAGEOFF
        B		sayit		


saybye:
	 	ADRP	X28, ps3@PAGE	
		ADD		X0, X28, ps3@PAGEOFF
        B		sayit

sayerrlength:
	 	ADRP	X28, ps5@PAGE	
		ADD		X0, X28, ps5@PAGEOFF
        B		sayit
				
sayword:
	 	ADRP	X28, zword@PAGE	
		ADD		X0, X28, zword@PAGEOFF
        B		sayit
				
sayunderflow:
	 	ADRP	X28, ps10@PAGE	
		ADD		X0, X28, ps10@PAGEOFF
        B		sayit


sayeol:
		ADRP	X28, ps4@PAGE	
		ADD		X0, X28, ps4@PAGEOFF
		BL		sayit
		B		finish

sayit:		
        STP		LR, XZR, [SP, #-16]!
		ADRP	X8, ___stdoutp@GOTPAGE
		LDR		X8, [X8, ___stdoutp@GOTPAGEOFF]
		LDR		X1, [X8]

 		STP		X1, X0, [SP, #-16]!
		BL		_fputs	 
		ADD     SP, SP, #16 
        
		
		LDP     LR, XZR, [SP], #16
		RET


resetword: ; out x22, x23
		; reset word to zeros; get zword into X22
		ADRP	X28, zword@PAGE	   
	    ADD		X22, X28, zword@PAGEOFF
		STP     XZR, XZR, [X22]
		STP     XZR, XZR, [X22, #8]
		ADRP	X28, zword@PAGE	   
	    ADD		X22, X28, zword@PAGEOFF
		RET

resetline:

		; get zpad address in X23
		ADRP	X28, zpad@PAGE	   
	    ADD		X23, X28, zpad@PAGEOFF
		MOV     X0, X23

		MOV     X1, #0
		STP		X1, X1, [X0], #16
		STP		X1, X1, [X0], #16
		STP		X1, X1, [X0], #16
		STP		X1, X1, [X0], #16

		STP		X1, X1, [X0], #16
		STP		X1, X1, [X0], #16
		STP		X1, X1, [X0], #16
		STP		X1, X1, [X0], #16

		; 128

		STP		X1, X1, [X0], #16
		STP		X1, X1, [X0], #16
		STP		X1, X1, [X0], #16
		STP		X1, X1, [X0], #16

		STP		X1, X1, [X0], #16
		STP		X1, X1, [X0], #16
		STP		X1, X1, [X0], #16
		STP		X1, X1, [X0], #16

		; 256

		STP		X1, X1, [X0], #16
		STP		X1, X1, [X0], #16
		STP		X1, X1, [X0], #16
		STP		X1, X1, [X0], #16

		STP		X1, X1, [X0], #16
		STP		X1, X1, [X0], #16
		STP		X1, X1, [X0], #16
		STP		X1, X1, [X0], #16

		; 384

		STP		X1, X1, [X0], #16
		STP		X1, X1, [X0], #16
		STP		X1, X1, [X0], #16
		STP		X1, X1, [X0], #16

		STP		X1, X1, [X0], #16
		STP		X1, X1, [X0], #16
		STP		X1, X1, [X0], #16
		STP		X1, X1, [X0], #16

		; 512

		STP		X1, X1, [X0], #16
		STP		X1, X1, [X0], #16
		STP		X1, X1, [X0], #16
		STP		X1, X1, [X0], #16

		STP		X1, X1, [X0], #16
		STP		X1, X1, [X0], #16
		STP		X1, X1, [X0], #16
		STP		X1, X1, [X0], #16
		RET

advancespaces: ; byte ptr in x23, advance past spaces until zero
10:		LDRB	W0, [X23]
		CMP		W0, #0
		B.eq	90f	
		CMP     W0, #32
		b.ne	90f
		ADD		X23, X23, #1
		B		10b
90:		RET


print: 			; prints top of stack		
		STP		LR, XZR, [SP, #-16]!
		ADRP	X28, dsp@PAGE	   
	    ADD		X28, X28, dsp@PAGEOFF
		LDR		X16, [X28]
		LDR		W1, [X16, #-4]
		SUB		X16, X16, #4
		STR		X16, [X28]

		ADRP	X28, spu@PAGE	   
	    ADD		X28, X28, spu@PAGEOFF
		CMP		X16, X28
		b.gt	12f	

		; reset stack
		ADRP	X27, sp1@PAGE	   
	    ADD		X27, X27, sp1@PAGEOFF
		ADRP	X28, dsp@PAGE	   
	    ADD		X28, X28, dsp@PAGEOFF
		STR		X27, [X28]
		; report underflow
		B.lt	sayunderflow
		
12:

	 	ADRP	X28, ps9@PAGE	   
		ADD		X0, X28, ps9@PAGEOFF
		STP		X1, X0, [SP, #-16]!
		BL		_printf		 
		ADD     SP, SP, #16 


		LDP		LR, XZR, [SP], #16	
		RET


word2number:	; converts ascii at word to 32bit number
		STP		LR, XZR, [SP, #-16]!
		ADRP	X28, zword@PAGE	   
	    ADD		X0, X28, zword@PAGEOFF
		BL		_atoi
		; push onto dsp
		; data stack pointer
		ADRP	X28, dsp@PAGE	   
	    ADD		X28, X28, dsp@PAGEOFF
		LDR		X16, [X28]
		STR		W0, [X16], #4
		STR		X16, [X28]
95:		LDP     LR, XZR, [SP], #16
		RET

collectword:  ; byte ptr in x23, x22 
			  ; copy and advance byte ptr until space.

		STP		LR, XZR, [SP, #-16]!
		; reset word to zeros;
		ADRP	X28, zword@PAGE	   
	    ADD		X22, X28, zword@PAGEOFF
		STP     XZR, XZR, [X22]
		STP     XZR, XZR, [X22, #8]
		ADRP	X28, zword@PAGE	   
	    ADD		X22, X28, zword@PAGEOFF

		MOV		W1, #0

10:		LDRB	W0, [X23], #1
		CMP		W0, #32
		b.eq	90f
		CMP		W0, #10
		B.eq	90f
		CMP		W0, #12
		B.eq	90f
		CMP		W0, #13
		B.eq	90f
 		CMP		W0, #0
		B.eq	90f

30:				
		STRB	W0, [X22], #1
		ADD		W1, W1, #1
		CMP		W1, #15
		B.ne	10b

		ADRP	X28, zword@PAGE	   
	    ADD		X22, X28, zword@PAGEOFF
		STP     XZR, XZR, [X22]
		STP     XZR, XZR, [X22, #8]
		ADRP	X28, zword@PAGE	   
	    ADD		X22, X28, zword@PAGEOFF
		
		BL		sayerrlength
		B		95f
		
20:		B     	10b
		 
90:		MOV     W0, #0x00
		STRB	W0, [X22], #1
		STRB	W0, [X22], #1
95:		LDP     LR, XZR, [SP], #16
		RET

		; announciate version
announce:		
		STP		LR, XZR, [SP, #-16]!
        ADRP	X28, ver@PAGE	     
		ADD		X0, X28, ver@PAGEOFF
        LDR     X1, [X0]
	 	ADRP	X28, ps1@PAGE	   
		ADD		X0, X28, ps1@PAGEOFF

		STP		X1, X0, [SP, #-16]!
		BL		_printf		 
		ADD     SP, SP, #16 
		LDP		LR, XZR, [SP], #16	
		RET

		; exit the program
finish: 
		MOV		X0, #0
		LDR		LR, [SP], #16
		LDP		X19, X20, [SP], #16
		RET


bye_then:
		; found Bye
		BL		saybye
		B		finish

;; leaf
get_word: ; get word from zword into x22
		ADRP	X28, zword@PAGE	   
	    ADD		X22, X28, zword@PAGEOFF
		LDR		X22, [X22]
		RET

;; leaf
empty_word: ; is word empty?

		ADRP	X28, zword@PAGE	   
	    ADD		X22, X28, zword@PAGEOFF
		MOV		W1, #0
 		LDRB	W0, [X22]
		CMP		W0, #0 
		RET


main:	STP		X19, X20, [SP, #-16]!
		STR		LR, [SP, #-16]!

   	    BL  announce
input: 	BL  sayok
		BL  resetword
		BL  resetline
		BL  getline
10:		BL  advancespaces

		BL  collectword

		; check if we have read all available words in the line
		BL 		empty_word
		B.eq	input ; get next line

		; process the word
		;BL  saylb 
		;BL  sayword
		;BL  sayrb
		;BL  saycr
	 
		; look for BYE - which does quit.
		BL		get_word
		ADRP	X28, dbye@PAGE	   
	    ADD		X21, X28, dbye@PAGEOFF
		LDR		X21, [X21]
		CMP		X21, X22
		B.eq	bye_then  ; bye then

		; look for CR - which displays a CR
		BL		get_word
		ADRP	X28, dcr@PAGE	   
	    ADD		X21, X28, dcr@PAGEOFF
		LDR		X21, [X21]
		CMP		X21, X22
		B.ne	23f
		BL		saycr  	; bye then

		; look for PRINT - which prints int from top of stack
23:
		BL		get_word
		ADRP	X28, dpr@PAGE	   
	    ADD		X21, X28, dpr@PAGEOFF
		LDR		X21, [X21]
		CMP		X21, X22
		B.ne	22f
		BL		print  	; bye then

		; look for dot an alias of PRINT
22:
		BL		get_word
		ADRP	X28, ddot@PAGE	   
	    ADD		X21, X28, ddot@PAGEOFF
		LDR		X21, [X21]
		CMP		X21, X22
		B.ne	20f
		BL		print  	; bye then


20:
		; look for number and if found push it to Data Stack
		ADRP	X28, zword@PAGE	   
	    ADD		X22, X28, zword@PAGEOFF
		LDRB	W0, [X22]
		CMP 	W0, #'9'
		B.gt    21f
		CMP     W0, #'0'
		B.lt    21f
		BL		word2number



		; not a number
21:

		B	10b		

        B   bye_then
		 



		;brk #0xF000
		



.data

.align 8

dpage: .zero 4
zstdin: .zero 16

ver:    .double 0.10 

ps1:    .ascii  "Version %2.2f\n"
        .zero   4

.align 8

ps2:    .ascii  "Ok\n"
		.zero 16
.align 	8

ps3:	.ascii "Bye.."
		.zero 16


.align 	8

ps4:	.ascii "Exit no more input.."
		.zero 16

.align 	8

ps5:	.ascii "Word too long.."
		.zero 16

.align 	8

ps6:	.ascii "\r\n"
		.zero 16

.align 	8

ps7:	.ascii "["
		.zero 16

ps8:	.ascii "]"
		.zero 16

ps9:	.ascii "%3d"
		.zero 16

ps10:	.ascii "stack underflow"
		.zero 16


.align 	8
spaces:	.ascii "                              "
		.zero 16

.align  8
sps:	.zero 8*8	
spu:	 
sp1:    .zero 256*8
spo:	 
sp0:    .zero 8*8
dsp:	.quad sp1


.align 8
zpad:    .ascii "ZPAD STARTS HERE"
		 .zero 1024

.align 8
zword: .zero 64

.align 8
zpos:    .quad 0
zpadsz:  .quad 1024
zpadptr: .quad zpad


 .align 8
 dbye:		.ascii "BYE" 
			.zero 5
			.zero 8
 dcr:		.ascii "CR" 
			.zero 6	
			.zero 8	
 dpr:		.ascii "PRINT" 
			.zero 3
			.zero 8	

 ddot:		.ascii "." 
			.zero 7
			.zero 8	
