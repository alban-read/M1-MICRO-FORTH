;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; risc-ish experiment by Alban
;; ARM64 code November - December 2021
;; This is a small FORTH like interpreter for Apple Silicon
;; implemented in assembly language

;; reserved registers.
;; X18 reserved for OS
;; X29 frame ptr for OS/C
;; X30 aka LR (the return register)
;; X28 data section pointer
;; X0-X7 and D0-D7, are used to pass arguments to assembly functions, 
;; X19-X28 callee saved
;; X8 indirect result 

;; related to the interpreter
; X16 is the data stack
; X26 is the locals stack
; X15 is the interpreter pointer/dictionary pointer
; X14 is the return stack
; X13  
; X12 is the tertiary pointer
; X6  is the tracing ON/OFF register

;; X27 dend (start of dictionary)
;; X28 dictionary - current word header in the dictionary searcj=h
;; X29 the value 64. (perhaps wasteful)

;; X22 word (text)
;; X23 also used for text




 .macro reset_data_stack
	ADRP	X1, sp1@PAGE		
	ADD		X1, X1, sp1@PAGEOFF
	ADRP	X0, dsp@PAGE		
	ADD		X0, X0, dsp@PAGEOFF
	STR		X1, [X0]
	MOV		X16, X1 
.endm


 .macro reset_return_stack
	ADRP	X1, rp1@PAGE		
	ADD		X1, X1, rp1@PAGEOFF
	ADRP	X0, rsp@PAGE		
	ADD		X0, X0, rsp@PAGEOFF
	STR		X1, [X0]
	MOV		X14, X1 
.endm


