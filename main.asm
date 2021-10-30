;; reserved registers.
;; X18 reserved
;; X29 frame ptr
;; X30 aka LR
;; X28 data section pointer
;; X0-X7 and D0-D7, are used to pass arguments to assembly functions, 
;; X19-X28 callee saved
;; X8 indirect result 

;; related to the interpreter
;; X16 data stack
;; X15 return stack
;; X14 IP (interpretive pointer)
;; X13 CSP code pointer stack
;; X12
;; X11


;; X28 dictionary
;; X22 word 

.global main 

.align 4			 


 		; get line from terminal
getline:

		ADRP	X8, ___stdinp@GOTPAGE
		LDR		X8, [X8, ___stdinp@GOTPAGEOFF]
		LDR		X2, [X8]
	    ADRP	X0, zpadsz@PAGE	   
		ADD     X1, X0, zpadsz@PAGEOFF
		ADRP	X0, zpadptr@PAGE	
		ADD     X0, X0, zpadptr@PAGEOFF
		STP		LR, X16, [SP, #-16]!	
		BL		_getline
		LDP		LR, X16, [SP], #16	
		RET

   	    ; Ok prompt
sayok: 	
        ADRP	X0, tok@PAGE	
		ADD		X0, X0, tok@PAGEOFF
		B		sayit

saycr: 	
        ADRP	X0, tcr@PAGE	
		ADD		X0, X0, tcr@PAGEOFF
		B		sayit

saylb:
	 	ADRP	X0, tlbr@PAGE	
		ADD		X0, X0, tlbr@PAGEOFF
        B		sayit		

sayrb:
	 	ADRP	X0, trbr@PAGE	
		ADD		X0, X0, trbr@PAGEOFF
        B		sayit		


saybye:
	 	ADRP	X0, tbye@PAGE	
		ADD		X0, X0, tbye@PAGEOFF
        B		sayit

sayerrlength:
	 	ADRP	X0, tlong@PAGE	
		ADD		X0, X0, tlong@PAGEOFF
        B		sayit
				
sayword:
	 	ADRP	X0, zword@PAGE	
		ADD		X0, X0, zword@PAGEOFF
        B		sayit
				
sayoverflow:
	 	ADRP	X0, tovflr@PAGE	
		ADD		X0, X0, tovflr@PAGEOFF
        B		sayit

sayunderflow:
	 	ADRP	X0,	 tunder@PAGE	
		ADD		X0, X0,	tunder@PAGEOFF
        B		sayit



sayeol:
		ADRP	X0, texit@PAGE	
		ADD		X0, X0, texit@PAGEOFF
		BL		sayit
		B		finish

sayit:		
     
		ADRP	X8, ___stdoutp@GOTPAGE
		LDR		X8, [X8, ___stdoutp@GOTPAGEOFF]
		LDR		X1, [X8]
   		STP		LR, X16, [SP, #-16]!
 		STP		X1, X1, [SP, #-16]!
		BL		_fputs	 
		ADD     SP, SP, #16 
		LDP     LR, X16, [SP], #16
		RET


resetword: ; clear word return x22
		ADRP	X22, zword@PAGE	   
	    ADD		X22, X22, zword@PAGEOFF
		STP     XZR, XZR, [X22]
		STP     XZR, XZR, [X22, #8]
		RET

resetline:

		; get zpad address in X23
		ADRP	X0, zpad@PAGE	   
	    ADD		X23, X0, zpad@PAGEOFF
		MOV     X0, X23
		.rept   384
		MOV     W1, #32
		STRB	W1, [X0], #1
		MOV     W1, #0
		STRB	W1, [X0], #1
		.endr
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


addz:			; add tos to 2os leaving result tos
		LDR		W1, [X16, #-4]
		LDR		W2, [X16, #-8]
		ADD		W3, W1, W2
		STR		W3, [X16, #-8]
		SUB		X16, X16, #4
		RET

subz:			; add tos to 2os leaving result tos
		LDR		W1, [X16, #-4]
		LDR		W2, [X16, #-8]
		SUB		W3, W2, W1
		STR		W3, [X16, #-8]
		SUB		X16, X16, #4
		RET


mulz:	; mul tos with 2os leaving result tos
		LDR		W1, [X16, #-4]
		LDR		W2, [X16, #-8]
		MUL		W3, W2, W1
		STR		W3, [X16, #-8]
		SUB		X16, X16, #4
		RET


divz:	; div tos by 2os leaving result tos
		LDR		W1, [X16, #-4]
		LDR		W2, [X16, #-8]
		UDIV	W3, W2, W1
		STR		W3, [X16, #-8]
		SUB		X16, X16, #4
		RET


emitz:	; output tos as char

	
		LDR		W1, [X16, #-4]
		SUB		X16, X16, #4

		; check underflow
		ADRP	X0, spu@PAGE	   
	    ADD		X0, X0, spu@PAGEOFF
		CMP		X16, X0
		b.gt	12f	

		; reset stack
		ADRP	X27, sp1@PAGE	   
	    ADD		X27, X27, sp1@PAGEOFF
		ADRP	X0, dsp@PAGE	   
	    ADD		X0, X0, dsp@PAGEOFF
		STR		X27, [X0]
		MOV		X16, X27 
		; report underflow
	 
		B		sayunderflow
		
12:		MOV		X0, X1 
		STP		LR, X16, [SP, #-16]!
 		STP		X0, X0, [SP, #-16]!
		BL		_putchar	 
		ADD     SP, SP, #16 
		LDP     LR, X16, [SP], #16
		RET


print: ; prints int on top of stack		
	
		LDR		W1, [X16, #-4]
		SUB		X16, X16, #4

		; check underflow
		ADRP	X0, spu@PAGE	   
	    ADD		X0, X0, spu@PAGEOFF
		CMP		X16, X0
		b.gt	12f	

		; reset stack
		ADRP	X27, sp1@PAGE	   
	    ADD		X27, X27, sp1@PAGEOFF
		ADRP	X0, dsp@PAGE	   
	    ADD		X0, X0, dsp@PAGEOFF
		STR		X27, [X0]
		MOV		X16, X27 
		; report underflow
	 
		B		sayunderflow
		
12:

	 	ADRP	X0, tdec@PAGE	   
		ADD		X0, X0,tdec@PAGEOFF
		STP		LR, X16, [SP, #-16]!
		STP		X1, X0, [SP, #-16]!
		BL		_printf		 
		ADD     SP, SP, #16 
		LDP		LR, X16, [SP], #16	
		RET


word2number:	; converts ascii at word to 32bit number
				; IN X16

		ADRP	X0, zword@PAGE	   
	    ADD		X0, X0, zword@PAGEOFF
		STP		LR, X16, [SP, #-16]!
		BL		_atoi
		LDP     LR, X16, [SP], #16

		STR		W0, [X16], #4

		; check for overflow
		ADRP	X0, spo@PAGE	   
	    ADD		X0, X0, spo@PAGEOFF
		CMP		X16, X0
		b.lt	95f

		; reset stack
		ADRP	X27, sp1@PAGE	   
	    ADD		X27, X27, sp1@PAGEOFF
		ADRP	X0, dsp@PAGE	   
	    ADD		X0, X0, dsp@PAGEOFF
		STR		X27, [X0]
		MOV		X16, X27 
		; report overfow
	
		B		sayoverflow


95:		
		RET

collectword:  ; byte ptr in x23, x22 
			  ; copy and advance byte ptr until space.

		STP		LR, X16, [SP, #-16]!
		; reset word to zeros;
		BL		resetword

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

		ADRP	X0, zword@PAGE	   
	    ADD		X22, X0, zword@PAGEOFF
		STP     XZR, XZR, [X22]
		STP     XZR, XZR, [X22, #8]
		ADRP	X0, zword@PAGE	   
	    ADD		X22, X0, zword@PAGEOFF
		
		BL		sayerrlength
		B		95f
		
20:		B     	10b
		 
90:		MOV     W0, #0x00
		STRB	W0, [X22], #1
		STRB	W0, [X22], #1
95:		LDP     LR, X16, [SP], #16
		RET

		; announciate version
announce:		
	
        ADRP	X0, ver@PAGE	     
		ADD		X0, X0, ver@PAGEOFF
        LDR     X1, [X0]
	 	ADRP	X0, tver@PAGE	   
		ADD		X0, X0, tver@PAGEOFF
		STP		LR, X16, [SP, #-16]!
		STP		X1, X0, [SP, #-16]!
		BL		_printf		 
		ADD     SP, SP, #16  
		LDP		LR, X16, [SP], #16	
		RET

		; exit the program
finish: 
		MOV		X0, #0
		LDR		LR, [SP], #16
		LDP		X19, X20, [SP], #16
		RET

 

;; leaf
get_word: ; get word from zword into x22
		ADRP	X22, zword@PAGE	   
	    ADD		X22, X22, zword@PAGEOFF
		LDR		X22, [X22]
		RET

;; leaf
empty_wordQ: ; is word empty?
		ADRP	X22, zword@PAGE	   
	    ADD		X22, X22, zword@PAGEOFF
 		LDRB	W0, [X22]
		CMP		W0, #0 
		RET


;; start running here

main:	 
		 

init:	

		ADRP	X0, dsp@PAGE	   
	    ADD		X0, X0, dsp@PAGEOFF
		LDR		X16, [X0]  ;; <-- data stack pointer to X16


   	    BL  announce

input: 	BL  sayok
		BL  resetword
		BL  resetline
		BL  getline

10:		BL  advancespaces

		BL  collectword

		; check if we have read all available words in the line
		BL 		empty_wordQ
		B.eq	input ; get next line
	 
		; look for BYE - which does quit.
		BL		get_word
		ADRP	X0, dbye@PAGE	   
	    ADD		X21, X0, dbye@PAGEOFF
		LDR		X21, [X21]
		CMP		X21, X22
		B.ne	outer  
		
		; Bye - we are leaving the program

		ADRP	X0, tbye@PAGE	
		ADD		X0, X0, tbye@PAGEOFF  
		ADRP	X8, ___stdoutp@GOTPAGE
		LDR		X8, [X8, ___stdoutp@GOTPAGEOFF]
		LDR		X1, [X8]

 		STP		X1, X0, [SP, #-16]!
		BL		_fputs	 
		ADD     SP, SP, #16 
		MOV		X0, #0
		BL		_exit


		; outer interpreter
		; look for WORDs - when found, execute the words function	
		; we are in immediate mode, we see a word and we execute its code.

outer:	
		; from here X28 is current word.
		ADRP	X28, sdict@PAGE	   
	    ADD		X28, X28, sdict@PAGEOFF
	 
find_word:	

		BL		get_word	
		LDR		X21, [X28]
		CMP     X21, #0        ; end of list?
		B.eq    finish_list	
		CMP     X21, #-1       ; undefined entry in list?
		b.eq    next_word

		CMP		X21, X22       ; is this our word?
		B.ne	next_word

		; found word, exec function
		LDR     X0,	[X28, #16]
		CMP		X0, #0 
		B.eq	finish_list

		STP		X28, XZR, [SP, #-16]!
		BLR		X0	 ;; call function
		LDP		X28, XZR, [SP]

next_word:		
		SUB		X28, X28, #24
		B       find_word

finish_list: ; we did not find a defined word.

	 

check_integer_variables:

		; look for a single letter variable name
		; followed by @ (fetch) or ! (store)
 
		ADRP	X22, zword@PAGE	   
	    ADD		X22, X22, zword@PAGEOFF
		LDRB	W0, [X22, #1]
		CMP		W0, #'@'
		B.eq	ivfetch
		CMP		W0, #'!'
		B.eq	ivset
		B		20f

ivfetch: ; from variable push to stack
		LDRB 	W0,	[X22]
		LSL		X0, X0, #3
		ADRP	X27,ivars@PAGE 
		ADD		X27, X27, ivars@PAGEOFF
		LDR		W0, [X27, X0]
		STR		W0, [X16], #4	
		; todo check overflow.
		B       10b

ivset:	; from stack set variable
		LDRB 	W0,	[X22]
		LSL     X0, X0, #3
		LDR		W1, [X16, #-4]
		SUB		X16, X16, #4
		; todo check under-flow.

		; check underflow
		ADRP	X2, spu@PAGE	   
	    ADD		X2, X2, spu@PAGEOFF
		CMP		X16, X2
		b.gt	ivset2	

		; reset stack
		ADRP	X26, sp1@PAGE	   
	    ADD		X26, X26, sp1@PAGEOFF
		ADRP	X2, dsp@PAGE	   
	    ADD		X2, X2, dsp@PAGEOFF
		STR		X26, [X2]
		MOV		X16, X26 
		; report underflow
		BL		sayunderflow
		B		10b

ivset2:		
		ADRP	X27,ivars@PAGE 
		ADD		X27, X27, ivars@PAGEOFF
		ADD     X27, X27, X0
		STR		W1, [X27]
		B		10b


20:
		; look for an integer number made of decimal digits.
		; If found immediately push it onto our Data Stack

		ADRP	X22, zword@PAGE	   
	    ADD		X22, X22, zword@PAGEOFF
		
		LDRB	W0, [X22]
		CMP 	W0, #'9'
		B.gt    compiler
		CMP     W0, #'0'
		B.lt    compiler

23:		ADD		X22, X22, #1
		LDRB	W0, [X22]
		CMP		W0, #0
		B.eq	24f
		CMP 	W0, #'.'
		B.eq	decimal_number
		CMP 	W0, #'9'
		B.gt    compiler
		CMP     W0, #'0'
		B.lt    compiler
		
		B		23b
24:
		BL		word2number
		B       compiler
		; the word may be a decimal number

decimal_number:
		; TODO: decimals


compiler:

		ADRP	X22, zword@PAGE	   
	    ADD		X22, X22, zword@PAGEOFF
		
		LDRB	W0, [X22]
		CMP 	W0, #':' 	; do we enter the compiler
		B.ne	exit_compiler

		; from here we compile words.

enter_compiler:

		; look for the name of the new word we are compiling.
		BL  	advancespaces
		BL  	collectword
		 
		BL 		empty_wordQ
		B.ne	create_word 

		; : was followed by nothing which is an error.
		ADRP	X0,	 tcomer1@PAGE	
		ADD		X0, X0,	tcomer1@PAGEOFF
        BL		sayit
		B		input ; back to immediate mode.

		; to create a new word :-
		; 1. find first free word in the list. 
		; 2. set the words name.
		; 4. find the next code space address.
		; 5. set the function to the code space addres
		; 6. set the first code space element to DOCOL 
		; 7. set the next code space elemement to SEMI
		; - [DOCOL, SEMI] is essentially a NOOP. 
		
create_word: 




exit_compiler:

		; BL sayok



		B	10b	

		MOV		X0,#0
        BL		_exit
		

		;brk #0xF000


.data

.align 8

dpage: .zero 4
zstdin: .zero 16

ver:    .double 0.31 

;; text literals

tver:    .ascii  "Version %2.2f\n"
        .zero   4

.align 8

tok:    .ascii  "\nOk\n"
		.zero 16

.align 	8
tbye:	.ascii "\nBye..\n"
		.zero 16


.align 	8
texit:	.ascii "Exit no more input.."
		.zero 16

.align 	8
tlong:	.ascii "Word too long.."
		.zero 16

.align 	8
tcr:	.ascii "\r\n"
		.zero 16

.align 	8
tlbr:	.ascii "["
		.zero 16

.align 	8
trbr:	.ascii "]"
		.zero 16

.align 	8
tdec:	.ascii "%3d"
		.zero 16

.align 	8
tovflr:	.ascii "stack over-flow"
		.zero 16

.align 	8
tunder:	.ascii "stack under-flow"
		.zero 16

.align 	8
tcomer1: .ascii "Compiler error ':' expects a word to define."
		.zero 16

.align 	8
tcomer3: .ascii "Compiler error  "
		.zero 16

.align 	8
tcomer4: .ascii "Compiler error  "
		.zero 16

.align 	8
tcomer5: .ascii "Compiler error  "
		.zero 16


.align 	8
spaces:	.ascii "                              "
		.zero 16


; this is the code pointer stack
; every address pushed here is a leaf subroutine address.
; 
.align 8
cps:	.zero 8*16	
cpu:	.zero 16
cp1:    .zero 4096*16  
cpo:	.zero 16
cp0:    .zero 16
csp:	.quad cp1


; this is the data stack
.align  8
sps:	.zero 8*8	
spu:	.zero 4
sp1:    .zero 256*4  
spo:	.zero 4
sp0:    .zero 8*8
dsp:	.quad sp1

; this is the return stack
.align  8
rps:	.zero 8*8	
rpu:	.zero 4
rp1:    .zero 256*4  
rpo:	.zero 4
rp0:    .zero 8*8
rsp:	.quad rp1

; global, single letter, integer variables
.align 16
ivars:	.zero 256*16	


; used for line input
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
addressbuffer:
		.zero 128*8



 .align 8
 dbye:		.ascii "BYE" 
			.zero 5
			.zero 8
			.quad 0

 wlist:	    ; each word is 16 bytes of zero terminated ascii	
			; with a pointer to the adress of the machine code function to call.
			; 24 bytes

			; the end of the list
 dend:		.quad 0
			.quad 0
			.quad 0

			; primitive code word headings.

 dcr:		.ascii "CR" 
			.zero 6	
			.zero 8	
			.quad saycr

 dpr:		.ascii "PRINT" 
			.zero 3
			.zero 8	
			.quad print

 ddot:		.ascii "." 
			.zero 7
			.zero 8	
			.quad print

 dok:		.ascii "OK" 
			.zero 6
			.zero 8	
			.quad sayok			

 daddz:		.ascii "+" 
			.zero 7
			.zero 8	
			.quad addz

 dsubz:		.ascii "-" 
			.zero 7
			.zero 8	
			.quad subz

 dmulz:		.ascii "*" 
			.zero 7
			.zero 8	
			.quad mulz

 ddivz:		.ascii "/" 
			.zero 7
			.zero 8	
			.quad divz

 			.ascii ".VERSION" 
			.zero 8	
			.quad announce

			.ascii "EMIT" 
			.zero 4
			.zero 8	
			.quad emitz

 ; user defined word headings x 128
 duserdef:
			.rept 128 ; <-- 128 words
			.quad -1 
			.quad 0
			.quad -1 
			.endr
 sdict:		.quad -1 
			.quad  0
			.quad -1			