.macro save_registers  
	STP		X12, X13, [SP, #-16]!
	STP		X14, X15, [SP, #-16]!
	STP		LR,  X16, [SP, #-16]!
	STP		X6,  X7,  [SP, #-16]!
	STP		X4,  X5,  [SP, #-16]!
.endm

.macro restore_registers  
	LDP		X4, X5, [SP], #16
	LDP		X6, X7, [SP], #16
	LDP		LR, X16, [SP], #16
	LDP		X14, X15, [SP], #16	
	LDP		X12, X13, [SP], #16	
.endm

.macro save_registers_not_stack  
	STP		X12, X13, [SP, #-16]!
	STP		X14, X15, [SP, #-16]!
	STP		LR,  XZR, [SP, #-16]!
.endm

.macro restore_registers_not_stack  
	LDP		LR, XZR, [SP], #16
	LDP		X14, X15, [SP], #16	
	LDP		X12, X13, [SP], #16	
.endm


; dictionary headers
; These are seperate from the token space, or literal pools
; contain the name of a word, the runtime and compile time functions
; and a small ammount of data for the functions use.


; data 		(argument for runtime)
; runtime	function address when running
; data		(argument for compile time)
; comptime	function address when compiling
; data		spare data
; data
; name 		the words name
 

.macro makeword name:req, runtime=-1, comptime=-1, datavalue=1
	.quad	\datavalue
	.quad	\runtime
	.quad	0				; data
	.quad	\comptime
	.quad	0
	.quad	0
10:
	.asciz	"\name"
20:
	.zero	16 - ( 20b-10b )
.endm

.macro makevarword name:req, v1=1, v2=0, v3=0, v4=0
	.quad	\v1
	.quad	dvaraddz
	.quad	\v2
	.quad	dvaraddc
	.quad	\v3
	.quad	\v4
10:
	.asciz	"\name"
20:
	.zero	16 - ( 20b-10b )
.endm


.macro makebword name:req, runtime=-1, comptime=-1, datavalue=1
	.quad	\datavalue
	.quad	\runtime
	.quad	0
	.quad	\comptime
	.quad	0
	.quad	0
	.byte	\name
	.zero	15
.endm

 .macro makeqvword name:req
	.quad	8 * \name + ivars	
	.quad	dvaraddz
	.quad	0
	.quad	dvaraddc
	.quad	0
	.quad	0
	.byte	\name
	.zero	15
.endm

;  
.macro makeemptywords n=32 
	.rept  \n
	.quad  -1
	.quad  -1
	.quad  0
	.quad  0
	.quad  0
	.quad  0
	.quad  -1
	.quad  -1
	.endr
.endm

; trace words, check for X6<>0 
; and print a trace of the inner interpreter

.macro  trace_show_word

	CBZ		X6, 	999f

	STP		LR,  X0, [SP, #-16]!
	STP		X1,  X12, [SP, #-16]!
	
	ADD		X12,  X1, #48
	MOV		X0,  X1
	BL		X0addrprln

	LDRH	W0, [X15]
	BL		X0halfpr

	MOV		X0, X12
	LDRH    W1, [X15,#-2] 
	CBZ     W1, 20f
	CMP		W1,	16
	B.gt	20f
 	ADRP	X0, literal_name@PAGE	
	ADD		X0, X0, literal_name@PAGEOFF	
	
20:
	BL		X0prname
	BL		ddotsz


	LDP		X1, X12, [SP], #16	
	LDP		LR, X0, [SP], #16	
999:
.endm
 

.macro  do_trace	
	CBZ		X6, 	999f
	STP		LR,  X0, [SP, #-16]!
	
	MOV		X0, X15
	BL		X0addrprln
		
	LDRH	W0, [X15]
	BL		X0halfpr
	LDRH	W0, [X15]
	LSL		W0, W0, #6		;  TOKEN*64 
	ADD		X0, X0, X27		; + dend
	ADD		X0, X0, #48

	ADRP	X2, startdict@PAGE	
	ADD		X2, X2, startdict@PAGEOFF	
	CMP		X0, X2
	B.gt	999f

	LDR		X2, [X0] 

	LDRH    W1, [X15,#-2] 
	CBZ		W1, 20f
	CMP		W1,	16
	B.gt	20f
 	ADRP	X0, literal_name@PAGE	
	ADD		X0, X0, literal_name@PAGEOFF	
	
20:
	BL		X0prname

 	MOV		X0, X15
	BL		X0prip

	BL		ddotsz
	BL		ddotrz
	
	LDP		LR, X0, [SP], #16	
999:

.endm


.data

.align 8

ver:	.double 0.534
tver:	.ascii  "Version %2.2f\n"
	.zero	4

.text

.global main 

.align 8			


	; get line from terminal
getline:

	ADRP	X8, ___stdinp@GOTPAGE
	LDR		X8, [X8, ___stdinp@GOTPAGEOFF]
	LDR		X2, [X8]
	ADRP	X0, zpadsz@PAGE		
	ADD	X1, X0, zpadsz@PAGEOFF
	ADRP	X0, zpadptr@PAGE	
	ADD	X0, X0, zpadptr@PAGEOFF
	save_registers
	BL		_getline
	restore_registers
	RET

cls:
dpagez:
	ADRP	X0, clear_screen@PAGE	
	ADD		X0, X0, clear_screen@PAGEOFF
	B		sayit



		; Ok prompt
sayok:	
	ADRP	X0, tok@PAGE	
	ADD		X0, X0, tok@PAGEOFF
	B		sayit

saycr:	
	ADRP	X0, tcr@PAGE	
	ADD		X0, X0, tcr@PAGEOFF
	B		sayit

sayforgetting:	
	ADRP	X0, tforget@PAGE	
	ADD		X0, X0, tforget@PAGEOFF
	B		sayit


saycompfin:	
	ADRP	X0, tcomer6@PAGE	
	ADD		X0, X0, tcomer6@PAGEOFF
	B		sayit

saywordexists:	
	ADRP	X0, texists@PAGE	
	ADD		X0, X0, texists@PAGEOFF
	B		sayit

saycreatedword:	
	ADRP	X0, tcomer7@PAGE	
	ADD		X0, X0, tcomer7@PAGEOFF
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


saynotfound:
	ADRP	X0, tcomer4@PAGE	
	ADD		X0, X0, tcomer4@PAGEOFF
	B		sayit


sayerrlength:
	ADRP	X0, tlong@PAGE	
	ADD		X0, X0, tlong@PAGEOFF
	B		sayit

sayerrwordlong:
	ADRP	X0, tcomer8@PAGE	
	ADD		X0, X0, tcomer8@PAGEOFF
	B		sayit

sayerrpoolfullquad:
	ADRP	X0, poolfullerr@PAGE	
	ADD		X0, X0, poolfullerr@PAGEOFF
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
	ADRP	X0, 	tunder@PAGE	
	ADD		X0, X0, 	tunder@PAGEOFF
	B		sayit

sayeol:
	ADRP	X0, texit@PAGE	
	ADD		X0, X0, texit@PAGEOFF
	BL		sayit
	B		finish


sayliteral:
	ADRP	X0, tliteral@PAGE	
	ADD		X0, X0, tliteral@PAGEOFF
	BL		sayit
	B		finish


; WORDS - displays words in the dictionary.

 


alldotwords:

	ADRP	X8, ___stdoutp@GOTPAGE
	LDR		X8, [X8, ___stdoutp@GOTPAGEOFF]
	LDR		X1, [X8]

	MOV		X2, X27 ; dend
	B 		20f


dotwords:
	
	ADRP	X8, ___stdoutp@GOTPAGE
	LDR		X8, [X8, ___stdoutp@GOTPAGEOFF]
	LDR		X1, [X8]

	ADRP	X2, hashdict@PAGE	
	ADD		X2, X2, hashdict@PAGEOFF

20:	ADD		X2, X2, #64
	LDR		X0, [X2, #48]
	CMP		X0, #-1
	B.eq	10f

	CMP		X0, #0
	B.eq	15f

	ADD		X0, X2,  #48
	STP		X2, X1, [SP, #-16]!
	save_registers
	BL		_fputs	
 
	MOV		X0, #32
	BL		_putchar
	restore_registers
	LDP		X2, X1, [SP], #16


10:	; skip non word
	B		20b  

 
15:
	RET

sayit:	
	
	ADRP	X8, ___stdoutp@GOTPAGE
	LDR		X8, [X8, ___stdoutp@GOTPAGEOFF]
	LDR		X1, [X8]
	save_registers
 
	BL		_fputs	
	
	restore_registers
	RET


resetword: ; clear word return x22
	ADRP	X22, zword@PAGE		
	ADD		X22, X22, zword@PAGEOFF
	STP		XZR, XZR, [X22]
	STP		XZR, XZR, [X22, #48]
	RET

resetline:

	; get zpad address in X23
	ADRP	X0, zpad@PAGE		
	ADD		X23, X0, zpad@PAGEOFF
	MOV		X0, X23
	.rept	384
	MOV		W1, #32
	STRB	W1, [X0], #1
	MOV		W1, #0
	STRB	W1, [X0], #1
	.endr
	RET

advancespaces: ; byte ptr in x23, advance past spaces until zero
10:	LDRB	W0, [X23]
	CMP		W0, #0
	B.eq	90f	
	CMP		W0, #32
	b.ne	90f
	ADD		X23, X23, #1
	B		10b
90:	RET

absz:		
	RET


addz:		; add tos to 2os leaving result tos
	LDR		X1, [X16, #-8]
	LDR		X2, [X16, #-16]
	ADD		X3, X1, X2
	STR		X3, [X16, #-16]
	SUB		X16, X16, #8
	RET

subz:		; add tos to 2os leaving result tos
	LDR		X1, [X16, #-8]
	LDR		X2, [X16, #-16]
	SUB		X3, X2, X1
	STR		X3, [X16, #-16]
	SUB		X16, X16, #8
	RET


mulz:	; mul tos with 2os leaving result tos
	LDR		X1, [X16, #-8]
	LDR		X2, [X16, #-16]
	MUL		X3, X2, X1
	STR		X3, [X16, #-16]
	SUB		X16, X16, #8
	RET


dstarslshz: ; famous */ but only 64 bit not using 128 intermediate

	LDR		X1, [X16, #-8]
	LDR		X2, [X16, #-16]
	LDR		X3, [X16, #-24]
	SUB		X16, X16, #24
	MUL		X0, X3, X2
	SDIV	X0, X0, X1
	STR		X0, [X16], #8
	RET

 dstarslshzmod: ; */MOD
	LDP 	X1, X2,  [X16, #-16]  
	LDR		X3, [X16, #-24]
	SUB		X16, X16, #24
	MUL		X0, X3, X2
	SDIV	X0, X0, X1
	MSUB	X3, X2, X3, X0 
	STR		X0, [X16], #8
	STR		X3, [X16], #8
	RET
		

andz:	; and tos with 2os leaving result tos
	LDR		X1, [X16, #-8]
	LDR		X2, [X16, #-16]
	AND		X3, X2, X1
	STR		X3, [X16, #-16]
	SUB		X16, X16, #8
	RET


negz:	;  negate 
	LDR		X1, [X16, #-8]
	NEG		X1, X1
	STR		X1, [X16, #-8]
	RET		


orz:	; or tos with 2os leaving result tos
	LDR		X1, [X16, #-8]
	LDR		X2, [X16, #-16]
	ORR		X3, X2, X1
	STR		X3, [X16, #-16]
	SUB		X16, X16, #8
	RET


sdivz:	; div tos by 2os leaving result tos
	LDR		X1, [X16, #-8]
	LDR		X2, [X16, #-16]
	SDIV	X3, X2, X1
	STR		X3, [X16, #-16]
	SUB		X16, X16, #8
	RET
 
udivz:	; div tos by 2os leaving result tos - ??? not clear this is correct.
	LDR		X1, [X16, #-8]
	LDR		X2, [X16, #-16]
	SDIV	X3, X2, X1
	STR		X3, [X16, #-16]
	SUB		X16, X16, #8
	RET


emitz:	; output tos as char
	LDR		X1, [X16, #-8]
	SUB		X16, X16, #8

	
12:	MOV		X0, X1 

X0emit:	
	save_registers
	BL		_putchar	
	restore_registers
	RET


emitchz:	; output X0 as char
	save_registers
	BL		_putchar	
	restore_registers
	RET

emitchc:	; output X0 as char
	RET


reprintz:
	
	LDP		X1, X0, [X16, #-16]
	SUB		X16, X16, #16
20:	
	CMP	X1, #0
	B.eq	10f
	STP	X0, X1,  [SP, #-16]!
	save_registers
	STP		X0, X0, [SP, #-16]!
	BL		_putchar	
	ADD	SP, SP, #16 
	restore_registers
	LDP	X0, X1, [SP], #16
	SUB		X1, X1, #1
	B		20b

10:
	RET


reprintc:
	RET
	


spacesz:
	; number of spaces
	
	LDR		X1, [X16, #-8]
	SUB		X16, X16, #8
20:	
	CMP	X1, #0
	B.eq	10f
	MOV	X0, #32
	STP	X0, X1, [SP, #-16]!
	save_registers
	STP		X0, X0, [SP, #-16]!
	BL		_putchar	
	ADD	SP, SP, #16 
	restore_registers
	LDP	X0, X1, [SP], #16
	SUB		X1, X1, #1
	B		20b

10:
	RET


spacesc:	
	RET




X0prname:

	MOV		X1, X0
	CBZ		X1, 16f
	CMP		X1, #-1
	B.eq	16f
	B		12f	
		
12:

	ADRP	X0, tprname@PAGE		
	ADD		X0, X0, tprname@PAGEOFF
	save_registers
	STP		X1, X0, [SP, #-16]!
	BL		_printf		
	ADD	SP, SP, #16 
	restore_registers  
16:
	RET



X0halfpr:
	MOV	X1, X0
	B		12f	
		
12:

	ADRP	X0, thalfpr@PAGE		
	ADD		X0, X0, thalfpr@PAGEOFF
	save_registers
	STP		X1, X0, [SP, #-16]!
	BL		_printf		
	ADD	SP, SP, #16 
	restore_registers  
	RET


X0branchpr:

	MOV	X1, X0
	B		12f	
		
12:

	ADRP	X0, tbranchpr@PAGE		
	ADD		X0, X0, tbranchpr@PAGEOFF
	save_registers
	STP		X1, X0, [SP, #-16]!
	BL		_printf		
	ADD	SP, SP, #16 
	restore_registers  
	RET


X0addrpr:
	MOV	X1, X0
	B		12f

addrpr: ; prints int on top of stack in hex	
	
	LDR		X1, [X16, #-8]
	SUB		X16, X16, #8	
		
12:

	ADRP	X0, tpradd@PAGE		
	ADD		X0, X0, tpradd@PAGEOFF
	save_registers
	STP		X1, X0, [SP, #-16]!
	BL		_printf		
	ADD	SP, SP, #16 
	restore_registers  
	RET


X0prip: ; print IP
	MOV		X1, X0
	ADRP	X0, tpradIP@PAGE		
	ADD		X0, X0, tpradIP@PAGEOFF
	save_registers
	STP		X1, X0, [SP, #-16]!
	BL		_printf		
	ADD	SP, SP, #16 
	restore_registers  
	RET


X0addrprln: ; print address
	MOV	X1, X0
	B		12f

lnaddrpr: ; prints int on top of stack 
	
	LDR		X1, [X16, #-8]
	SUB		X16, X16, #8	
		
12:

	ADRP	X0, tpraddln@PAGE		
	ADD		X0, X0, tpraddln@PAGEOFF
	save_registers
	STP		X1, X0, [SP, #-16]!
	BL		_printf		
	ADD	SP, SP, #16 
	restore_registers  
	RET


X0hexprint:
	MOV	X1, X0
	B		12f

hexprint: ; prints int on top of stack in hex	
	
	LDR		X1, [X16, #-8]
	SUB		X16, X16, #8	
		
12:

	ADRP	X0, thex@PAGE		
	ADD		X0, X0, thex@PAGEOFF
	save_registers
	STP		X1, X0, [SP, #-16]!
	BL		_printf		
	ADD		SP, SP, #16 
	restore_registers  
	RET



X0print:
	MOV		X1, X0
	B		12f

print: ; prints int on top of stack		
	
	LDR		X1, [X16, #-8]
	SUB		X16, X16, #8	
		
12:

	ADRP	X0, tdec@PAGE		
	ADD		X0, X0, tdec@PAGEOFF
	save_registers
	STP		X1, X0, [SP, #-16]!
	BL		_printf		
	ADD		SP, SP, #16 
	restore_registers  
	RET


word2number:	; converts ascii at word to 32bit number
			; IN X16

	ADRP	X0, zword@PAGE		
	ADD		X0, X0, zword@PAGEOFF

	save_registers
	BL		_atoi
	restore_registers  
	
	STR		X0, [X16], #8

	; check for overflow
	B			chkoverflow
	RET



dsleepz: ; sleep	
	
	LDR		X0, [X16, #-8]
	SUB		X16, X16, #8	
		
12:
	save_registers
	STP		X1, X0, [SP, #-16]!
	BL		_sleep 
	ADD		SP, SP, #16 
	restore_registers  
	RET



chkunderflow: ; check for stack underflow
	ADRP	X0, spu@PAGE		
	ADD		X0, X0, spu@PAGEOFF
	CMP		X16, X0
	b.gt	12f	

	; reset stack
	reset_data_stack
	
	B		sayunderflow

12:
	RET

chkoverflow:; check for stack overflow

	ADRP	X0, spo@PAGE		
	ADD		X0, X0, spo@PAGEOFF
	CMP		X16, X0
	b.lt	95f

	; reset stack
	reset_data_stack
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

10:	LDRB	W0, [X23], #1
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
	STP		XZR, XZR, [X22]
	STP		XZR, XZR, [X22, #8]
	ADRP	X0, zword@PAGE		
	ADD		X22, X0, zword@PAGEOFF
	
	BL		sayerrlength
	B		95f
	
20:	B		10b
		
90:	MOV		W0, #0x00
	STRB	W0, [X22], #1
	STRB	W0, [X22], #1
95:	LDP		LR, X16, [SP], #16
	RET



	; announciate version
announce:	
	
	ADRP	X0, ver@PAGE		
	ADD		X0, X0, ver@PAGEOFF
	LDR		X1, [X0]
	ADRP	X0, tver@PAGE		
	ADD		X0, X0, tver@PAGEOFF
	save_registers
	STP		X1, X0, [SP, #-16]!
	BL		_printf		
	ADD		SP, SP, #16  
	restore_registers
	RET


	; exit the program
finish: 
	MOV		X0, #0
	LDR		LR, [SP], #16
	LDP		X19, X20, [SP], #16
	RET

 
get_word: ; get word from zword into x22
	ADRP	X22, zword@PAGE		
	ADD		X22, X22, zword@PAGEOFF
	LDR		X22, [X22]
	RET
	
empty_wordQ: ; is word empty?
	ADRP	X22, zword@PAGE		
	ADD		X22, X22, zword@PAGEOFF
	LDRB	W0, [X22]
	CMP		W0, #0 
	RET


start_point: ; finds where to start searching the dictionary
 
	
	ADRP	X22, zword@PAGE		
	ADD		X22, X22, zword@PAGEOFF
	
	LDRB	W0, 	[X22]	; first letter
	
	CMP		W0, #'#'	
	B.eq	150f

	CMP		W0, #'('	
	B.ne	200f
150:
	ADRP	X28, hashdict@PAGE		
	ADD		X28, X28, hashdict@PAGEOFF	
	B		251f

200:
	; lower case and check for a..z
	ORR		W0, W0, 0x20

	CMP		W0, #'z'	
	B.gt	searchall
	
	CMP		W0, #'a'
	B.lt	searchall

	; We have a..z, A..Z, so narrow the search.

	CMP		W0, #'a'
	B.ne	201f
	ADRP	X28, adict@PAGE		
	ADD		X28, X28, adict@PAGEOFF	
	B		251f

201:	
	CMP		W0, #'b'
	B.ne	221f
	ADRP	X28, bdict@PAGE		
	ADD		X28, X28, bdict@PAGEOFF	
	B		251f


221:	
	CMP		W0, #'c'
	B.ne	202f
	ADRP	X28, cdict@PAGE		
	ADD		X28, X28, cdict@PAGEOFF	
	B		251f		

202:
	CMP		W0, #'d'
	B.ne	203f
	ADRP	X28, ddict@PAGE		
	ADD		X28, X28, ddict@PAGEOFF	
	B		251f
 
203:
	CMP		W0, #'e'
	B.ne	204f
	ADRP	X28, edict@PAGE		
	ADD		X28, X28, edict@PAGEOFF	
	B		251f
 
204:
	CMP		W0, #'f'
	B.ne	205f
	ADRP	X28, fdict@PAGE		
	ADD		X28, X28, fdict@PAGEOFF	
	B		251f

205:
	CMP		W0, #'g'
	B.ne	206f
	ADRP	X28, gdict@PAGE		
	ADD		X28, X28, gdict@PAGEOFF	
	B		251f


206:
	CMP		W0, #'h'
	B.ne	207f
	ADRP	X28, hdict@PAGE		
	ADD		X28, X28, hdict@PAGEOFF	
	B		251f

207:
	CMP		W0, #'i'
	B.ne	208f
	ADRP	X28, idict@PAGE		
	ADD		X28, X28, idict@PAGEOFF	
	B		251f

208:
	CMP		W0, #'j'
	B.ne	209f
	ADRP	X28, jdict@PAGE		
	ADD		X28, X28, jdict@PAGEOFF	
	B		251f

209:
	CMP		W0, #'k'
	B.ne	210f
	ADRP	X28, kdict@PAGE		
	ADD		X28, X28, kdict@PAGEOFF	
	B		251f

210:
	CMP		W0, #'l'
	B.ne	211f
	ADRP	X28, ldict@PAGE		
	ADD		X28, X28, ldict@PAGEOFF	
	B		251f

211:
	CMP		W0, #'m'
	B.ne	212f
	ADRP	X28, mdict@PAGE		
	ADD		X28, X28, mdict@PAGEOFF	
	B		251f

212:
	CMP		W0, #'n'
	B.ne	213f
	ADRP	X28, ndict@PAGE		
	ADD		X28, X28, ndict@PAGEOFF	
	B		251f

213:
	CMP		W0, #'o'
	B.ne	214f
	ADRP	X28, odict@PAGE		
	ADD		X28, X28, odict@PAGEOFF	
	B		251f

214:
	CMP		W0, #'p'
	B.ne	215f
	ADRP	X28, pdict@PAGE		
	ADD		X28, X28, pdict@PAGEOFF	
	B		217f

215:
	CMP		W0, #'q'
	B.ne	216f
	ADRP	X28, qdict@PAGE		
	ADD		X28, X28, qdict@PAGEOFF	
	B		251f

216:
	CMP		W0, #'r'
	B.ne	217f
	ADRP	X28, rdict@PAGE		
	ADD		X28, X28, rdict@PAGEOFF	
	B		251f

217:
	CMP		W0, #'s'
	B.ne	218f
	ADRP	X28, sdict@PAGE		
	ADD		X28, X28, sdict@PAGEOFF	
	B		251f

218:
	CMP		W0, #'t'
	B.ne	219f
	ADRP	X28, tdict@PAGE		
	ADD		X28, X28, tdict@PAGEOFF	
	B		251f

219:
	CMP		W0, #'u'
	B.ne	220f
	ADRP	X28, udict@PAGE		
	ADD		X28, X28, udict@PAGEOFF	
	B		251f

220:
	CMP		W0, #'v'
	B.ne	221f
	ADRP	X28, vdict@PAGE		
	ADD		X28, X28, vdict@PAGEOFF	
	B		251f

221:
	CMP		W0, #'w'
	B.ne	222f
	ADRP	X28, wdict@PAGE		
	ADD		X28, X28, wdict@PAGEOFF	
	B		251f

222:
	CMP		W0, #'x'
	B.ne	223f
	ADRP	X28, xdict@PAGE		
	ADD		X28, X28, xdict@PAGEOFF	
	B		251f

223:
	CMP		W0, #'y'
	B.ne	224f
	ADRP	X28, ydict@PAGE		
	ADD		X28, X28, ydict@PAGEOFF	
	B		251f

224:
	CMP		W0, #'z'
	B.ne	225f
	ADRP	X28, zdict@PAGE		
	ADD		X28, X28, zdict@PAGEOFF	
	B		251f		

225:

searchall:
	; search from bottom of dictionary
	; from here X28 is current word in sdict
	ADRP	X28, startdict@PAGE		
	ADD		X28, X28, startdict@PAGEOFF
251:	
	SUB		X28, X28, #64

	RET


;; start running here

main:	



	; here we set some global values
	; the dictionary end, the data (parameter) stack
	; and the return stack.
	

init:	

	ADRP	X27, dend@PAGE	;; <-- dictionary end
	ADD		X27, X27, dend@PAGEOFF

	ADRP	X0, dsp@PAGE		
	ADD		X0, X0, dsp@PAGEOFF
	LDR		X16, [X0]  ;; <-- data stack pointer to X16

	ADRP	X0, rsp@PAGE		
	ADD		X0, X0, rsp@PAGEOFF
	LDR		X14, [X0]  ;; <-- return stack pointer to X14

	ADRP	X26, lsp@PAGE		
	ADD		X26, X26, lsp@PAGEOFF
 


	;  disable tracing, X6 = 0
	MOV		X6, #0

	; start of outer interpreter/compiler
	;
	;
	BL  cls
	BL  announce
	BL  dotwords
input:	
	BL  chkoverflow
	BL  chkunderflow
	BL  sayok
	BL  resetword
	BL  resetline
	BL  getline

advance_word:

10:	BL  advancespaces

	BL  collectword

	; check if we have read all available words in the line
	BL		empty_wordQ
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
	save_registers
	STP		X1, X0, [SP, #-16]!
	BL		_fputs	
	ADD		SP, SP, #16 
	restore_registers
	MOV		X0, #0
	BL		_exit


	; outer interpreter called QUIT in typical FORTH
	; look for WORDs - when found, execute the words function	
	; we are in immediate mode, we see a word and we execute its code.

outer:	
	

interpret_word:	

	ADRP	X22, zword@PAGE		
	ADD		X22, X22, zword@PAGEOFF
	LDRB	W0, [X22, #1]
	CMP		W0, #0
	B.ne	fw1	

short_words:

	; we have a byte length word.

	; check if we need to enter the compiler loop.
	LDRB	W0, [X22]
	CMP		W0, #':'	; do we enter the compiler ?
	B.eq	enter_compiler

	CMP		W0, #';'	; do we exit the compiler ?
	B.eq	exit_compiler


	; check if we need to enter the compiler loop.
	LDRB	W0, [X22]
	CMP		W0, #']'	; do we enter the compiler ?
	B.eq	enter_compiler

fw1:
	BL		start_point	


252: 
	BL		get_word
	
	LDR		X21, [X28, #48]		; name field
	CMP		X21, #0				; end of list?
	B.eq	finish_list	
	CMP		X21, #-1		; undefined entry in list?
	b.eq	251b

	CMP		X21, X22		; is this our word?
	B.ne	251b

	; we found our word, execute its runtime function
 
	LDR		X2, [X28, #8]  
	CMP		X2, #0 
	B.eq	finish_list

	LDR		X0, [X28] ; data (argument)
	STP		X28, XZR, [SP, #-16]!
	
	MOV		X1, 	X28
	
	BLR		X2	;; call function with X0=data, X1=address

	LDP		X28, XZR, [SP] 

	B		advance_word

finish_list: ; we did not find a defined word.


20:
	; look for an integer number made of decimal digits.
	; If found immediately push it onto our Data Stack

	ADRP	X22, zword@PAGE		
	ADD		X22, X22, zword@PAGEOFF
	
	; tolerate a negative number
	LDRB	W0, [X22]
	CMP		W0, #'-'
	B.ne	22f 
	ADD		X22, X22, #1
	LDRB	W0, [X22]

22:
	CMP		W0, #'9'
	B.gt	30f
	CMP	W0, #'0'
	B.lt	30f

23:	ADD		X22, X22, #1
	LDRB	W0, [X22]
	CMP		W0, #0
	B.eq	24f
	CMP		W0, #'.'
	B.eq	30f
	CMP		W0, #'9'
	B.gt	30f
	CMP		W0, #'0'
	B.lt	30f
	
	B		23b
24:
	; we have a valid number, so we translate it
	BL		word2number
	B		advance_word

	
30:	; exit number


decimal_number:

	; OR the word may be a floating point decimal number
	; TODO check for floating point and convert it.
	; from here we are no longer interpreting the line.
	; we are compiling input from ':' until we see a ';'

compiler:

	ADRP	X22, zword@PAGE		
	ADD		X22, X22, zword@PAGEOFF
	
	LDRB	W0, [X22]
	CMP		W0, #':'	; do we enter the compiler ?
	B.ne	not_compiling ; no..

	; yes, from here we compile a new word.

enter_compiler:

	; look for the name of the new word we are compiling.
	BL 		advancespaces
	BL 		collectword
	BL		get_word
	BL		empty_wordQ
	B.eq	exit_compiler_word_empty 

create_word: 

	BL		start_point

	; find free word and start building it

scan_words:

	LDR		X1, [X28, #48] ; name field
	LDR		X0, [X22]
	CMP		X1, X0
	B.eq	exit_compiler_word_exists; word exists

	CMP		X1, #0		; end of list?
	B.eq	exit_compiler ; no room in dictionary

	CMP		X1, #-1		; undefined entry in list?
	b.ne	try_next_word

	; undefined word found so build the word here

	; this is now the last_word word being built.
	ADRP	X1, last_word@PAGE		
	ADD		X1, X1, last_word@PAGEOFF
	STR		X28, [X1]


	; copy words name text over
	LDR		X0, [X22]
	STR		X0, [X28, #48]
	ADD		X22, X22, #8
	LDR		X0, [X22]
	STR		X0, [X28, #56]


	CBZ		X6, faster_mode

	ADRP	X1, runintz@PAGE	; high level word.	
	ADD		X1, X1, runintz@PAGEOFF
	STR		X1, [X28, #8]
	B		set_word_runtime

faster_mode:

	ADRP	X1, fastrunintz@PAGE	; high level word.	
	ADD		X1, X1, fastrunintz@PAGEOFF
	STR		X1, [X28, #8]

set_word_runtime:

	ADRP	X8, here@PAGE	
	ADD		X8, X8, here@PAGEOFF
	LDR		X15, [X8]

	ADRP	X8, lasthere@PAGE	
	ADD		X8, X8, lasthere@PAGEOFF
	STR		X15, [X8]


	STR		X15, [X28]		; set start point
 
	B		compile_words

	
try_next_word:	; try next word in dictionary
	SUB		X28, X28, #64
	B		scan_words
	
	
; we created a word header and stored it in last_word word


compile_words:

	MOV		X0,  #'!'  
	STP		X0,  X0, [X14], #16

	MOV		X4, #0

compile_next_word:


	
	; is the dictonary word full

	ADRP	X1, last_word@PAGE		
	ADD		X1, X1, last_word@PAGEOFF
	LDR		X1, [X1]
	SUB		X0, X15, X1
	CMP		X0, #124
	B.gt	exit_compiler_word_full

	; get next word from line
	BL 		advancespaces
	BL 		collectword
	BL		get_word
	BL		empty_wordQ
	B.eq	exit_compiler_no_words

	BL		start_point

	CMP		W0, #';'	; do we exit the compiler now ?
	B.eq	exit_compiler


find_word_token:

	LDR		X21, [X28, #48] ; name field
	ADD		X0, X28, #48
	
	CMP		X21, #0	; no word found
	B.eq	try_compiling_literal	

	CMP		X21, #-1		
	b.eq	keep_finding_tokens

	ADRP	X22, zword@PAGE		
	ADD		X22, X22, zword@PAGEOFF
	LDR		X22, [X22]
	CMP		X21, X22		; is this our word?
	B.ne	keep_finding_tokens

	
	; yes we have found our word


	; found word (at X28), get token.
	MOV		X1, X28
	MOV		X2, X27 ; dend
	SUB		X1, X1, X2
	LSR		X1, X1, #6	; * 64

	; X1 is token store halfword in [x15]
	STRH	W1, [X15]


	; if the word has a compile time action, we will call it.

	; check word type and skip if not primitive.
	; is this necessary?
	ADRP	X1, runintz@PAGE	; high level word.	
	ADD		X1, X1, runintz@PAGEOFF
	LDR		X0, [X28, #8]
	CMP		X0, X1
	B.eq	skip_compile_time


	ADRP	X1, fastrunintz@PAGE	; high level word.	
	ADD		X1, X1, fastrunintz@PAGEOFF
	LDR		X0, [X28, #8]
	CMP		X0, X1
	B.eq	skip_compile_time


	ADRP	X1, daddrz@PAGE	; high level word.	
	ADD		X1, X1, daddrz@PAGEOFF
	CMP		X0, X1
	B.eq	skip_compile_time

	; invoke compile time function
	LDR		X2, [X28, #24]
	CBZ		X2, skip_compile_time

	; a reason the compiler is very small is 
	; that words help compile themselves which happens here
	STP		X5, X7, [SP, #-16]!
	STP		X3, X4, [SP, #-16]!
	STP		X28, X16, [SP, #-16]!

	LDR		X0, [X28] ; data
	MOV		X1, X28

	; compile time functions can change X14, X15

	BLR		X2	;; call function X0 =data, X1=address
	
	
	LDP		X28, X16, [SP]
	LDP		X3, X4, [SP]
	LDP		X5, X7, [SP]

	; words that assist the compiler must return 0, or -1 in X0 for status

	CMP		X0, #-1 ; fail compile time call.
	B.eq	exit_compiler_compile_time_err


skip_compile_time:
	; increment X15 after the compile time function.

	ADD		X15, X15, #2

	; most words have no compile time action 

	; we finished compiling tokens, fetch next word.
	B		finished_compiling_token


keep_finding_tokens:	
	
	; next word in dictionary
	SUB		X28, X28, #64
	B		find_word_token


finished_compiling_token:

	B		compile_next_word


try_compiling_literal:


20:
	; look for an integer number made of decimal digits.
	; If found  store a literal in our word.

	ADRP	X22, zword@PAGE		
	ADD		X22, X22, zword@PAGEOFF
	; tolerate a negative number
	LDRB	W0, [X22]
	CMP		W0, #'-'
	B.ne	22f 
	ADD		X22, X22, #1
	LDRB	W0, [X22]

22:
	CMP		W0, #'9'
	B.gt	30f
	CMP		W0, #'0'
	B.lt	30f

23:	ADD		X22, X22, #1
	LDRB	W0, [X22]
	CMP		W0, #0
	B.eq	24f
	CMP		W0, #'.'
	B.eq	30f
	CMP		W0, #'9'
	B.gt	30f
	CMP		W0, #'0'
	B.lt	30f
	
	B		23b
24:
	; we have a valid number, so translate it
	ADRP	X0, zword@PAGE		
	ADD		X0, X0, zword@PAGEOFF

	save_registers
	BL		_atoi
	restore_registers  

	; halfword numbers ~32k
	MOV		X3, #4000
	LSL		X3, X3, #3  
	MOV		X1, x0
	CMP		X0, X3 
	B.gt	25f  ; too big to be

	MOV		X0, #1 ; #LITS
	STRH	W0, [X15]
	ADD		X15, X15, #2
	STRH	W1, [X15]	; value
	ADD		X15, X15, #2
	B		compile_next_word


25:	; long word
	; we need to find or create this in the literal pool.

	; X0 is our literal 
	ADRP	X1, quadlits@PAGE	
	ADD		X1, X1, quadlits@PAGEOFF
	MOV		X3, XZR

10:
	LDR		X2, [X1]
	CMP		X2, X0
	B.eq	80f
	CMP		X2, #-1  
	B.eq	70f
	CMP		X2, #-2 ; end of pool ERROR  
	B.eq	exit_compiler_pool_full
	ADD		X3, X3, #1
	ADD		X1, X1, #8
	B		10b	
70:
	; literal not present 
	; free slot found, store lit and return value
	STR		X0, [X1]
	
	
	MOV		X0, #2 ; #LITL
	STRH	W0, [X15]
	ADD		X15, X15, #2
	STRH	W3, [X15]	; value
	ADD		X15, X15, #2

	B		compile_next_word

80:
	; found the literal

	MOV		X0, #2 ; #LITL
	STRH	W0, [X15]
	MOV		X1, X3
	STRH	W1, [X15]	; value
	ADD		X15, X15, #2

	B		compile_next_word

30:	; exit number means word not found/not number

	B		exit_compiler_unrecognized


; word not recognized
exit_compiler_unrecognized:
	SUB		X14, X14, #16
	BL	saylb
	BL	sayword
	BL	sayrb
	BL	saynotfound
	BL	saycr
	reset_data_stack
	BL	clean_last_word
	B	input ; back to immediate mode


; literal pool  is full.
exit_compiler_pool_full:
	SUB		X14, X14, #16
	reset_data_stack
	BL		clean_last_word
	ADRP	X0, poolfullerr@PAGE	
	ADD		X0, X0, poolfullerr@PAGEOFF
	BL		sayit

	B		input ; back to immediate mode

exit_compiler_compile_time_err:
	SUB		X14, X14, #16
	reset_data_stack
	BL		clean_last_word
	; compile time function returned error
	ADRP	X0, tcomer9@PAGE	
	ADD		X0, X0, tcomer9@PAGEOFF
	BL		sayit
	B		input ; back to immediate mode


exit_compiler_unbalanced_loops:
	BL		clean_last_word
	reset_data_stack
	ADRP	X0, tcomer30@PAGE	
	ADD		X0, X0, tcomer30@PAGEOFF
	BL		sayit
	B		input ; back to immediate mode



exit_compiler_word_empty:
	SUB		X14, X14, #16
	reset_data_stack
	; : was followed by nothing which is an error.
	ADRP	X0, tcomer1@PAGE	
	ADD		X0, X0, tcomer1@PAGEOFF
	BL		sayit
	B		input ; back to immediate mode
	

exit_compiler_word_full:
	SUB		X14, X14, #16
	; TODO reset new  word, and stack
	reset_data_stack
	BL		clean_last_word
	BL		sayerrlength
	B		input ; 


exit_compiler_word_exists:
	SUB		X14, X14, #16
	reset_data_stack
	BL		err_word_exists
	B		input ;  

exit_compiler_no_words:

	; we ran out of words in this line.
	reset_data_stack
	BL  resetword
	BL  resetline
	BL  getline
	B	compile_next_word


exit_compiler: ; NORMAL success exit
	

	LDP		X0, X1,  [X14, #-16]  
	CMP		X0, '!'
	B.ne	exit_compiler_unbalanced_loops
	CMP		X1, '!'
	B.ne	exit_compiler_unbalanced_loops
	SUB		X14, X14, #16

	MOV		X0, #0 ; EXIT
	STRH	W0, [X15]
	ADD		X15, X15, #2
	MOV		X0, #0 ; EXIT
	STRH	W0, [X15]
	ADD		X15, X15, #2

	ADRP	X1, last_word@PAGE		
	ADD		X1, X1, last_word@PAGEOFF
	LDR		X1, [X1]
	
	ADRP	X8, here@PAGE	
	ADD		X8, X8, here@PAGEOFF
	STR		X15, [X8]

	ADRP	X8, lasthere@PAGE	
	ADD		X8, X8, lasthere@PAGEOFF
	LDR		X0, [X8]

	SUB		X0, X15, X0
	BL		X0print
	BL		saycompfin

	B		advance_word ; back to main loop



not_compiling:

; at this point we have not found this word
; display word not found as an error.

	BL		saycr
	BL		saylb
	BL		sayword
	BL		sayrb
	BL		saynotfound
	B		advance_word


exit_program:	

	MOV		X0, #0
	BL		_exit
	
	;brk #0xF000
	
190:	
	RET



; Return stack
; The word execution uses the machine stack pointer
; So the return stack is NOT actually used for return addresses
; it is used to stack LOOP addresses

dtorz:
	LDR		X0, [X16, #-8]	
	STR		X0, [X14], #8
	SUB		X16, X16, #8
	RET

dtorc:
	RET

dfromrz:
	LDR		X0, [X14, #-8]	
	STR		X0, [X16], #8
	SUB		X14, X14, #8
	RET

	RET

dfromrc:
	RET

dratz:
	LDR		X0, [X14, #-8]
	STR		X0, [X16], #8
	RET


fetchspz: ; fetch stack pointer to stack
	MOV     X0, X16
	STR		X0, [X16], #8
	RET

fetchrpz: ; fetch stack pointer to stack
	MOV     X0, X14
	STR		X0, [X16], #8
	RET


; locals
; local stack indexed by X26
; 0..  7 A
; 8.. 15 B
; 16..23 C
; 24..39
; 40..47
; 48..55
; 56..63
;
;



dlocaz:	; LOCAL A
	LDR		X0, [X26, #-64]	
	STR		X0, [X16], #8
	RET

dlocasz: 
	LDR		X0,	[X16, #-8]!
	STR		X0, [X26, #-64]
	RET


dlocbz:	; LOCAL B
	LDR		X0, [X26, #-8]	
	STR		X0, [X16], #8
	RET

dlocbsz:
	LDR		X0,	[X16, #-8]!
	STR		X0, [X26, #-8]
	RET

dloccz:	; LOCAL C
	LDR		X0, [X26, #-16]	
	STR		X0, [X16], #8
	RET

dloccsz:
	LDR		X0,	[X16, #-8]!
	STR		X0, [X26, #-16]
	RET


dlocdz:	; LOCAL D
	LDR		X0, [X26, #-24]	
	STR		X0, [X16], #8
	RET

dlocdsz:
	LDR		X0,	[X16, #-8]!
	STR		X0, [X26, #-24]
	RET


dlocez:	; LOCAL E
	LDR		X0, [X26, #-32]	
	STR		X0, [X16], #8
	RET


dlocesz:
	LDR		X0,	[X16, #-8]!
	STR		X0, [X26, #-32]
	RET


dlocfz:	; LOCAL F
	LDR		X0, [X26, #-48]	
	STR		X0, [X16], #8
	RET

dlocfsz:
	LDR		X0,	[X16, #-8]!
	STR		X0, [X26, #-40]
	RET

dlocgz:	; LOCAL G
	LDR		X0, [X26, #-48]	
	STR		X0, [X16], #8
	RET

dlocgsz:
	LDR		X0,	[X16, #-8]!
	STR		X0, [X26, #-48]
	RET


dlochz:	; LOCAL H
	LDR		X0, [X26, #-56]	
	STR		X0, [X16], #8
	RET


dlochsz:
	LDR		X0,	[X16, #-8]!
	STR		X0, [X26, #-56]
	RET



; DO LOOP words
; The definite loops
; Not compliant with standard FORTH.
;

; DO .. LOOP, +LOOP uses the return stack.
; LEAVE does an immediate early exit

; #21DOER 
; checks arguments

stckdoargsz:

	STP		LR,  X12, [SP, #-16]!
	MOV		X12, X15
	; Get my arguments
	LDP 	X0, X1,  [X16, #-16]  
	SUB		X16, X16, #16

	; Stack arguments 21, literal address, start, limit
	
	MOV		X2,  #21 ; DO
	STP		X2,  X12, [X14], #16
	STP		X0,  X1,  [X14], #16

	LDP		LR, X12, [SP], #16

	RET


; as above but includes skip forwards

ddoerz:

	STP		LR,  X12, [SP, #-16]!
	MOV		X12, X15

	; do we have two arguments
	ADRP	X8, dsp@PAGE		
	ADD		X8, X8, dsp@PAGEOFF
	LDR		X0, [X8]
	SUB		X0, X16, X0
	LSR		X0, X0, #3
	CMP		X0, #2
	B.lt	do_loop_arguments	

	; Get my arguments
	LDP 	X0, X1,  [X16, #-16]  
	SUB		X16, X16, #16

	; Stack arguments 21, literal address, start, limit
	MOV		X2,  #21 ; DO
	STP		X2,  X12, [X14], #16
	STP		X0,  X1,  [X14], #16


	; Check my arguments
	CMP		X0, X1
	B.lt	skip_do_loop

	B		200f



ddowndoerz:

	STP		LR,  X12, [SP, #-16]!
	MOV		X12, X15

	; do we have two arguments
	ADRP	X8, dsp@PAGE		
	ADD		X8, X8, dsp@PAGEOFF
	LDR		X0, [X8]
	SUB		X0, X16, X0
	LSR		X0, X0, #3
	CMP		X0, #2
	B.lt	do_loop_arguments


	; Get my arguments
	LDP 	X0, X1,  [X16, #-16]  
	SUB		X16, X16, #16

	; Stack arguments 22, literal address, start, limit
	MOV		X2,  #22 ; DODOWN
	STP		X2,  X12, [X14], #16
	STP		X0,  X1,  [X14], #16

	; Check my arguments
	CMP		X0, X1
	B.gt	skip_do_loop

	B		200f


dochecker:

skip_do_loop:
	
	ADD		X15, X15, #2

	MOV		X2, #1 	; find at least one loop

skipper:

	LDRH	W0, [X15]
	
	CMP		W0, #21 ; found DO
	B.eq	count_up

	CMP		W0, #17
	B.eq	found_loop

	CMP		W0, #18
	B.eq	found_loop

	CMP		W0, #19
	B.eq	found_loop

	ADD		X15, X15, #2
	B		skipper

count_up:	; we found a DO so we need to find more than one loop
	ADD		X2, X2, #1
	B		skipper

found_loop:
	SUB		X2, X2, #1
	CBZ		X2, found_loops
	B		skipper

 found_loops:
	SUB		X0, X15, X12	
	B		200f


do_without_loop:
	; detected 'at runtime' by magic number	test
	ADRP	X0, tcomer16@PAGE	
	ADD		X0, X0, tcomer16@PAGEOFF
	BL		sayit	


do_loop_arguments:
	; not enough arguments
	ADRP	X0, tcomer20@PAGE	
	ADD		X0, X0, tcomer20@PAGEOFF
	BL		sayit	
	LDP		LR, X15, [SP], #16	; unwind word


200:
	LDP		LR, X12, [SP], #16
	RET


.macro loop_vars
	LDP		X0, X1,  [X14, #-16]
	LDP		X2, X12, [X14, #-32]	
	CMP		X2, #21 ; DOOER
	B.ne	do_loop_err 
.endm

.macro loop_continues
	STP		X0,  X1,  [X14, #-16]
	STP		X2,  X12, [X14, #-32]
.endm

dplooperz:

	loop_vars

	LDR		X2, [X16, #-8]
	SUB		X16, X16, #8	

	ADD		X1, X1, X2

	CMP		X0, X1
	B.lt	loops_end

	MOV		X2, #21 ; DOOER
	loop_continues

	MOV		X15, X12
	RET


; -LOOP is non standard

dmlooperz:

	LDP		X0, X1,  [X14, #-16]
	LDP		X2, X12, [X14, #-32]	
	CMP		X2, #22 ; DOWNDOER
	B.ne	do_loop_err 

	LDR		X2, [X16, #-8]
	SUB		X16, X16, #8	

	SUB		X1, X1, X2

	CMP		X0, X1
	B.gt	loops_end

	MOV		X2, #22 ; DODOWNER
	loop_continues
	
	MOV		X15, X12
	RET	


dlooperz: ; LOOP sense add or sub

	LDP		X0, X1,  [X14, #-16]
	LDP		X2, X12, [X14, #-32]	
	CMP		X2, #21 ; DOOER
	B.eq	dlooperadd
	CMP		X2, #22 ; DODOWN
	B.eq	dloopersub
	B		do_loop_err

dloopersub:
	SUB		X1, X1, #1
	B		ddownloopercmp

dlooperadd:	
	ADD		X1, X1, #1

dloopercmp:

	CMP		X0, X1
	B.lt	loops_end

	loop_continues

	MOV		X15, X12

	RET

ddownloopercmp:

	CMP		X0, X1
	B.gt	loops_end

	loop_continues

	MOV		X15, X12

	RET


loops_end:  ; loop end
	
	SUB		X14, X14, #32 ; unstack loop value
	


	RET

do_loop_err:
	reset_return_stack
	LDP		LR, X15, [SP], #16	; unstack word
	ADRP	X0, tcomer18@PAGE	
	ADD		X0, X0, tcomer18@PAGEOFF
	B		sayit
		
	RET	

; compile in DO LOOP, +LOOP, DOWNDO -LOOP

doerc:
	MOV	X0, #21 ; 
	STRH W0, [X15] ; replace code
	RET
	

ddownerc:
	MOV	X0, #22 ; 
	STRH W0, [X15] ; replace code
	RET


dloopc:
	MOV	X0, #19
	STRH W0, [X15] ; replace code

	LDP		X1, X12,  [X14, #-16] ; X5 is branch
	CMP		X1, #13 ; (LEAVE) we MAY have a leave to patch
	B.ne 	20f

	SUB		X0, X15, X12 ; dif between REPEAT/AGAIN and (LEAVE).
	ADD		X0, X0, #2
	STRH	W0, [X12]	 ; store that
	SUB		X14, X14, #16
20:

	RET
	
	
dploopc: 
	MOV	X0, #17
	STRH W0, [X15] ; replace code

	RET

	
dmloopc: 
	MOV	X0, #18
	STRH W0, [X15] ; replace code

	RET










; The INDEFINITE LOOPS
; BEGIN stacks its address, AGAIN, UNTIL, REPEAT and LEAVE use that.
;
; BEGIN ... AGAIN
; BEGIN ... f UNTIL
; BEGIN .. f WHILE .... REPEAT
;
; LEAVE (LEAVE) and WHILE (WHILE) use a branch.
; AGAIN/REPEAT must fix up branch offsets.

dbeginz: ; BEGIN runtime

	MOV		X2,  #'B' ;  BEGIN 
	STP		X2,  X15, [X14], #16

190:
	RET


dbeginc: ; COMPILE BEGIN
	; Stack begins IP
	MOV		X2,  #'B' ;  BEGIN 
	STP		X2,  X15, [X14], #16
	MOV		X0, #0
	RET
 

; : t2 BEGIN 1+ DUP DUP . CR 10 >  UNTIL .' fini ' DROP ;

duntilz: ; UNTIL runtime

	LDP		X2, X5,  [X14, #-16] ; X5 is branch
	CMP		X2, #'B' ;BEGIN
	B.ne	190f ; UNTIL needs BEGIN

	; I am in a BEGIN loop testing UNTIL

	LDR		X1, [X16, #-8]
	SUB		X16, X16, #8	
	CMP		X1, #-1
	B.eq	180f	

	; not true
	MOV		X15, X5	; back we go
	RET

	; true I am finishing
180:
	SUB		X14, X14, #16
	RET 

 

duntilc:

	RET

		; : t3 BEGIN  1 + DUP 10 < WHILE DUP . CR REPEAT ;
dwhilez: ; WHILE needs a foward branch to REPEAT

	do_trace

	LDP		X2, X5,  [X14, #-16] ; X5 is branch
	CMP		X2, #'B' ;BEGIN is left for REPEAT
	B.ne	190f

	; I am in a BEGIN loop testing while
	
	LDR		X1, [X16, #-8]
	SUB		X16, X16, #8	
	CMP		X1, #-1
	B.eq	180f		; loop finishes

	; skip forward to REPEAT
	do_trace
 

	ADD		X15, X15, #2
	LDRH	W5, [X15]
	SUB		X5, X5, #2
	ADD		X15, X15, X5 ; jump to REPEAT

	RET 


180:
 	ADD		X15, X15, #2
	RET




190:	; UNTIL/AGAIN needs BEGIN

	ADRP	X0, tcomer23@PAGE	
	ADD		X0, X0, tcomer23@PAGEOFF
	BL		sayit

	LDP		LR, X15, [SP], #16	
	RET



dwhilec: ; COMPILE (WHILE)

	LDP		X2, X5,  [X14, #-16] ; X5 is branch
	CMP		X2, #'B' ;BEGIN
	B.ne	190f

	; pop BEGIN
	SUB		X14, X14, #16 ;  

	MOV		X0, #9 ; (WHILE)
	STRH	W0, [X15] 
	ADD		X15, X15, #2
	MOV		X0, #1234 
	STRH	W0, [X15] ; dummy offset

	; push WHILE for REPEAT
	MOV		X0, #9 ;  
	STP		X0,  X15, [X14], #16 ; save branch
	MOV		X0, #0
	RET


190:	; WHILE needs BEGIN

	ADRP	X0, tcomer25@PAGE	
	ADD		X0, X0, tcomer25@PAGEOFF
	BL		sayit
 	MOV		X0, #-1
	RET

 
; BEGIN -- f WHILE -- REPEAT

drepeatz: ; REPEAT

	do_trace

	LDP		X2, X5,  [X14, #-16] ; X5 is branch
	CMP		X2, #'B' ;BEGIN
	B.ne	190f

	MOV		X15, X5	; back we go
 
	RET


drepeatc:	; COMPILE REPEAT


	STP		LR,  X12, [SP, #-16]!

	LDP		X1,  X12,  [X14, #-16]  
	CMP		X1, #9 ; WHILE
	B.ne 	20f

	; FIX UP (WHILE)
	SUB		X0, X15, X12 ; BEGIN - WHILE - REPEAT
	ADD		X0, X0, #2
	STRH	W0, [X12]	 ; store that

30:
	MOV		X0, #0
	LDP		LR, X12, [SP], #16	
 
RET


170:	; Error - no BEGIN for our REPEAT.
	ADRP	X0, tcomer25@PAGE	
	ADD		X0, X0, tcomer25@PAGEOFF
	B		sayit
	MOV		X0, #-1
	RET			

190:	; Error - no WHILE for our REPEAT.
	ADRP	X0, tcomer24@PAGE	
	ADD		X0, X0, tcomer24@PAGEOFF
	B		sayit
	MOV		X0, #-1
	RET			


; : t2 BEGIN 1+ DUP 10 > IF LEAVE THEN DUP . CR AGAIN .' fini ' DROP ;

dagainz:	; AGAIN

	do_trace
	LDP		X2, X5,  [X14, #-16] ; X5 is branch
	CMP		X2, #'B' ;BEGIN
	B.ne	190f

	MOV		X15, X5	; back we go
 
	RET

	
190:	; continue - on as LEAVE popped BEGIN


	RET			
	

	

dagainc:	; COMPILE AGAIN
	 
	STP		LR,  X12, [SP, #-16]!
	
	LDP		X1, X12,  [X14, #-16] ; X5 is branch
	CMP		X1, #13 ; (LEAVE) we MAY have a leave to patch
	B.ne 	20f

	; FIX UP (LEAVE)
	SUB		X0, X15, X12 ; dif between REPEAT/AGAIN and (LEAVE).
	ADD		X0, X0, #2
	STRH	W0, [X12]	 ; store that

20:
	CMP		X0, #'B' ; was that a BEGIN we saw?
	B.eq 	30f
	
	SUB		X14, X14, #16
	LDP		X0, XZR,  [X14, #-16] ; X5 is branch
	SUB		X14, X14, #16
	CMP		X0, #'B' ; BEGIN - WE MUST HAVE a BEGIN or error
	B.ne	190f

30:
	MOV		X0, #0
	LDP		LR, X12, [SP], #16	
 
RET

190:	; AGAIN needs BEGIN

	ADRP	X0, tcomer23@PAGE	
	ADD		X0, X0, tcomer23@PAGEOFF
	BL		sayit
	LDP		LR, X12, [SP], #16	
	MOV		X0, #-1
	RET



; LEAVE (LEAVE) runtime
; : t2 BEGIN 1+ DUP 10 > IF LEAVE THEN DUP . CR AGAIN .' fini ' DROP ;
dleavez:	; just LEAVE the enclosing loop
	STP		LR,  X5, [SP, #-16]!
	do_trace

	LDP		X2, XZR,  [X14, #-16]  
	LDP		X1, XZR,  [X14, #-32]  
	CMP		X1, #20 ; LOOP
	B.eq	100f
	CMP		X1, #21 ; LOOP
	B.eq	100f
	CMP		X1, #22 ; LOOP
	B.eq	100f

	CMP		X2, #'B' ;BEGIN
	B.ne	190f

	; I am in a BEGIN loop, pop it now and AGAIN will end
	SUB		X14, X14, #16

	; however I want to LEAVE right NOW not after one extra step.

	LDRH	W0, [X15, #2]
	ADD		X15, X15, X0 ; change IP

	do_trace

	LDP		LR, X5, [SP], #16	
	RET


100: ; LOOP exit

	SUB		X14, X14, #32
	LDRH	W0, [X15, #2]
	ADD		X15, X15, X0 ; change IP
	RET



190:	; not leaving a loop? leave whole word.
	do_trace
	LDP		LR, X5, [SP], #16	
	LDP		LR, X15, [SP], #16	
	RET


 ; LEAVE has to be careful
 ; LEAVE may find itself inside an IF statement.

dleavec:	; COMPILE LEAVE create branch slot, look out for IF

	MOV		X0, #13 ; (LEAVE)
	STRH	W0, [X15] 
	ADD		X15, X15, #2
	MOV		X0, #4321
	STRH	W0, [X15] ; slot

	LDP		X1, X2,  [X14, #-16]  
	SUB		X14, X14, #16 ; pop
	CMP		X1, #'B' ;BEGIN
	B.eq	80f
	CMP		X1, #3 ; (IF)
	B.eq	90f
	B  		100f

80: ; restack BEGIN
	MOV		X0, #'B' ;  
	STP		X0,  X2, [X14], #16 
	B		100f

90: ; STACK LEAVE UNDER (IF)
	; (LEAVE)
	MOV		X0, #13  
	STP		X0,  X15, [X14], #16 
	; (IF)
 	MOV		X0, #3  
	STP		X0,  X2, [X14], #16 
	B 		180f

100:
	; just stack LEAVE
	MOV		X0, #13 ; (LEAVE)  
	STP		X0,  X15, [X14], #16

180:	
	MOV		X0, #0
	RET

190:
	MOV		X0, #-1
	RET


;;



dstorez:	; ( addr value -- )
	B		storz
	RET

dstorec:	; ( addr value -- )
	RET

dhstorez:	; ( addr value -- )
	B		hwstorz
	RET

dhstorec:	; ( addr value -- )
	RET

plustorz:

    LDR		X0, [X16, #-8] 
	LDR		X1, [X16, #-16]

 
	
	LDR 	X2, [X0]
	ADD		X1, X1, X2
	STR		X1, [X0]
	SUB		X16, X16, #16
	RET


dquotz:	; " 
	RET

dquotc:	; " 
	RET

dhashz:	; # 
	RET

dhashc:	; #
	RET

ddollarz: ; $ 
	RET

ddollarc: ; $ 
	RET

dmodz: ; %  MOD
	LDP 	X0, X1,  [X16, #-16]  
	UDIV	X2, X0, X1
	MSUB	X3, X2, X1, X0 
	STR		X3, [X16, #-16]
	SUB		X16, X16, #8
	RET


	RET

dmodc: ; % 
	RET


dandz: ; & 
	B		andz
	RET

dandc: ; & 
	RET


ddepthz: 

	ADRP	X0, spu@PAGE		
	ADD		X0, X0, spu@PAGEOFF
	CMP		X16, X0
	b.gt	50f	

	; reset stack we are under
	reset_data_stack
	
50:
	ADRP	X8, dsp@PAGE		
	ADD		X8, X8, dsp@PAGEOFF
	LDR		X0, [X8]
	SUB		X0, X16, X0

	LSR		X0, X0, #3
	STR		X0, [X16], #8	
	RET

ddepthc:

	RET


get_last_word:
	STP		X0, X1, [SP, #-16]!
	ADRP	X1, last_word@PAGE		
	ADD		X1, X1, last_word@PAGEOFF
	LDR		X0, [X1]
	STR		X0, [X16], #8
	LDP		X0, X1, [SP], #16	
	RET
 

clean_last_word:

	STP		X0, X1, [SP, #-16]!
	ADRP	X1, last_word@PAGE		
	ADD		X1, X1, last_word@PAGEOFF
	LDR		X0, [X1]
	CMP		X0, #-1
	B.eq	100f 

	MOV		X1, #-1
	STP		X1, X1, [X0], #16
	MOV		X1, #0
	STP		X1, X1, [X0], #16
	STP		X1, X1, [X0], #16
	MOV		X1, #-1
	STP		X1, X1, [X0], #16


	ADRP	X8, lasthere@PAGE	
	ADD		X8, X8, lasthere@PAGEOFF
	LDR		X0, [X8]

	ADRP	X8, here@PAGE	
	ADD		X8, X8, here@PAGEOFF
	STR		X0, [X8]


	RET


;;; test FIB

dtstfib:
	STP		LR,  X15, [SP, #-16]!

	LDR		X0, [X16, #-8]
	MOV		X1, #0
	MOV		X2, #1
floop:
	MOV		X3, X2
	ADD		X2, X1, X2
	MOV		X1, X3
	SUB		X0, X0, #1
	CMP		X0, #1
	B.ne	floop

	MOV		X0, X2
	STR		X0, [X16], #8
	LDP		LR, X15, [SP], #16
	RET	
	

fibtest: ; 1- DUP 1-'  
	LDR		X0, [X16, #-8]
	SUB		X0, X0, #1
	STR		X0, [X16, #-8]
	LDR		X0, [X16, #-8]
	SUB		X0, X0, #1
	STR		X0, [X16], #8
	RET 


;; Introseption and inspection
; good to see what our compiler is doing.
; displays a word in readable form


dseez:


100:	
	save_registers
	
	BL		advancespaces
	BL		collectword

	BL		empty_wordQ
	B.eq	190f

	BL		start_point


120:
	
	LDR		X21, [X28, #48] ; name field

	CMP		X21, #0		; end of list?
	B.eq	190f			; not found 
	CMP		X21, #-1		; undefined entry in list?
	b.eq	170f

	; check word

	BL		get_word
	LDR		X21, [X28, #48] ; name field
	CMP		X21, X22		; is this our word?
	B.ne	170f


	; see word

	ADRP	X0, word_desc11@PAGE		
	ADD		X0, X0, word_desc11@PAGEOFF
	BL		sayit

	MOV		X0, X28
	BL		X0addrpr

	ADD		X0, X28, #48
	BL		X0prname

	BL		saycr	
	
	; display the data word 0
	MOV		X0, #0
	BL		X0addrpr

	MOV		X0, #':'
	BL		X0emit

	LDR		X0, [X28]	
	BL		X0addrpr


	; anotate the data word

	ADRP	X2, dconstz@PAGE		
	ADD		X2, X2, dconstz@PAGEOFF
	LDR		X0, [X28, #8]
	CMP		X0, X2
	B.ne	12070f

	ADRP	X0, word_desc7@PAGE		
	ADD		X0, X0, word_desc7@PAGEOFF
	BL		sayit
	B		12095f

12070:

	ADRP	X2, dvaraddz@PAGE		
	ADD		X2, X2, dvaraddz@PAGEOFF
	LDR		X0, [X28, #8]
	CMP		X0, X2
	B.ne	12080f

	ADRP	X0, word_desc8@PAGE		
	ADD		X0, X0, word_desc8@PAGEOFF
	BL		sayit

	BL		saylb
	
	LDR		X0, [X28]
	LDR		X0, [X0]

	BL		X0addrpr
	BL		sayrb


	B		12095f

12080:

	ADRP	X0, word_desc9@PAGE		
	ADD		X0, X0, word_desc9@PAGEOFF
	BL		sayit
	B		12095f


12090:	; not a variable constant or high level word
	; so must be a primitive..
	ADRP	X0, word_desc10@PAGE		
	ADD		X0, X0, word_desc10@PAGEOFF
	BL		sayit
	B		12095f


12095:

	BL		saycr		


	; display this words runtime
	MOV		X0, #8
	BL		X0addrpr
	
	MOV		X0, #':'
	BL		X0emit

	LDR		X0, [X28, #8]
	BL		X0addrpr 

	ADRP	X2, dconstz@PAGE		
	ADD		X2, X2, dconstz@PAGEOFF
	LDR		X0, [X28, #8]
	CMP		X0, X2
	B.eq	12010f


	ADRP	X2, dvaraddz@PAGE		
	ADD		X2, X2, dvaraddz@PAGEOFF
	LDR		X0, [X28, #8]
	CMP		X0, X2
	B.eq	12020f

	


; must be a primitive word 


	ADRP	X0, word_desc3@PAGE		
	ADD		X0, X0, word_desc3@PAGEOFF
	BL		sayit


	; display the data word 1

	BL		saycr
	MOV		X0, #16
	BL		X0addrpr

	MOV		X0, #':'
	BL		X0emit

	LDR	X0, [X28, #16]	
	BL		X0addrpr


	ADRP	X0, word_desc10_1@PAGE		
	ADD		X0, X0, word_desc10_1@PAGEOFF
	BL		sayit
	
	; display this words compile time
	BL		saycr
	MOV		X0, #24
	BL		X0addrpr
	
	MOV		X0, #':'
	BL		X0emit

	; offset into word
	LDR		X0, [X28, #24]
	BL		X0addrpr 


	ADRP	X0, word_desc12@PAGE		
	ADD		X0, X0, word_desc12@PAGEOFF
	BL		sayit

	
	; display the data word 1

	BL		saycr
	MOV		X0, #32
	BL		X0addrpr

	MOV		X0, #':'
	BL		X0emit

	LDR	X0, [X28, #32]	
	BL		X0addrpr
	
	ADRP	X0, word_desc10_2@PAGE		
	ADD		X0, X0, word_desc10_2@PAGEOFF
	BL		sayit
	BL		saycr

	; display the data word 3

	
	MOV		X0, #40
	BL		X0addrpr

	MOV		X0, #':'
	BL		X0emit

	LDR		X0, [X28, #40]	
	BL		X0addrpr
	ADRP	X0, word_desc10_3@PAGE		
	ADD		X0, X0, word_desc10_3@PAGEOFF
	BL		sayit
	BL		saycr


	; display the name
	; offset into word
	MOV		X0, #48
	BL		X0addrpr
	
	MOV		X0, #':'
	BL		X0emit

 
	ADD		X0, X28, #48
	BL		X0prname 

	LDR		X12, [X28] ; words pointer
	
	ADRP	X0, word_desc5@PAGE		
	ADD		X0, X0, word_desc5@PAGEOFF
	BL		sayit
	BL		saycr

	ADRP	X2, runintz@PAGE		
	ADD		X2, X2, runintz@PAGEOFF
	LDR		X0, [X28, #8]
	CMP		X0, X2
	B.eq	see_HLW0


	ADRP	X2, limitrunintz@PAGE		
	ADD		X2, X2, limitrunintz@PAGEOFF
	LDR		X0, [X28, #8]
	CMP		X0, X2
	B.eq	see_HLW0


	ADRP	X2, fastrunintz@PAGE		
	ADD		X2, X2, fastrunintz@PAGEOFF
	LDR		X0, [X28, #8]
	CMP		X0, X2
	B.eq	see_HLW1


	B		160f


12010:	; CONSTANT
	ADRP	X0, word_desc1@PAGE		
	ADD		X0, X0, word_desc1@PAGEOFF
	BL		sayit
	B		160f


12020:	; VARIABLE
	ADRP	X0, word_desc2@PAGE		
	ADD		X0, X0, word_desc2@PAGEOFF
	BL		sayit
	B		160f


see_HLW0: ; HIGH LEVEL WORD

	ADRP	X0, word_desc4@PAGE		
	ADD		X0, X0, word_desc4@PAGEOFF
	BL		sayit
	BL		saycr

	B 		see_pointer

see_HLW1:
 
	ADRP	X0, word_desc4_1@PAGE		
	ADD		X0, X0, word_desc4_1@PAGEOFF
	BL		sayit
	BL		saycr
	

see_pointer:
	
	LDR		X12, [X28] ; words pointer

see_tokens:	

	BL		saycr

	MOV		X0, X12
	BL		X0addrpr

	LDRH	W0, [X12]
	CMP		W0, #0 ; END / EXIT
	B.eq	end_token

	BL		X0halfpr

	
	MOV		X2, X27 ; dend
	LDRH	W1, [X12]
	MOV		W14, W1
	LSL		X1, X1, #6	; / 64 
	ADD		X1, X1, X2 
	ADD		X0, X1, #48  ; name field
	BL		X0prname

	CMP		W14, #0; END / EXIT
	B.eq	literal_skip
	CMP		W14, #0 ; NULL
	B.eq	literal_skip
	CMP		W14, #16 ; do we have an inline argument?
	B.gt	literal_skip

litcont:
	; we are a word with a literal inline
	BL		saycr
	ADD		X12, X12, #2

	MOV		X0, X12
	BL		X0addrpr


	LDRH	W0, [X12]
	BL		X0halfpr
	

	MOV		X0, #'*'
	BL		X0emit

	CMP		W14, #2 ; LITL
	B.ne	literal_skip

	; Look up the LITLs value 
	LDRH	W0, [X12]
	ADRP	X1, quadlits@PAGE	
	ADD		X1, X1, quadlits@PAGEOFF
	LDR		X0, [X1, X0, LSL #3]
	BL		X0halfpr


literal_skip:


	ADD		X12, X12, #2
	B		see_tokens

end_token:
	ADRP	X0, tcomer19@PAGE	
	ADD		X0, X0, tcomer19@PAGEOFF
	BL		sayit	
	B.eq	160f
	
160:	
	BL		saycr
	restore_registers
	MOV		X0, #0
	RET


170:	; next word in dictionary
	SUB		X28, X28, #64
	B		120b

190:	; error out 
	MOV		X0, #-1
	restore_registers
	RET


dseec:
	RET


;; CREATION WORDS
;; add words to dictionary.
;; create, variable, constant
 

err_word_exists:
		
	; reset stack
	reset_data_stack
	save_registers_not_stack
	BL		saycr
	BL		saylb
	BL		sayword
	BL		sayrb
	ADRP	X0, texists@PAGE	
	ADD		X0, X0, texists@PAGEOFF
	restore_registers_not_stack
	B		sayit
	

; create, creates a standard word header.

dcreatz:

	save_registers

	BL		advancespaces
	BL		collectword
	BL		get_word
	BL		empty_wordQ
	B.eq	300f


	BL		start_point

100:	; find free word and start building it


	LDR		X1, [X28, #48] ; name field
	LDR		X0, [X22]
	CMP		X1, X0
	B.eq	290f

	CMP		X1, #0		; end of list?
	B.eq	280f			; not found 
	CMP		X1, #-1		; undefined entry in list?
	b.ne	260f

	; undefined so build the word here

	; this is now the last_word word being built.
	ADRP	X1, last_word@PAGE		
	ADD		X1, X1, last_word@PAGEOFF
	STR		X28, [X1]

	; copy text over
	LDR		X0, [X22]
	STR		X0, [X28, #48]
	ADD		X22, X22, #8
	LDR		X0, [X22]
	STR		X0, [X28, #56]


	CBZ		X6, 150f
	B 		160f

	ADRP	X1, runintz@PAGE	; high level word traceable	
	ADD		X1, X1, runintz@PAGEOFF
	STR		X1, [X28, #8]

150:
	ADRP	X1, fastrunintz@PAGE	; high level word not traceable  
	ADD		X1, X1, fastrunintz@PAGEOFF
	STR		X1, [X28, #8]

160:
	ADD		X1, 	X28, #32
	STR		X1, [X28]

	B		300f


260:	; try next word in dictionary
	SUB		X28, X28, #64
	B		100b

280:	; error dictionary FULL


300:
	restore_registers
	RET


dcreatc:
	RET



;; CONSTANT
;; e.g. 198 CONSTANT test198

; create constant, creates a standard word header.

dcreatcz:

	save_registers_not_stack

	BL		advancespaces
	BL		collectword
	BL		get_word
	BL		empty_wordQ
	B.eq	300f


	BL		start_point

100:	; find free word slot and start building a word in it


	LDR		X1, [X28, #48] ; name field
	LDR		X0, [X22]
	CMP		X1, X0
	B.eq	290f
	CMP		X1, #0		; end of list?
	B.eq	280f			; not found 
	CMP		X1, #-1		; undefined entry in list?
	b.ne	260f
	
	; undefined so build the word here

	; this is now the last_word word being built.
	ADRP	X1, last_word@PAGE		
	ADD		X1, X1, last_word@PAGEOFF
	STR		X28, [X1]

	; copy text for name over
	LDR		X0, [X22]
	STR		X0, [X28, #48]
	ADD		X22, X22, #8
	LDR		X0, [X22]
	STR		X0, [X28, #56]

	; constant code
	ADRP	X1, dconstz@PAGE	
	ADD		X1, X1, dconstz@PAGEOFF
	STR		X1, [X28, #8]


	; set constant from tos.
	LDR		X1, [X16, #-8]	
	SUB		X16, X16, #8
	STR		X1, [X28]

	B		300f


260:	; try next word in dictionary
	SUB		X28, X28, #64
	B		100b

280:	; error dictionary FULL

290:	; error word exist
	restore_registers_not_stack
	B err_word_exists

300:
	restore_registers_not_stack
	RET


dcreatcc:
	RET



;; VARIABLE
;; e.g. 198 VARIABLE test198

; create variable, creates a standard word header.

dcreatvz:

	save_registers_not_stack

	BL		advancespaces
	BL		collectword
	BL		get_word
	BL		empty_wordQ
	B.eq	300f


	BL		start_point

100:	; find free word and start building it


	LDR		X1, [X28, #48] ; name field
	LDR		X0, [X22]
	CMP		X1, X0
	B.eq	290b

	CMP		X1, #0		; end of list?
	B.eq	280f			; not found 
	CMP		X1, #-1		; undefined entry in list?
	b.ne	260f

	; undefined so build the word here

	; this is now the last_word word being built.
	ADRP	X1, last_word@PAGE		
	ADD		X1, X1, last_word@PAGEOFF
	STR		X28, [X1]

	; copy text for name over
	LDR		X0, [X22]
	STR		X0, [X28, #48]
	ADD		X22, X22, #8
	LDR		X0, [X22]
	STR		X0, [X28, #56]

	; variable code
	ADRP	X1, dvaraddz@PAGE	; high level word.	
	ADD		X1, X1, dvaraddz@PAGEOFF
	STR		X1, [X28, #8]

	ADD		X1, 	X28, #32
	STR		X1, [X28]

	; set variable from tos.
	LDR		X1, [X16, #-8]	
	SUB		X16, X16, #8
	STR		X1, [X28, #32]

	B		300f


260:	; try next word in dictionary
	SUB		X28, X28, #64
	B		100b

280:	; error dictionary FULL


300:
	restore_registers_not_stack
	RET


dcreatvc:
	RET


dtickz: ; ' - get address of NEXT words data field

100:	
	save_registers
	
	BL		advancespaces
	BL		collectword

	; display word to find
	;	BL		saycr
	;	BL		saylb
	;	BL		sayword
	;	BL		sayrb
 
	BL		empty_wordQ
	B.eq	190f

	BL		start_point

120:
	LDR		X21, [X28, #48] ; name field

	CMP		X21, #0		; end of list?
	B.eq	190f			; not found 
	CMP		X21, #-1		; undefined entry in list?
	b.eq	170f

	; check word

	; display word seen
	;BL		saycr
	;ADD		X0, X28, #8
	;BL		sayit 

	BL		get_word
	LDR		X21, [X28, #48] ; name field
	CMP		X21, X22		; is this our word?
	B.ne	170f

	; found word, stack address of word

	MOV	X0, 	X28  
	restore_registers

	B		stackit

170:	; next word in dictionary
	SUB		X28, X28, #64
	B		120b

190:	; error out 
	MOV		X0, #0
	restore_registers
	B	stackit


	RET




dcharz: ; char - stack char code while interpreting

10:	LDRB	W0, [X23]
	CMP		W0, #32
	ADD		X23, X23, #1
	B.eq	10b
	B		stackit

 
 
dcharc: ; char - convert Char to small lit while compiling.
	
	MOV		W0, #1 ; #LITS
	STRH	W0, [X15]
	ADD		X15, X15, #2

 10:	
 	LDRB	W0, [X23], #1
	CMP		W0, #32
	b.eq	10b
	CMP		W0, #10
	B.eq	20f
	CMP		W0, #12
	B.eq	20f
	CMP		W0, #13
	B.eq	20f
	CMP		W0, #0
	B.eq	20f

20:	
	STRH	W0, [X15]	; value
	ADD		X23, X23, #1

	MOV 	X0, #0

	RET
 


; control flow
; condition IF .. ELSE .. ENDIF 

difz:
	RET


difc:

	MOV		X0, #3 ; (IF)
	STRH	W0, [X15]
	ADD		X15, X15, #2
	MOV		X0, #4000 
	STRH	W0, [X15] ; dummy offset
	MOV		X0, #3 ; (IF)
	STP		X0,  X15, [X14], #16 ; save branch
	B		200f

190:	; error out 
	MOV		X0, #-1
200:
	RET			


dendifz:
	RET

; ENDIF	
; We are part of IF ..  ENDIF or IF .. ELSE  .. ENDIF
; We look for closest ELSE or IF by seeking the branch.

 

dendifc:
	
	;SUB	X15, X15, #2 ; do not compile endif

	LDP		X2, X5,  [X14, #-16] ; X5 is branch
	SUB		X14, X14, #16		; pop the ELSE/ENDIF
	CMP		X2, #4; (ELSE)
	B.eq	80f
	CMP		X2, #3; (IF)
	B.eq	100f
	B		190f  


80:	; fix up ELSE
	
	SUB		X4, X15, X5  ; dif between zbran and else.
	ADD		X4, X4, #0
	ADD		W4, W4, #32 ; avoid confusion
	STRH	W4, [X5]	; store that

	MOV		X0, #0
	B		200f


100: ; fix up IF
	
	SUB		X4, X15, X5  ; dif between zbran and (IF).
	ADD		X4, X4, #4
	ADD		W4, W4, #32 ; avoid confusion
	STRH	W4, [X5]	; store that

	MOV		X0, #0
	B		200f
 

190:	; error out - no IF for our ENDIF.
	
	ADRP	X0, tcomer9@PAGE	
	ADD		X0, X0, tcomer9@PAGEOFF
	BL		sayit	
		
	MOV		X0, #-1
	B		200f
	RET			

200:
	RET





delsez:
	RET


; ELSE

delsec: ;  at compile time inlines the ELSE branch


	MOV		X0, #4 ; #BRANCH
	STRH	W0, [X15]
	ADD		X15, X15, #2
	MOV		X0, #4000 
	STRH	W0, [X15] ; dummy offset for ENDIF
 
	; check for if
	LDP		X2, X5,  [X14, #-16] ; X5 is branch
	CMP		X2, #3 ; (IF)
	B.ne	190f

	; drop if and stack else
	SUB	X14, X14, #16
	MOV		X2, #4 ; (ELSE)
	STP		X2,  X15, [X14], #16 ; store ELSE address

	
	SUB		X4, X15, X5  ; dif between zbran and else.
	ADD		X4, X4, #4
	ADD		W4, W4, #32 ; avoid confusion
	STRH	W4, [X5]	; store that

	MOV		X0, #0
	B		200f

190:	; error out 
	MOV	X0, #-1

200:
	RET		

; if top of stack is zero branch

dzbranchz:

	do_trace
 
dzbranchz_notrace:

	LDR		X1, [X16, #-8]
	SUB		X16, X16, #8	
	CMP		X1, #0
	B.ne	90f

; it is zero, branch forwards n tokens		
80:
	
	LDRH	W0, [X15, #2]	; offset to endif
	SUB		W0, W0, #32		; avoid confusion 

 
	SUB		X0, X0, #2
	ADD		X15, X15, X0	; change IP

 

	RET

90:	
	ADD		X15, X15, #2	; skip offset
	RET  



dzbranchc:
	

	RET


; always branch 
dbranchz: ; (ELSE)
	
	do_trace	
	LDRH	W0, [X15, #2]	; offset to endif
	SUB		W0, W0, #32		; avoid confusion 
	ADD		X15, X15, X0	; change IP

	RET
dbranchc:
	RET



dtickc: ; ' at compile time, turn address of word into literal


100:	
	STP		X22, X28, [SP, #-16]!
	STP		X3,  X4, [SP, #-16]!
	STP		LR,  X16, [SP, #-16]!

	BL		advancespaces
	BL		collectword

 
	BL		empty_wordQ
	B.eq	190f

	BL		start_point

120:
	LDR		X21, [X28, #48] ; name field

	CMP		X21, #0		; end of list?
	B.eq	190f			; not found 
	CMP		X21, #-1		; undefined entry in list?
	b.eq	170f


	BL		get_word
	LDR		X21, [X28, #48] ; name field
	CMP		X21, X22		; is this our word?
	B.ne	170f

 

	; found word, push litl and create literal address of word

	MOV		X0, #2 ; #LITL
	STRH	W0, [X15]
	ADD		X15, X15, #2

	; find or create literal
	MOV		X0, X28	
	ADRP	X1, quadlits@PAGE	
	ADD		X1, X1, quadlits@PAGEOFF
	MOV		X3, XZR

10:
	LDR		X2, [X1]
	CMP		X2, X0
	B.eq	80f
	CMP		X2, #-1  
	B.eq	70f
	CMP		X2, #-2 ; end of pool ERROR  
	B.eq	190f ; error out
	ADD		X3, X3, #1
	ADD		X1, X1, #8
	B		10b	
70:
	; literal not present 
	; free slot found, store lit and return value
	STR		X0, [X1]
	MOV		X0, X3
	B		85f

80:
	; found the literal
	MOV		X0, X3
	B		85f


85:
	STRH	W0, [X15]	; value
	ADD		X15, X15, #2

	MOV		X0, #0		; no error
	B		200f


170:	; next word in dictionary
	SUB		X28, X28, #64
	B		120b

190:	; error out 
	MOV		X0, #-1
	B		200f


200:
	; restore registers for compiler loop
	LDP		LR, X16, [SP], #16
	LDP		X3, X4, [SP], #16	
	LDP		X22, X28, [SP], #16	
	RET


dnthz: ; from address, what is our position.
	MOV		X2, X27 ; dend
	LDR		X1, [X16, #-8]	
	SUB		X1, X1, X2
	LSR		X1, X1, #6	; / 64
	STR		X1, [X16, #-8]	
	RET

dnthc: ; '
	RET


daddrz: ; from our position, address
	MOV		X2, X27 ; dend
	LDR		X1, [X16, #-8]	
	LSL		X1, X1, #6	; / 64 
	ADD		X1, X1, X2
	STR		X1, [X16, #-8]	
	RET

daddrc: ; '
	RET



dcallz:	;  code field (from ' WORD on stack)

	LDR		X1, [X16, #-8]	
	SUB		X16, X16, #8
	LDR		X0, [X1]
	LDR		X1, [X1, #8]
	BR		X1		


dcallc:	; CALL code field (on stack)

; runintz is the inner interpreter of token 'compiled' words.
; X15 IP is our instruction pointer.
; there is a FASTER and a TRACEABLE version.
; You can switch between.

; A high level word is a list of tokens
; tokens are expanded to word addresses
; each word is then executed.


dtronz:
	MOV		X6, #-1
	RET

dtroffz:
	MOV		X6, #0
	RET

dtraqz:
	MOV		X0, X6
	B		stackit



dtickerz:
	MRS	X0, cntpct_el0
	B		stackit


dtimeitz: ; time the next work

	save_registers

	BL		advancespaces
	BL		collectword

	BL		empty_wordQ
	B.eq	190f

	BL		start_point

120:

	LDR		X21, [X28, #48] ; name field

	CMP		X21, #0		; end of list?
	B.eq	190f			; not found 
	CMP		X21, #-1		; undefined entry in list?
	b.eq	170f

	BL		get_word
	LDR		X21, [X28, #48] ; name field
	CMP		X21, X22		; is this our word?
	B.ne	170f


	MOV		X1, 	X28  
 
	; WORD IN X1

	LDR		X0, [X1]		; words data
	LDR		X2, [X1, #8]	; words code

	CBZ		X1, 200f
	CBZ		X2, 200f

	MRS		X12, cntpct_el0

	STP		LR,  X12, [SP, #-16]!

	BLR		X2		; with X0 as data and X1 as address
	
	LDP		LR, X12, [SP], #16	

	
	MRS		X1,  cntpct_el0
	SUB		X0, X1, X12
	MOV		X12, X0

	MOV		X2, #1000
	MOV		X1, #24			; 24000
	MUL		X1, X1, X2
	UDIV	X0, X0, X1		; ms

	BL		X0print
	
	ADRP	X0, tcomer21@PAGE	
	ADD		X0, X0, tcomer21@PAGEOFF
	BL		sayit

	MOV		X0, X12
	MOV		X2, #100
	MOV		X1, #24			; 2400
	MUL		X1, X1, X2
	UDIV	X0, X0, X1		; ns


	BL		X0print
	
	ADRP	X0, tcomer22@PAGE	
	ADD		X0, X0, tcomer22@PAGEOFF
	BL		sayit

	B		200f

170:	; next word in dictionary
	SUB		X28, X28, #64
	B		120b

190:	; error out 
	MOV	X0, #-1

200:
	restore_registers
	RET

 

; assign fast or tracable runtime to word.

; switch to tracable mode.
dtracable:

	save_registers

	BL		advancespaces
	BL		collectword

	BL		empty_wordQ
	B.eq	190f

	BL		start_point

120:
	LDR		X21, [X28, #48] ; name field

	CMP		X21, #0		; end of list?
	B.eq	190f			; not found 
	CMP		X21, #-1		; undefined entry in list?
	b.eq	170f

	BL		get_word
	LDR		X21, [X28, #48] ; name field
	CMP		X21, X22		; is this our word?
	B.ne	170f

	; is it high level
	LDR		X0, [X28, #8]	; words code
	ADRP	X8, runintz@PAGE	
	ADD		X8, X8, runintz@PAGEOFF
	CMP		X0, X8
	B.eq	140f

	ADRP	X8, fastrunintz@PAGE	
	ADD		X8, X8, fastrunintz@PAGEOFF
	STR		X8, [X28, #8]	; words code is now fast
	CMP		X0, X8
	B.eq	140f
	
	B 		200f
140:

	ADRP	X8, runintz@PAGE	
	ADD		X8, X8, runintz@PAGEOFF
	STR		X8, [X28, #8]	
	B		200f


170:	; next word in dictionary
	SUB		X28, X28, #64
	B		120b

190:	; error out 
	MOV	X0, #-1

200:
	restore_registers
	RET

; switch to fast mode
duntracable:

	save_registers

	BL		advancespaces
	BL		collectword

	BL		empty_wordQ
	B.eq	190f

	BL		start_point

120:
	LDR		X21, [X28, #48] ; name field

	CMP		X21, #0		; end of list?
	B.eq	190f			; not found 
	CMP		X21, #-1		; undefined entry in list?
	b.eq	170f

	BL		get_word
	LDR		X21, [X28, #48] ; name field
	CMP		X21, X22		; is this our word?
	B.ne	170f

	; is it high level
	LDR		X0, [X28, #8]	; words code
	ADRP	X8, runintz@PAGE	
	ADD		X8, X8, runintz@PAGEOFF
	CMP		X0, X8
	B.eq	140f

	ADRP	X8, fastrunintz@PAGE	
	ADD		X8, X8, fastrunintz@PAGEOFF
	STR		X8, [X28, #8]	; words code is now fast
	CMP		X0, X8
	B.eq	140f


	B 		200f

140:

	ADRP	X8, fastrunintz@PAGE	
	ADD		X8, X8, fastrunintz@PAGEOFF
	STR		X8, [X28, #8]	; words code is now fast
	B		200f


170:	; next word in dictionary
	SUB		X28, X28, #64
	B		120b

190:	; error out 
	MOV	X0, #-1

200:
	restore_registers
	RET




; switch to tracable mode for N steps
dlimited:


	save_registers

	BL		advancespaces
	BL		collectword

	BL		empty_wordQ
	B.eq	190f

	BL		start_point

120:
	LDR		X21, [X28, #48] ; name field

	CMP		X21, #0		; end of list?
	B.eq	190f			; not found 
	CMP		X21, #-1		; undefined entry in list?
	b.eq	170f

	BL		get_word
	LDR		X21, [X28, #48] ; name field
	CMP		X21, X22		; is this our word?
	B.ne	170f

	; is it high level
	LDR		X0, [X28, #8]	; words code
	ADRP	X8, runintz@PAGE	
	ADD		X8, X8, runintz@PAGEOFF
	CMP		X0, X8
	B.eq	140f

	ADRP	X8, fastrunintz@PAGE	
	ADD		X8, X8, fastrunintz@PAGEOFF
	STR		X8, [X28, #8]	; words code is now fast
	CMP		X0, X8
	B.eq	140f
	
	B 		200f
140:

	ADRP	X8, limitrunintz@PAGE	
	ADD		X8, X8, limitrunintz@PAGEOFF
	STR		X8, [X28, #8]	
	B		200f


170:	; next word in dictionary
	SUB		X28, X28, #64
	B		120b

190:	; error out 
	MOV	X0, #-1

200:
	restore_registers
	RET


; fast not traceable, otherwise the same as runintz below.

fastrunintcz: ; interpret the list of tokens at word + 

	; over ride X0 to compile time token address

	LDR		X0, [X1, #40]		; compile mode tokens


fastrunintz:; interpret the list of tokens at X0
	; until (END)

	; zero locals
	STP		XZR, XZR, [X26],#16
	STP		XZR, XZR, [X26],#16
	STP		XZR, XZR, [X26],#16
	STP		XZR, XZR, [X26],#16


	; SAVE IP 
	STP		LR,  X15, [SP, #-16]!
	SUB		X15, X0, #2
	MOV		X29, #64

	

	; unrolling the loop here x16 makes this a lot faster, 
10:	; next token
	
	.rept	16

		LDRH	W1, [X15, #2]!
		CBZ		X1, 90f
	 
		MADD	X1, X29, X1, X27
		LDP		X0, X2, [X1]
		CBZ		X2, 10b
	
		BLR		X2		; with X0 as data and X1 as address	

	.endr

	b		10b


90:
	LDP		LR, X15, [SP], #16	
	SUB		X26, X26, #64
	RET


; only run the word for STEPPING steps.
; allow word to be tested a few steps at a time. 
; 

stepoutz:

	MOV		X25, #-1
	B 		step_away

limitrunintz:; interpret the list of tokens at X0

	trace_show_word		
	STP		XZR, XZR, [X26],#16
	STP		XZR, XZR, [X26],#16
	STP		XZR, XZR, [X26],#16
	STP		XZR, XZR, [X26],#16
	
	; SAVE IP 

	SUB		X15, X0, #2
	 
step_in_runz: ; take more steps

	ADRP	X8, step_limit@PAGE	
	ADD		X8, X8, step_limit@PAGEOFF
	LDR     X25, [X8] ; steps to run for 
	 
step_away:
	CBZ		X15, 98f	; we finished 
	STP		LR,  XZR, [SP, #-16]!
	MOV		X29, #64

	; unrolling the loop here x16 makes this a lot faster, 
10:	; next token


	SUB     X25, X25, #1
	CBZ		X25, 80f
	LDRH	W1, [X15, #2]!
	CBZ		X1, 90f
	
	MADD	X1, X29, X1, X27
	LDP		X0, X2, [X1]
	CBZ		X2, 10b

	BLR	X2		

	; this is why we are a little slower.
	do_trace

	b		10b

80: 
	LDP		LR, XZR, [SP], #16	
	RET

90:
	SUB		X26, X26, #64
	LDP		LR, XZR, [SP], #16	
	RET

95: ; we finish so mark IP as invalid
	LDP		LR, XZR, [SP], #16
	MOV		X15, #0
98:
	SUB		X26, X26, #64
	RET

; traceable version

runintcz: ; interpret the list of tokens at word + 

	; over ride X0 to compile time token address

	LDR		X0, [X1, #32]		; compile mode tokens


runintz:; interpret the list of tokens at X0
	; until (END) #24

	trace_show_word		
	STP		XZR, XZR, [X26],#16
	STP		XZR, XZR, [X26],#16
	STP		XZR, XZR, [X26],#16
	STP		XZR, XZR, [X26],#16

	; SAVE IP 
	STP		LR,  X15, [SP, #-16]!
	SUB		X15, X0, #2
	MOV		X29, #64

	; unrolling the loop here x16 makes this a lot faster, 
10:	; next token

	.rept	16
	
		LDRH	W1, [X15, #2]!
		CBZ		X1, 90f
	 
		MADD	X1, X29, X1, X27
		LDP		X0, X2, [X1]
		CBZ		X2, 10b
	
		BLR	X2		
	
	; this is why we are a little slower.
	do_trace

	.endr

	b		10b
	
dendz:	; EXIT interpreter - called by exit

90:
	LDP		LR, X15, [SP], #16	
	SUB		X26, X26, #64
	RET



dexitz: ; EXIT
	LDP		LR, X15, [SP], #16	
	SUB		X26, X26, #64
	RET

dexitc: ; EXIT compiles end
	MOV		X0, #0 ; (EXIT)
	STRH	W0, [X15]
	SUB		X26, X26, #128
	RET


dlcmntz:	; // comment to end of line or /
dlcmntc:

	SUB		X15, X15, #2
10:	LDRB	W0, [X23], #1
	CMP		W0, #'/' 
	b.eq	990f
	CMP		W0, #10
	B.eq	990f
	CMP		W0, #12
	B.eq	990f
	CMP		W0, #13
	B.eq	990f
	CMP		W0, #0
	B.eq	990f
	ADD		W1, W1, #1
	B		10b

990:
	MOV		X0, #0
	RET


dlrbc: 
dlrbz: ; ( This is a comment that ends with .. )

	SUB		X15, X15, #2
10:	LDRB	W0, [X23], #1
	CMP		W0, #')' 
	b.eq	990f
	CMP		W0, #10
	B.eq	990f
	CMP		W0, #12
	B.eq	990f
	CMP		W0, #13
	B.eq	990f
	CMP		W0, #0
	B.eq	990f
	ADD		W1, W1, #1
	B		10b

990:
	MOV		X0, #0
	RET



drrbz: ; )
	RET

drrbc: ; )
	RET

dstarz: ; *
	B		mulz
	RET

dstarc: ; *
	RET

dcomaz: ; , compile tos into dict.
	RET

dcomac: ; , 
	RET

dsubz: ; -  subtract
	B 		subz
	RET

dsubc: ;  subtract
	RET

ddotz: ; . print tos
	B 		print
	RET

ddotc: ; 
	RET


ddivz: ; / divide
	B 		udivz
	RET

ddivc: ; 
	RET

dsdivz: ; \ divide
	B 		sdivz
	RET

dsdivc: ; 
	RET

dsmodz: ; /MOD
	LDP 	X0, X1,  [X16, #-16]  
	UDIV	X2, X0, X1
	MSUB	X3, X2, X1, X0 
	STP		X3, X2, [X16, #-16]  
	RET

dsmodc:
	RET


; break to debugger
dbreakz: 
	
	BRK #01
	RET

dbreakc: ; 
	RET


dplusz: ; +
	LDR		X0, [X16, #-8]
	LDR		X1, [X16, #-16]
	ADD		X0, X0, X1
	STR		X0, [X16, #-16]
	SUB		X16, X16, #8
	RET


dplusc: ; 
	RET

dorz: ; OR
	
	B		orz

	RET

dorc: ; 
	RET


ddropz: ;  
	SUB		X16, X16, #8
	RET

ddropc: ;	
	RET	


ztypez:
	LDR		X0, [X16, #-8] 
	B		sayit

ztypec:


ddupz: ;  
	LDR		X0, [X16, #-8] 
	STR		X0, [X16], #8
	RET
	

dqdupc: ;	
	RET	


dqdupz: ;  ?DUP 
	LDR		X0, [X16, #-8]
	CBZ		X0, 10f
	STR		X0, [X16], #8
10:	
	RET
	

ddupc: ;	
	RET	


dswapz: ;  
	LDP		X0, X1, [X16, #-16]
	STP		X1, X0, [X16, #-16]
	RET

dswapc: ;	
	RET	

drotz: ;  
	LDP		X1, X0, [X16, #-16] 
	LDR		X2, [X16, #-24]	
	STP		X0, X2, [X16, #-16]  
	STR		X1, [X16, #-24]  
	RET

drotc: ;	
	RET		


doverz: ;
	LDR		X0, [X16, #-16] 
	STR		X0, [X16], #8
	RET

doverc:	
	RET


dpickc: ;	
	
	RET	

dpickz: ;  
	LDR		X0, [X16, #-8]!
	ADD		X0, X0, #1
	NEG		X0, X0
	LDR		X1, [X16, X0, LSL #3]
	STR		X1, [X16], #8
	RET

	

dnipc: ;	
	RET	

dnipz: ;  
	
	LDP		X0, X1, [X16, #-16]  
	STR		X1, [X16, #-16]  
	SUB		X16, X16, #8
	RET


dcolonz: ; : define new word, docol
	RET

dcolonc: ;  : compile word 
	RET		

dsemiz: ; ";" semi, end word, return.
	RET

dsemic: ;  ";" semi, end word, stop compiling.
	RET		


dltz: ; "<" less than
	
lessthanz:
	LDR		X0, [X16, #-8] 
	LDR		X1, [X16, #-16]
	CMP 	X1, X0		
	B.gt	10f
	B.eq	10f
	MVN		X0, XZR ; true
	B		20f
10:
	MOV		X0, XZR
20:
	STR		X0, [X16, #-16]
	SUB		X16, X16, #8
	RET


dltc: ;  "<"  
	RET		

dequalzz:	; 0=

	LDR		X0, [X16, #-8] 
	SUB		X16, X16, #8
	CMP		X0, #0
	B.eq	10f
	MOV		X0, XZR ; true
	B		20f
10:
	MVN		X0, XZR
20:
	STR		X0, [X16], #8
	RET


dltzz:	; 0<

	LDR		X0, [X16, #-8] 
	SUB		X16, X16, #8
	CMP		X0, #0
	B.lt	10f
	MOV		X0, XZR ; true
	B		20f
10:
	MVN		X0, XZR
20:
	STR		X0, [X16], #8
	RET

dgtzz:	; 0>

	LDR		X0, [X16, #-8] 
	SUB		X16, X16, #8
	CMP		X0, #0
	B.gt	10f
	MOV		X0, XZR ; true
	B		20f
10:
	MVN		X0, XZR
20:
	STR		X0, [X16], #8
	RET


dgt1z:	; 1>

	LDR		X0, [X16, #-8] 
	SUB		X16, X16, #8
	CMP		X0, #1
	B.gt	10f
	MOV		X0, XZR ; true
	B		20f
10:
	MVN		X0, XZR
20:
	STR		X0, [X16], #8
	RET



dnoteqz:	; <>

	LDR		X0, [X16, #-8] 
	LDR		X1, [X16, #-16]
	CMP 	X0, X1		
	B.eq	10f
	MVN		X0, XZR ; true
	B		20f
10:
	MOV		X0, XZR
20:
	STR		X0, [X16, #-16]
	SUB		X16, X16, #8
	RET



dequz: ; "=" 
	
equalz:
	LDR		X0, [X16, #-8] 
	LDR		X1, [X16, #-16]
	CMP 	X0, X1		
	B.ne	10f
	MVN		X0, XZR ; true
	B		20f
10:
	MOV		X0, XZR
20:
	STR		X0, [X16, #-16]
	SUB		X16, X16, #8
	RET


dequc: ;  "="  
	RET		

dgtz: ; ">" greater than

greaterthanz:
	LDR		X0, [X16, #-8] 
	LDR		X1, [X16, #-16]
	CMP 	X1, X0		
	B.lt	10f
	B.eq	10f
	MVN		X0, XZR ; true
	B		20f
10:
	MOV		X0, XZR
20:
	STR		X0, [X16, #-16]
	SUB		X16, X16, #8
	RET		


dgtc: ;  ">"  
	RET		


dinvertz:	; INVERT

	LDR		X0, [X16, #-8] 
	SUB		X16, X16, #8
	MVN		X0, X0
	STR		X0, [X16], #8
	RET


dqmz: ; "?"  print variable e.g. AT .

	LDR		X0, [X16, #-8] 
	SUB		X16, X16, #8
	LDR		X0, [X0]
	B		X0print



	RET

dqmc: ;  "?"  
	RET		

datz: ; "@" at - fetch 
	B		atz
 

dhatc: ;  "@"  
	RET		

dhatz: ; "@" at - fetch 
	B		hwatz
 

datc: ;  "@"  
	RET		

	
atz: ;  ( address -- n ) fetch var.
	LDR		X0, [X16, #-8] 
	CBZ		X0, itsnull
	LDR		X0, [X0]
	STR		X0, [X16, #-8]
	RET

itsnull: ; error word_desc13
	MOV		X0, #0
	STR		X0, [X16, #-8]
	ADRP	X0, word_desc13@PAGE		
	ADD		X0, X0, word_desc13@PAGEOFF
	B		sayit


itsnull2: ; error word_desc13
	SUB		X16, X16, #16
	ADRP	X0, word_desc13@PAGE		
	ADD		X0, X0, word_desc13@PAGEOFF
	B		sayit

storz:  ; ( n address -- )
	LDR		X0, [X16, #-8] 
	LDR		X1, [X16, #-16]
	CBZ		X0, itsnull2
	STR		X1, [X0]
	SUB		X16, X16, #16
	RET


hwatz: ;  ( address -- n ) fetch var.
	LDR		X0, [X16, #-8] 
	CBZ		X0, itsnull
	LDRH	W0, [X0]
	STR		X0, [X16, #-8]
	RET

hwstorz:  ; ( n address -- )
	LDR		X0, [X16, #-8] 
	LDR		X1, [X16, #-16]
	CBZ		X0, itsnull2
	STRH	W1, [X0]
	SUB		X16, X16, #16
	RET


catz: ;  ( address -- n ) fetch var.
	LDR		X0, [X16, #-8] 
	CBZ		X0, itsnull
	LDRB	W0, [X0]
	STR		X0, [X16, #-8]
	RET

cstorz:  ; ( n address -- )
	LDR		X0, [X16, #-8] 
	LDR		X1, [X16, #-16]
	CBZ		X0, itsnull2
	STRB	W1, [X0]
	SUB		X16, X16, #16
	RET


nsubz:	;
	LDR		X1, [X16, #-8]
	SUB		X1, X1, X0
	STR		X1, [X16, #-8]
	RET

dnsubz:	
	B		nsubz


dnsubc:	
	RET	


doneminusz: 
	LDR		X0, [X16, #-8]
	SUB		X0, X0, #1
	STR		X0, [X16, #-8]
	RET
 
dotwominusz:
	LDR		X0, [X16, #-8]
	SUB		X0, X0, #2
	STR		X0, [X16, #-8]
	RET
 


nplusz:	;
	LDR		X1, [X16, #-8]
	ADD		X1, X1, X0
	STR		X1, [X16, #-8]
	RET

dnplusz:
	B		nplusz


dnplusc:
	RET	


nmulz:	; perform shift left to multiply
	LDR		X1, [X16, #-8]
	LSL		X0, X1, X0
	STR		X0, [X16, #-8]
	RET

dnmulz:
	B		nmulz


dnmulc:
	RET	
	

ndivz:	; perform shift right to divide
	LDR		X1, [X16, #-8]
	LSR		X1, X1, X0
	STR		X1, [X16, #-8]
	RET

dndivz:
	B		ndivz

dndivc:
	RET

tentimez:
	LDR		X1, [X16, #-8]
	LSL		X0, X1, #1
	ADD		X0, X0, X1, LSL#3
	STR		X0, [X16, #-8]
	RET

tendivz:
	LDR		X1, [X16, #-8]
	MOV		X0, #205
	MUL		X0, X1, X0
	LSR     X0, X0, #11
	STR		X0, [X16, #-8]
	RET



longlitit: ; COMPILE X0 into word as short or long lit

	; X0 is our literal 

	; halfword numbers ~32k
	MOV		X3, #4000
	LSL		X3, X3, #3  
	MOV		X1, x0
	CMP		X0, X3 
	B.gt	25f  ; too big to be

	MOV		X0, #1 ; #LITS
	STRH	W0, [X15]
	ADD		X15, X15, #2
	STRH	W1, [X15]	; value

	; short literal done
 
	RET

25:	; long word
	; we need to find or create this in the literal pool.


	ADRP	X1, quadlits@PAGE	
	ADD		X1, X1, quadlits@PAGEOFF
	MOV		X3, XZR

10:
	LDR		X2, [X1]
	CMP		X2, X0
	B.eq	80f

	CMP		X2, #-1  
	B.eq	70f
	CMP		X2, #-2 ; end of pool ERROR  
	B.eq	exit_compiler_pool_full
	ADD		X3, X3, #1
	ADD		X1, X1, #8
	B		10b	
70:
	; literal not present 
	; free slot found, store lit and return value

	STR		X0, [X1]
	MOV		X0, #2 ; #LITL
	STRH	W0, [X15]
	ADD		X15, X15, #2
	STRH	W3, [X15]	; value = index

	; long literal created and stored
	RET


80:
	; found the literal
	MOV		X0, #2 ; #LITL
	STRH	W0, [X15]
	ADD		X15, X15, #2
	MOV		X1, X3
	STRH	W1, [X15]	; value = index
	LDP		LR, X0, [SP], #16
	RET


stackit: ; push x0 to stack.

	STR		X0, [X16], #8
	RET

dvaraddz: ; address of variable
	STR		X0, [X16], #8
	RET

dvaraddc: ; compile address of variable
	RET


dconsz: ; value of constant
	STR		X0, [X16], #8
	RET

dconsc: ; compile address of variable
	RET


dlitz: ; next cell has address of short (half word) inline literal
	
	CBZ		X6, dlitz_notrace
	STP		LR,  X0, [SP, #-16]!
	do_trace
	LDP		LR, X0, [SP], #16	

dlitz_notrace:
	
	ADD		X15, X15, #2		
	LDRH	W0, [X15]

	B		stackit 

dlitc: ; compile address of variable
	RET


dlitlz: ; next cell has address of quad literal, held in pool
	
	ADD		X15, X15, #2	
	LDRH	W0, [X15] 
 
	ADRP	X1, quadlits@PAGE	
	ADD		X1, X1, quadlits@PAGEOFF
	LDR		X0, [X1, X0, LSL #3]
	B		stackit 

dlitlc: ; compile address of variable
	RET


	; literal pool lookup
	; literal on stack, find or add it to LITERAL pool.

dfindlitz:

	LDR		X0, [X16, #-8] 

	ADRP	X1, quadlits@PAGE	
	ADD		X1, X1, quadlits@PAGEOFF
	MOV		X3, XZR

10:
	LDR		X2, [X1]
	CMP		X2, X0
	B.eq	80f
	CMP		X2, #-1  
	B.eq	70f
	CMP		X2, #-2 ; end of pool ERROR  
	B.eq	85f
	ADD		X3, X3, #1
	ADD		X1, X1, #8
	B		10b	
70:
	; literal not present 
	; free slot found, store lit and return value
	STR		X0, [X1]
	MOV		X0, X3
	B		stackit

80:
	; found the literal
	MOV		X0, X3
	B		stackit


85:	; error pool full

	; reset stack
	reset_data_stack
	; report error
	B		sayerrpoolfullquad

90:	
	RET

dfindlitc:
	RET


dconstz: ; value of constant
	LDR		X0, [X1]
	STR		X0, [X16], #8
	RET


dconstc: ; value of constant
	STR		X0, [X16], #8
	RET


diloopz: ; special I loop variable
	LDP		X0, X1,  [X14, #-16]
	LDP		X2, XZR, [X14, #-32]	
	B		loop_var_check	

djloopz: ; special J loop variable

	LDP		X0, X1,  [X14, #-48]
	LDP		X2, XZR, [X14, #-64]	
	B		loop_var_check	


dkloopz: ; special K loop variable

	LDP		X0, X1,  [X14, #-80]
	LDP		X2, XZR, [X14, #-96]	
	B		loop_var_check	

loop_var_check:	
	
	CMP		X2, #21 ; DOOER
	B.eq	stack_loop_var
	CMP		X2, #22 ; DOWNDOER
	B.eq	stack_loop_var

	B.ne	loop_index_err
 

stack_loop_var:	
	MOV		X0, X1
	B		stackit
	RET

 
loop_index_err:
	reset_return_stack
	LDP		LR, X15, [SP], #16	; unstack word
	ADRP	X0, tcomer17@PAGE	
	ADD		X0, X0, tcomer17@PAGEOFF
	B		sayit
		
	RET


diloopc: ; special I loop variable
	RET

djloopc: ; special J loop variable
	RET

dkloopc: ; special K loop variable
	RET


; stack display

ddotrz:
	STP		LR,  X15, [SP, #-16]!
	MOV		X15, X14


	MOV		X0, #'R'
	BL		X0emit
	MOV		X0, #' '
	BL		X0emit

ddotdisp:
 
	LDR		X0, [X15, #-8]
	BL		X0halfpr

 
	LDR		X0, [X15, #-16]
	BL		X0halfpr

 
	LDR		X0, [X15, #-24]
	BL		X0halfpr


	LDP		LR, X15, [SP], #16	
	RET


ddotsz:
	STP		LR,  X15, [SP, #-16]!
	MOV		X15, X16
	MOV		X0, #'S'
	BL		X0emit
	MOV		X0, #' '
	BL		X0emit
	B 		ddotdisp



;; STRINGS ASCII ZERO terminated

; executes .' using an inline literal lookup.


; hash is used to look up literal strings.
; I have to suspect that collisions might occur..
; if there are enough string literals defined.

.macro short_string_hash

200:	; short string hash

	MOV		X22, X8
	MOV		W7, #53					
	MOV		X8, #51721
	MOVK	X8, #15258, LSL #16		
	MOV		W1, 	#0					
	MOV		W2, #1					

205:
	LDRB	W0, [X22], #1
	CBZ		W0,  208f

	ADD		W0, W0, #1
	MUL		W3, W2, W0
	ADD		W1, W1, W3
	MUL		W2, W2, W7
	SDIV	W4, W2, W8
	ADD		W1, W1, W4
	ADD		X22, X22, #1
	B		205b

	MOV		X2, X1


208:	
.endm


.macro	short_hash_find_free
	ADRP	X8, short_strings_hash@PAGE		
	ADD		X13, X8, short_strings_hash@PAGEOFF
	
	MOV		X3, #0	; position in table		
	
210:
	LDR		X0, 	[X13, X3, LSL#3]
	CBZ		X0, 220f
	CMP		X2, X0  ; is this our hash? 2 not 0
	B.eq	800f	; already in table
	ADD		X3, X3, #1
	B		210b

220: 	; found free slot at x3

.endm

.macro clear_string_buffer
	; clear target space
	ADRP	X8, string_buffer@PAGE		
	ADD		X8, X8, string_buffer@PAGEOFF
	MOV		X22, X8
	.rept	64
		STP		XZR, XZR, [X22], #16
	.endr

	MOV		X22, X8	
.endm


; run time .'  for interpreter only

dstrdotz:

	do_trace

	STP		LR,  XZR, [SP, #-16]!
	
	clear_string_buffer

	MOV		W1, #0

10:	LDRB	W0, [X23], #1
	CMP		W0, #39 ; '
	b.eq	200f
	CMP		W0, #10
	B.eq	990f
	CMP		W0, #12
	B.eq	990f
	CMP		W0, #13
	B.eq	990f
	CMP		W0, #0
	B.eq	990f

30:	STRB	W0, [X22], #1
	ADD		W1, W1, #1
	
	B.ne	10b

	CMP		W1, #255		; count
	B.lt	200f
	
	MOV		W3, #0

	B		770f		; string too long



	short_string_hash
	short_hash_find_free

	STR		X2, [X13, X3, LSL#3]		; store hash


	MOV		X0, X3
	LSL		X0, X0, #6

	ADRP	X8, string_buffer@PAGE		
	ADD		X8, X8, string_buffer@PAGEOFF
	MOV		X22, X8

	ADRP	X8, short_strings@PAGE		
	ADD		X13, X8, short_strings@PAGEOFF
	ADD		X13, X13, X0 ; string base + n * 64
	MOV		X2,  X13

	; copy from string buffer to string
	.rept 16
		LDP		X0, X1, [X22], #16
		STP		X0, X1, [X13], #16
	.endr

	MOV		X0, X2
	BL		sayit


770:	; err string too long.

	MOV		X0, #-1	
	LDP		LR, X15, [SP], #16	
	;; TODO
	
	RET


780:	; hash table full
	MOV		X0, #-1	
	LDP		LR, X15, [SP], #16	
	;; TODO

	RET


800:	; normal exit
	
	LDP		LR, X15, [SP], #16	
	
	RET



dstrstksz: ; runtime S" .. " stash and return address


	do_trace

	STP		LR,  XZR, [SP, #-16]!
	
	clear_string_buffer

	MOV		W1, #0

10:	LDRB	W0, [X23], #1
	CMP		W0, #39 ; '
	b.eq	200f
	STRB	W0, [X22], #1
	ADD		W1, W1, #1
	B.ne	10b


200:

	; short string hash

	MOV		X22, X8
	MOV		W7, #53					
	MOV		X8, #51721
	MOVK	X8, #15258, LSL #16		
	MOV		W1, #0					
	MOV		W2, #1					

205:
	LDRB	W0, [X22], #1
	CBZ		W0,  208f

	ADD		W0, W0, #1
	MUL		W3, W2, W0
	ADD		W1, W1, W3
	MUL		W2, W2, W7
	SDIV	W4, W2, W8
	ADD		W1, W1, W4
	ADD		X22, X22, #1
	B		205b

208:	
	MOV		X2, X1 ; X2 = HASH

	ADRP	X8, short_strings_hash@PAGE		
	ADD		X13, X8, short_strings_hash@PAGEOFF
	
	MOV		X3, #0	; position in table		
	
210:
	LDR		X0, [X13, X3, LSL#3]
	CBZ		X0, 220f
	CMP		X2, X0  ; is this our hash? 2 not 0
	B.eq	800f	; already in table
	ADD		X3, X3, #1
	B		210b

220:	
	STR		X2, [X13, X3, LSL#3]		; store hash

	MOV		X0, X3
	LSL		X0, X0, #6

	ADRP	X8, string_buffer@PAGE		
	ADD		X8, X8, string_buffer@PAGEOFF
	MOV		X22, X8

	ADRP	X8, short_strings@PAGE		
	ADD		X13, X8, short_strings@PAGEOFF
	ADD		X13, X13, X0 ; string base + n * 64
	MOV		X2,  X13

	; copy from string buffer to string
	.rept 16
		LDP		X0, X1, [X22], #16
		STP		X0, X1, [X13], #16
	.endr
	
	LDP		LR, X15, [SP], #16	
	MOV		X0, X2
	B 		stackit


800: 	; already in table

	MOV		X0, X3
	LSL		X0, X0, #6

	ADRP	X8, string_buffer@PAGE		
	ADD		X8, X8, string_buffer@PAGEOFF
	MOV		X22, X8

	ADRP	X8, short_strings@PAGE		
	ADD		X13, X8, short_strings@PAGEOFF
	ADD		X13, X13, X0 ; string base + n * 64
	MOV		X0,  X13

	LDP		LR, X15, [SP], #16	
	B 		stackit


770:	; err string too long.

	MOV		X0, #-1	

	LDP		LR, X15, [SP], #16	
	B 		stackit
	;; TODO
	
	RET


780:	; hash table full
	MOV		X0, #-2
	LDP		LR, X15, [SP], #16	
	B 		stackit
	;; TODO

	RET







; compiles string into the string literal pool.
; compiles string literal token and value into word.
dstrdotc:

	STP		LR,  XZR, [SP, #-16]!
	
	clear_string_buffer

	MOV		W1, #0

10:	LDRB	W0, [X23], #1
	CMP		W0, #39 ; '
	b.eq	200f
	CMP		W0, #10
	B.eq	990f
	CMP		W0, #12
	B.eq	990f
	CMP		W0, #13
	B.eq	990f
	CMP		W0, #0
	B.eq	990f

30:	STRB	W0, [X22], #1
	ADD		W1, W1, #1
	
	B.ne	10b

	CMP		W1, #255		; count
	B.lt	200f
	
	MOV		W3, #0

	B		880f		; string too long

	
	short_string_hash
	short_hash_find_free

	STR		X2, [X13, X3, LSL#3]		; store hash


	MOV		X0, X3
	LSL		X0, X0, #6

	ADRP	X8, string_buffer@PAGE		
	ADD		X8, X8, string_buffer@PAGEOFF
	MOV		X22, X8

	ADRP	X8, short_strings@PAGE		
	ADD		X13, X8, short_strings@PAGEOFF
	ADD		X13, X13, X0 ; string base + n * 64

	; copy from string buffer to string
	.rept 16
		LDP		X0, X1, [X22], #16
		STP		X0, X1, [X13], #16
	.endr
	B		800f


300:	; long string


800:	; end no error
	MOV		W0, #12 ; (.S)
	STRH	W0, [X15], #2
	ADD		W3, W3, #32 ; avoid confusion.
	STRH	W3, [X15]
	B		990f

880:	; string too long
	MOV		X0, #-1	
	LDP		LR, XZR, [SP], #16	
	RET


980:	; hash table full
	MOV		X0, #-1	
	LDP		LR, XZR, [SP], #16	
	RET

990:	
	MOV		X0, #0
	LDP		LR, XZR, [SP], #16	
	RET



dstrstksc: ; compile literal that returns its address.


	do_trace

	STP		LR,  XZR, [SP, #-16]!
	
	clear_string_buffer

	MOV		W1, #0

10:	LDRB	W0, [X23], #1
	CMP		W0, #39 ; '
	b.eq	200f
	STRB	W0, [X22], #1
	ADD		W1, W1, #1
	B.ne	10b


200:

	; short string hash

	MOV		X22, X8
	MOV		W7, #53					
	MOV		X8, #51721
	MOVK	X8, #15258, LSL #16		
	MOV		W1, #0					
	MOV		W2, #1					

205:
	LDRB	W0, [X22], #1
	CBZ		W0,  208f

	ADD		W0, W0, #1
	MUL		W3, W2, W0
	ADD		W1, W1, W3
	MUL		W2, W2, W7
	SDIV	W4, W2, W8
	ADD		W1, W1, W4
	ADD		X22, X22, #1
	B		205b



208:	
	MOV		X2, X1 ; X2 = HASH

	ADRP	X8, short_strings_hash@PAGE		
	ADD		X13, X8, short_strings_hash@PAGEOFF
	
	MOV		X3, #0	; position in table		
	
210:
	LDR		X0, [X13, X3, LSL#3]
	CBZ		X0, 220f
	CMP		X2, X0  ; is this our hash? 2 not 0
	B.eq	800f	; already in table
	ADD		X3, X3, #1
	B		210b


220:	
	STR		X2, [X13, X3, LSL#3]		; store hash

	MOV		X0, X3
	LSL		X0, X0, #6

	ADRP	X8, string_buffer@PAGE		
	ADD		X8, X8, string_buffer@PAGEOFF
	MOV		X22, X8

	ADRP	X8, short_strings@PAGE		
	ADD		X13, X8, short_strings@PAGEOFF
	ADD		X13, X13, X0 ; string base + n * 64
	MOV		X2,  X13

	; copy from string buffer to string
	.rept 16
		LDP		X0, X1, [X22], #16
		STP		X0, X1, [X13], #16
	.endr
	
	MOV		X0, X2
	BL		longlitit
	LDP		LR, XZR, [SP], #16	
	RET

800: 	; already in table

	MOV		X0, X3
	LSL		X0, X0, #6

	ADRP	X8, string_buffer@PAGE		
	ADD		X8, X8, string_buffer@PAGEOFF
	MOV		X22, X8

	ADRP	X8, short_strings@PAGE		
	ADD		X13, X8, short_strings@PAGEOFF
	ADD		X13, X13, X0 ; string base + n * 64
	MOV		X0,  X13
	BL 		longlitit
	LDP		LR, XZR, [SP], #16	
	RET


770:	; err string too long.

	MOV		X0, #-1	

	BL 		longlitit
	LDP		LR, XZR, [SP], #16	
	RET


780:	; hash table full
	MOV		X0, #-2
	BL 		longlitit
	LDP		LR, XZR, [SP], #16	
	RET



; print a short literal string, inline literal
dslitSzdot: 
	
	STP		LR,  X12, [SP, #-16]!
	STP		X0,  X8, [SP, #-16]!

	ADRP	X8, short_strings@PAGE		
	ADD		X12, X8, short_strings@PAGEOFF

	ADD		X15, X15, #2		
	LDRH	W0, [X15]
	SUB		W0, W0, #32 ; avoid confusion
 
	LSL		X0, X0, #6
	ADD		X0, X0, X12

	BL		sayit
	
	LDP		X0, X8, [SP], #16
	LDP		LR, X12, [SP], #16

	RET

; fetch address of a short literal string, inline literal
dslitSz:
	ADRP	X8, short_strings@PAGE		
	ADD		X12, X8, short_strings@PAGEOFF
	ADD		X15, X15, #2		
	LDRH	W0, [X15]
	SUB		W0, W0, #32 ; avoid confusion
	LSL		X0, X0, #6
	ADD		X0, X0, X12
	B		stackit
	;
	RET


; fetch address of long literal string, inline literal
dslitLz:
	RET


dhashbufferz:
 
	ADRP	X8, string_buffer@PAGE		
	ADD		X8, X8, string_buffer@PAGEOFF
	MOV		X12, X8

	MOV		W7, #53					
	MOV		X8, #51721
	MOVK	X8, #15258, LSL #16		
	MOV		W1, 	#0					
	MOV		W2, #1					

10:	LDRB	W0, [X12], #1
	CBZ		W0,  90f

	ADD		W0, W0, #1
	MUL		W3, W2, W0
	ADD		W1, 	W1, W3
	MUL		W2, W2, W7
	SDIV	W4, W2, W8
	ADD		W1, W1, W4
	ADD		X12, X12, #1
	B		10b
	
90:	STR		X1, [X16], #8
	RET



dlsbz:  ; [ 
	RET
	

dlsbc:  ; [
	RET

dshlashz:  ; \
	RET
	
dshlashc:  ; \
	RET

drsbz:  ; ]
	RET
	
drsbc:  ; ]
	RET

dabsz:  ; ABS

	LDR		X0, [X16, #-8]
	CMP		X0,  #1
	CSNEG	X0, X0, X0, pl	
	STR		X0, [X16, #-8]
	RET
	

dabsc:  ; 
	RET



dtophatz:  ; 
	RET
	

dtophatc:  ; 
	RET


dunderscorez:  ; 
	RET
	

dunderscorec:  ; 
	RET


dbacktkz:  ; 
	RET
	

dbacktkc:  ;	
	RET

dlcbz: ;  {	lcb
	RET

dlcbc: ;  {	lcb
	RET



dpipez: ; |  pipe
	B	orz
	RET


dpipec: ; |  pipe
	RET


drcbz: ;  }	rcb
	RET

drcbc: ;  }  rcb
	RET

dtildez: ;  ~  tilde
	RET

dtildec: ;  ~  tilde
	RET


ddelz:	; del (127)
	RET

ddelc:	; del (127)
	RET

.data 

; variables
.align 8 
last_word:	
	.quad	-1		; last_word word being updated.
	.quad	0
	.quad	0


.data

.align 8
 

dpage: .zero 4
zstdin: .zero 16

;; text literals

.align 8
literal_name:
.ascii  "<- literal"
	.zero 16

.align 8

tok:	.ascii  "\nOk\n"
	.zero 16

.align	8
tbye:	.ascii "\nBye..\n"
	.zero 16


.align	8
texit:	.ascii "Exit no more input.."
	.zero 16

.align	8
tlong:	.ascii "Word too long.."
	.zero 16

.align 8
poolfullerr:
	.ascii "Error pool full."
	.zero 16

.align	8
tcr:	.ascii "\r\n"
	.zero 16

.align	8
tlbr:	.ascii "["
	.zero 16

.align	8
trbr:	.ascii "]"
	.zero 16

.align	8
tdec:	.ascii "%3ld"
	.zero 16

.align	8
thex:	.ascii "%8X"
	.zero 16

.align	8
tpradd:	.ascii "%8ld "
	.zero 16


.align	8
tpraddln:	.ascii "\n%8ld "
	.zero 16


.align	8
tpradIP:	.ascii " IP[%8ld] "
	.zero 16



.align	8
thalfpr:	.ascii ": [%6ld] "
	.zero 16


.align	8
tbranchpr:	.ascii "={%4ld} "
	.zero 16

.align	8
tprname:	.ascii "%-12s"
	.zero 16

.align	8
tovflr:	.ascii "\nstack over-flow"
	.zero 16

.align	8
tunder:	.ascii "\nstack under-flow"
	.zero 16

.align	8
texists:	.ascii " <-- Word Exists"
	.zero 16

.align	8
tcomer1: .ascii "\nCompiler error ':' expects a word to define."
	.zero 16

.align	8
tcomer3: .ascii "\nCompiler error  "
	.zero 16

.align	8
tcomer4: .ascii "<-- Word was not recognized. "
	.zero 16

.align	8
tcomer5: .ascii "Compiler error  "
	.zero 16


.align	8
tcomer6: .ascii " half word cells used, compiler Finished\n  "
	.zero 16


.align	8
tcomer7: .ascii "\nCreated Word  "
	.zero 16

.align	8
tcomer8: .ascii "\nWord is too long (words must be short.)"
	.zero 16

.align	8
tcomer9: .ascii "\nCompile time function failed"
	.zero 16

.align	8
tcomer10: .ascii "\nENDIF could not find IF.."
	.zero 16

.align	8
tcomer11: .ascii "\nENDIF could not find IF.."
	.zero 16

.align	8
tcomer12: .ascii "\nENDIF could not find IF.."
	.zero 16

.align	8
tcomer13: .ascii "\nENDIF could not find IF.."
	.zero 16


	.align	8
tcomer14: .ascii "\nDO .. LOOP - LOOP could not find DO.."
	.zero 16

	.align	8
tcomer15: .ascii "\nDO .. LOOP - +LOOP could not find DO.."
	.zero 16


	.align	8
tcomer16: .ascii "\nDO .. LOOP - DO could not find LOOP.."
	.zero 16


	.align	8
tcomer17: .ascii "\nDO .. LOOP - LOOP index error.."
	.zero 16

	.align	8
tcomer18: .ascii "\nDO .. LOOP error.."
	.zero 16

	.align	8
tcomer19: .ascii ": END OF LIST\n "
	.zero 16

	.align	8
tliteral: .ascii " Literal Value"
	.zero 16

	.align	8
tcomer20: .ascii "DO .. LOOP error - DO needs two argments.\n "
	.zero 16

.align	8
tcomer21: .ascii "  : ms to run ( "
	.zero 16

tcomer22: .ascii "  ) ns \n "
	.zero 16


.align	8
tcomer23: .ascii "BEGIN .. AGAIN error - AGAIN/UNTIL needs BEGIN.\n "
	.zero 16

.align	8
tcomer24: .ascii "BEGIN .. WHILE REPEAT error - MISSING WHILE.\n "
	.zero 16

.align	8
tcomer25: .ascii "BEGIN .. WHILE REPEAT error - MISSING BEGIN.\n "
	.zero 16


.align	8
tcomer30: .ascii "Error: BEGIN or DO loops are not terminated "
	.zero 16



.align	8
tforget: .ascii "\nForgeting last_word word: "
	.zero 16




.align	8
word_desc1: .ascii "\t\tCONSTANT "
	.zero 16


.align	8
word_desc2: .ascii "\t\tVARIABLE "
	.zero 16



.align	8
word_desc3: .ascii "\t\tPRIM RUN"
	.zero 16

.align	8
word_desc4: .ascii "\t\tTOKEN COMPILED TRACEABLE"
	.zero 16

.align	8
word_desc4_1: .ascii "\t\tTOKEN COMPILED FAST"
	.zero 16

.align	8
word_desc5: .ascii "\t\tNAME"
	.zero 16


.align	8
word_desc6: .ascii "\t\tTOKENS"
	.zero 16

.align	8
word_desc7: .ascii "\t\tVALUE "
	.zero 16

.align	8
word_desc8: .ascii "\t\t^VALUE "
	.zero 16


.align	8
word_desc9: .ascii "\t\t^TOKENS "
	.zero 16


.align	8
word_desc10: .ascii "\t\tARGUMENT 1"
	.zero 16

.align	8
word_desc10_1: .ascii "\t\tARGUMENT 2"
	.zero 16

.align	8
word_desc10_2: .ascii "\t\tExtra DATA 1"
	.zero 16

.align	8
word_desc10_3: .ascii "\t\tExtra DATA 2"
	.zero 16



.align	8
word_desc11: .ascii "SEE WORD :"
	.zero 16


.align	8
word_desc12: .ascii "\t\tPRIM COMP"
	.zero 16




.align	8
word_desc13: .ascii "\nError: Null access."
	.zero 16

.align 8
clear_screen:
	.byte 27,'[','2','J',27,'[','H',0


.align	8
spaces:	.ascii "										"
	.zero 16


; this is the tokens stack
; code for token compiled words is compiled into here
; 
;  
.align 8

lasthere:	
	.quad	token_space
here:
	.quad	token_space

	.zero 16


	
token_space:
	.zero	128*1024*2

token_space_top:

	.zero 16



; this is the locals stack
; words get their own 8 locals nested up to 250 levels deep
; locals are zero on entry, and exist only while a word runs.

.align  8
lsp:	 
				.zero	16*1024

.align 	8

allot_ptr:		.quad	allot_space
				.zero 	32
allot_space:	;  allotable bytes
				.zero	128*1024
allot_limit:	; allotments went too far



; this is the data stack
.align  8
sps:	.zero 8*8	
	.quad -111111; underflow patterws
	.quad -222222
	.quad -333333
	.quad -444444
	.quad -555555
	.quad -666666
	.quad -777777
	.quad -888888
	.quad -999999
	.quad 0
	.quad 0
spu:	.quad 0
sp1:	; base
	.zero 512*8
spo:	.quad 0
	.quad 0
	.quad 0
	.quad 1111111 ; overflow patterns
	.quad 2222222
	.quad 3333333
	.quad 4444444
	.quad 5555555
	.quad 6666666
	.quad 7777777
	.quad 8888888
	.quad 9999999

sp0:	.zero 8*8
dsp:	.quad sp1

; this is the return stack
; used for loop constructs and local variables.

.align  8
rps:	.zero 8*8	
rpu:	.zero 8
rp1:	.zero 512*8  
rpo:	.zero 8
rp0:	.zero 8*8
rsp:	.quad rp1

; global, single letter, integer variables
.align 16
ivars:	.zero 256*16	

	.zero	512


.align	16
step_limit: 
			.quad  5
			
step_skip:
			.quad 0


.align 16 

; if the compiler sees a long lit > 16000 it makes a long lit
; which means it has to find a free lit (-1) in the litpool, and use its index.
; as a short word in the high level threads.
;  

quadbase: .quad quadlits

quadlits:	
; long literal values for all words in dictionary

	.quad  16
	.quad  32
	.quad  128 
	.quad  256 
	.quad  512
	.quad  1024

	.rept  512	; <-- increase if literal pool full error arises.
	.quad -1
	.endr
	.quad  -2 ; end of literal pool. 
	.quad  -2 



; STRINGS ASCII
; string lits ASCII counted strings


string_buffer:
.zero 2048

 
short_strings_hash:
.rept  2048
	.quad	0
.endr
.quad	-1
.quad	-1

short_strings:
.rept  2048
	.zero	256
.endr
.quad	-1
.quad	-1



;; long strings  
long_strings_hash:
.rept  2048
	.quad	-1
.endr


long_strings:
.rept  128
	.zero	512
.endr
.quad	-1
.quad	-1


; used for line input
.align 16
zpad:	.ascii "ZPAD STARTS HERE"
	.zero 1024


; the word being processed
.align 8
zword: .zero 64



 .align 8
 dbye:	.ascii "BYE" 
		.zero 5
		.zero 8
		.quad 0
		.quad 0

	
		.quad 0
		.quad 0
		.quad 0
		.quad 0

dend:	

		; Dictionary WORD headers
		; each word name is 16 bytes of zero terminated ascii	
		; a pointer to the adress of the run time machine code function to call.
		; a pointer to the adress of the compile time machine code function to call.
		; a data element
		; gaps for capacity are stacked up towards 'a'  
		;  

		; the end of the list - also the beginning of the same.

		; unlike FORTH 
		; the dictionary is a single vocabulary, it is not a linked list
		; it is an array of fixed size word headers.
		; the tokenid is the index to the array.

	

		; primitive code word headings.

		; first 32 words 
		; these are placed in this order fixed forever 
		; otherwise adding words breaks the compiler.
		; the compiler references these token numbers.

		; these hash words are inline compile only
	

		; words that can take inline literals as arguments
		makeword "(END)", dexitz, 0,  0					; 0 - never runs
		makeword "(LITS)",  dlitz, dlitc,  0			; 1
		makeword "(LITL)",  dlitlz, dlitlc,  0			; 2
		makeword "(IF)", 	dzbranchz, 0,  0			; 3
		makeword "(ELSE)", dbranchz, 0,  0				; 4
		makeword "(5)", 0, 0,  0						; 5
		makeword "(6)", 0, 0,  0						; 6
		makeword "(7)", 0, 0,  0						; 7
		makeword "(8)", 0, 0,  0						; 8
		makeword "(WHILE)", dwhilez, 0,  0				; 9
		makeword "($S)",  dslitSz, 0,  0				; 10
		makeword "($L)",  dslitLz, 0,  0				; 11
		makeword "(.')", dslitSzdot, 0,  0				; 12
		makeword "(LEAVE)", dleavez, 0,  0				; 13
		makeword "(14)", 0, 0,  0						; 14
		makeword "(15)", 0, 0,  0						; 15

		; other fixed position tokens
		makeword "(16)", 0, 0,  0						; 16
		makeword "(+LOOP)", 	dplooperz, 	0,  0		; 17
		makeword "(-LOOP)", 	dmlooperz, 	0,  0		; 18
		makeword "(LOOP)", 		dlooperz, 	0,  0		; 19
		makeword "(20)", 		0, 	0,  0				; 20
		makeword "(DOER)", 		ddoerz, 	0,  0		; 21
		makeword "(DOWNDOER)", 	ddowndoerz, 0 , 0		; 22
		makeword "(DO)", 		stckdoargsz, 0 , 0		; 23
		makeword "(END)", 		dendz, 0 , 0			; 24
		makeword "(DOCOL)",		0, 	0,  0				; 25
		makeword "(26)", 		0, 	0,  0				; 26
		makeword "(27)", 		0, 	0,  0				; 27
		makeword "(28)", 		0, 	0,  0				; 28
		makeword "(29)", 		0, 	0,  0				; 29
		makeword "(30)", 		0, 	0,  0				; 30
		makeword "(31)", 		0, 	0,  0				; 31

		; just words starting with (
		makeword "(", 			dlrbz, dlrbc, 	0		; ( comment

		makeemptywords 84


hashdict:	

		; end of inline compiled words, relax

		makeemptywords 84

		makeword "ALLWORDS", alldotwords , 0, 0 

		makeword "ALLOT", allotz , 0, 0 

		makeword "ADDR" , daddrz, daddrc, 0


		makeword "AGAIN" , dagainz, dagainc, 0

		makeword "ABS" , dabsz, dabsc, 0

		makeword "AND" , dandz, 0, 0

		makeqvword 97
		makeword "A", dvaraddz, dvaraddc,  8 * 65 + ivars	
	
	
adict:

		makeemptywords 84

		makeword "BEGIN" , dbeginz, dbeginc, 0
		makeword "BUFFER$", dvaraddz, dvaraddc,  string_buffer
		makeword "BREAK",  dbreakz, dbreakc, 0
		makeword "BL",  dconstz, dconstz, 32
		
		makeqvword 98
		makeword "B", dvaraddz, dvaraddc,  8 * 66 + ivars	

bdict:
		makeemptywords 80
		makeword "CHAR", 	dcharz, dcharc, 0
		makeword "C@", 		catz, 0, 0
		makeword "C!", 		cstorz, 0, 0
		makeword "CONSTANT", dcreatcz , dcreatcc, 0
		makeword "CREATE", 	dcreatz, dcreatc, 0
		makeword "CALL", 	dcallz, dcallc, 0
		makeword "CR", 		saycr, 0, 0
		makeqvword 99
		makeword "C", 		dvaraddz, dvaraddc,  8 * 67 + ivars	

cdict:
		makeemptywords 80

	
		makeword "DP", dvaraddz, dvaraddc,  here	
		makeword "DO", 0 , doerc, 0 
		makeword "DOWNDO", 0 , ddownerc, 0 
		makeword "DUP", ddupz , 0, 0 
		makeword "DROP", ddropz , 0, 0		
		makeword "DEPTH", ddepthz , 0, 0 

		makeqvword 100
		makeword "D", dvaraddz, dvaraddc,  8 * 68 + ivars	

ddict:
		makeemptywords 80
		makeword "ELSE", 0 , delsec, 0 
		makeword "ENDIF", 0 , dendifc, 0 
		makeword "EMIT", emitz , 0, 0 
		makeword "EXIT", dexitz, 	0,  0			
		
		makeqvword 101
		makeword "E", dvaraddz, dvaraddc,  8 * 69 + ivars	

edict:
		makeemptywords 48
		
		makeqvword 102

		makeword "FFIB", dtstfib, 0,  0
		makeword "FASTER", duntracable, 0, 0
		makeword "FALSE", dconstz, dconstc,  0
		makeword "FORGET", clean_last_word , 0, 0 
		makeword "F", dvaraddz, dvaraddc,  8 * 70 + ivars	
		makeword "FINDLIT", dfindlitz, dfindlitc,  0

fdict:	
		makeemptywords 79
		makeqvword 103
		makeword "G", dvaraddz, dvaraddc,  8 * 71 + ivars	
gdict:
		makeemptywords 78

		makeword "HW!", dhstorez, dhstorec,  0

		makeword "HW@", dhatz, dhatc, 0


		makeqvword 104
		makeword "HASHBUFFER$", dhashbufferz, 0,  0
		makeword "H", dvaraddz, dvaraddc,  8 * 72 + ivars	
hdict:
	
		makeemptywords 66
		makeqvword 105
		makeword "I", diloopz, diloopc,  0
		makeword "IF", difz, difc,  0
		makeword "INVERT", dinvertz, 0,  0

idict:
		makeemptywords 66
		makeqvword 106
		makeword "J", djloopz, djloopc,  0

jdict:
		makeemptywords 64
		makeword "KLAST", get_last_word, 0,  0
		makeqvword 107
		makeword "K", dkloopz, dkloopc,  0
	
kdict:
		makeemptywords 64
		
	
		makeqvword 108


		makeword "LEAVE", 0 , dleavec, 0 

		makeword "LOOP", 0 , dloopc, 0 

		makeword "LIMIT", dlimited , 0, 0 

		makeword "L", dvaraddz, dvaraddc,  8 * 76 + ivars	
	
		makeword "LONG$", dvaraddz, dvaraddc,  long_strings

		makeword "LITBASE", dvaraddz, dvaraddc,  quadlits

	
ldict:
		makeemptywords 61

	
		makeword "MOD", dmodz, dmodc, 0	

		makeemptywords 68

		makeqvword 109
		makeword "M", dvaraddz, dvaraddc,  8 * 77 + ivars	
mdict:
		makeemptywords 64


		makeword "NTH", dnthz, dnthc, 0	

		makeword "NIP", dnipz, dnipc, 0	

		makeqvword 110
		makeword "N", dvaraddz, dvaraddc,  8 * 78 + ivars	

ndict:	
		makeemptywords 62

		makeword "OR", dorz, 0, 0
		makeword "OVER", doverz, doverc, 0
		makeqvword 111
		makeword "O", dvaraddz, dvaraddc,  8 * 79 + ivars	
	
odict:
		makeemptywords 62
 
		makeword "PAGE", dpagez, 0, 0
		makevarword "PAD", zpad

		makeword "PRINT", print, 0, 0

		makeword "PICK", dpickz, dpickc, 0

		makeqvword 112
		makeword "P", dvaraddz, dvaraddc,  8 * 80 + ivars	


pdict:
		makeemptywords 62
		makeqvword 113
		makeword "Q", dvaraddz, dvaraddc,  8 * 81 + ivars	

qdict:
		makeemptywords 50

		makeword "REPRINT", reprintz , reprintc, 0 
		makeword "REPEAT", drepeatz , drepeatc, 0 
	

		makeword "ROT", drotz , drotc, 0 

		makeword "R>", dfromrz , dfromrc, 0 
		makeword "R@", dratz , 0, 0 
		makeword "RP@", fetchrpz , 0, 0 

		makeqvword 114
		makeword "R", dvaraddz, dvaraddc,  8 * 82 + ivars	

rdict:

		makeemptywords 50
		makeword "S'", dstrstksz , dstrstksc, 0 
		makeword "STEPOUT", stepoutz , 0, 0 
	 	makeword "STEP", step_in_runz , 0, 0 
		makevarword "STEPPING", step_limit
		makevarword "STEPS", step_skip
		makeword "SHORT$HASH", dvaraddz, dvaraddc,  short_strings_hash
		makeword "SHORT$", dvaraddz, dvaraddc,  short_strings
		makeword "SWAP", dswapz , 0, 0 
		makeword "SLEEP", dsleepz , 0, 0 
		makeword "SPACES", spacesz , spacesc, 0 
		makeword "SPACE", emitchz , emitchc, 32
	 	makeword "SP@", fetchspz , 0, 0 
		makevarword "SP", dsp
		makeword "SEE", dseez , 0, 0 

		makeqvword 115 
		makeword "S", dvaraddz, dvaraddc,  8 * 83 + ivars	

sdict:
		makeemptywords 50
		makeword "TIMEIT", dtimeitz, 0, 0
		makeword "TRACE", dtracable, 0, 0
		makeword "TRUE", dconstz, dconstc,  -1
		makeword "TRACING?", dtraqz, 0, 0
		makeword "TICKS", dtickerz, 0, 0
		makeword "TPMS", dconstz, dconstz, 24000
		makeword "TPS",  dconstz, dconstz, 24000000
		makeword "TRON", dtronz, 0, 0
		makeword "TROFF", dtroffz, 0, 0
		makeword "TYPEZ", ztypez, ztypec, 0	
		makeword "THEN", 0 , dendifc, 0 
		makeqvword 116
		makeword "T", dvaraddz, dvaraddc,  8 * 84 + ivars	

tdict:

		makeemptywords 50
		makeqvword 117

		makeword "UNTIL", duntilz, duntilc, 0	
		makeword "U", dvaraddz, dvaraddc,  8 * 85 + ivars	
	
udict:

		makeemptywords 48
		makeword "VERSION", announce , 0, 0


		makeword "VARIABLE", dcreatvz , dcreatvc, 0

		makeqvword 118
		makeword "V", dvaraddz, dvaraddc,  8 * 86 + ivars	
	
vdict:
		makeemptywords 48

		makeword "WORDS", dotwords , 0, 0 
		makeword "WHILE", 0 , dwhilec, 0 
	
		makeqvword 119
		makeword "W", dvaraddz, dvaraddc,  8 * 87 + ivars	
		
		
wdict:

		makeemptywords 48
		
		makeqvword 120
		makeword "X", dvaraddz, dvaraddc,  8 * 88 + ivars	
xdict:
		makeemptywords 48
		
 
		makeqvword 121
		makeword "Y", dvaraddz, dvaraddc,  8 * 89 + ivars	
		

ydict:
		makeemptywords 34

		makeqvword 122
		makeword "Z", dvaraddz, dvaraddc,  8 * 90 + ivars	

zdict:

		makeemptywords 30
		makeword "*/", dstarslshz, 0,  10
		makeword "*/MOD", dstarslshzmod, 0,  10
		makeword "1-DUP1-", fibtest, 0,  10
		makeword "10", dconstz, dconstc,  10
		makeword "11", dconstz, dconstc,  11
		makeword "12", dconstz, dconstc,  12
		makeword "13", dconstz, dconstc,  13
		makeword "14", dconstz, dconstc,  14
		makeword "15", dconstz, dconstc,  15
		makeword "16", dconstz, dconstc,  16
		makeword "17", dconstz, dconstc,  17
		makeword "18", dconstz, dconstc,  18
		makeword "19", dconstz, dconstc,  19
		makeword "20", dconstz, dconstc,  20
		makeword "21", dconstz, dconstc,  21
		makeword "22", dconstz, dconstc,  22
		makeword "23", dconstz, dconstc,  23
		makeword "24", dconstz, dconstc,  24
		makeword "25", dconstz, dconstc,  25
		makeword "-1", dconstz, dconstc,  -1
		makeword "-2", dconstz, dconstc,  -2
		makeword "1+", dnplusz , 0, 1 
		makeword "2+", dnplusz , 0, 2
		makeword "4+", dnplusz , 0, 4
		makeword "1-", doneminusz , 0, 1
		makeword "2-", dotwominusz , 0, 2
		makeword "2*", dnmulz , 0, 2
		makeword "2/", dndivz , 0, 2
		makeword "4*", dnmulz , 0, 2
		makeword "4/", dndivz , 0, 2

		makeword "8-", dnsubz , 0, 8
		makeword "8+", dnplusz , 0, 8 
		makeword "8*", dnmulz , 0, 3
		makeword "8/", dndivz , 0, 3


		makeword "10*", tentimez , 0, 0
		makeword "10/", tendivz , 0, 0
		makeword "16-", dnsubz , 0, 4
		makeword "16+", dnplusz , 0, 4 
		makeword "16*", dnmulz , 0, 4
		makeword "16/", dndivz , 0, 4

		makeword "24+", dnplusz , 0, 24
		makeword "24-", dnsubz , 0, 24
		
		makeword "0=", dequalzz, 0 , 0
		makeword "0<", dltzz, 0 , 0
		makeword "0>", dgtzz, 0 , 0
		makeword "1>", dgt1z, 0 , 0
		makeword "/MOD", dsmodz , dsmodc, 0

		makeword "//", dlcmntz , dlcmntc, 0

		makeword ".VERSION", announce , 0, 0

		makeword "?DUP", dqdupz, dqdupc, 0
		makeword ">R", dtorz , dtorc, 0 
		makeword "+LOOP", 0 , dploopc, 0
		makeword "-LOOP", 0 , dmloopc, 0
		makeword ".R", ddotrz, 0 , 0
		makeword ".S", ddotsz, 0 , 0
		makeword ".'", dstrdotz, dstrdotc , 0
		makeword "<>", dnoteqz, 0 , 0
		makeword "+!", plustorz, 0 , 0

		; cheap locals
		makeword "_A@" , dlocaz, 0
		makeword "_B@" , dlocbz, 0
		makeword "_C@" , dloccz, 0
		makeword "_D@" , dlocdz, 0
		makeword "_E@" , dlocez, 0
		makeword "_F@" , dlocfz, 0
		makeword "_G@" , dlocgz, 0
		makeword "_H@" , dlochz, 0
	 
		makeword "_A!" , dlocasz, 0
		makeword "_B!" , dlocbsz, 0
		makeword "_C!" , dloccsz, 0
		makeword "_D!" , dlocdsz, 0
		makeword "_E!" , dlocesz, 0
		makeword "_F!" , dlocfsz, 0
		makeword "_G!" , dlocgsz, 0
		makeword "_H!" , dlochsz, 0

		


zbytewords:
		makeemptywords 33
		makebword 33, 	dstorez, 	dstorec, 	0
		makebword 34, 	dquotz, 	dquotc, 		0
		makebword 35, 	dhashz, 	dhashc, 		0
		makebword 36, 	ddollarz, 	0, 	0
		makebword 37, 	dmodz, 		dmodc, 		0
		makebword 38, 	dandz, 		0, 		0
		makebword 39, 	dtickz, 	dtickc, 		0
		makebword 40, 	dlrbz, 		dlrbc, 		0			; (
		makebword 41, 	0, 			0, 			0			; )
		makebword 42, 	dstarz, 		0, 		0
		makebword 43, 	dplusz, 	dplusc, 		0
		makebword 44, 	dcomaz, 	dcomac, 		0
		makebword 45, 	dsubz, 		dsubc, 		0
		makebword 46, 	ddotz, 		0, 		0
		makebword 47, 	dsdivz, 	0, 		0
		makebword 48, 	stackit, 	stackit, 	0
		makebword 49, 	stackit, 	stackit, 	1
		makebword 50, 	stackit, 	stackit, 	2
		makebword 51, 	stackit, 	stackit, 	3
		makebword 52, 	stackit, 	stackit, 	4
		makebword 53, 	stackit, 	stackit, 	5
		makebword 54, 	stackit, 	stackit, 	6
		makebword 55, 	stackit, 	stackit, 	7
		makebword 56, 	stackit, 	stackit, 	8
		makebword 57, 	stackit, 	stackit, 	9

		makebword 58, 	dcolonz, 	dcolonc, 	0
		makebword 59, 	dsemiz, 	dsemic, 		0
		makebword 60, 	dltz, 		dltc, 		0
		makebword 61, 	dequz, 		dequc, 		0
		makebword 62, 	dgtz, 		dgtc, 		0
		makebword 63, 	dqmz, 		dqmc, 		0
		makebword 64, 	datz, 		datc, 		0
		
		makeemptywords 91-64
		
		makebword 91, 	dlsbz, 		0, 		0
		makebword 92, 	dshlashz, 	dshlashc, 	0
		makebword 93, 	drsbz, 		drsbc, 		0
		makebword 94, 	dtophatz, 	0, 	0
		makebword 95, 	dunderscorez, 	0, 	0
		makebword 96, 	dbacktkz, 		0, 		0
	

		makeemptywords 123-96

		makebword 123, 	dlcbz, 		dlcbc, 		0

		makebword 124, 	dpipez, 	dpipec, 		0
		makebword 125, 	drcbz, 		drcbc, 		0
		makebword 126, 	dtildez, 	dtildec, 	0
		makebword 127, 	ddelz, 		ddelz, 		0
		
		makeemptywords 128

 duserdef:

 dstart:
 startdict:	
		.quad -1 
		.quad  0
		.quad -1	
		.quad 0	
		.quad 0	

		.quad 0 
		.quad 0
		.quad 0
		.quad 0	
		.quad 0	


.align 8
zpos:	.quad 0
zpadsz:  .quad 1024
zpadptr: .quad zpad

.align 8
addressbuffer:
	.zero 128*8


			



