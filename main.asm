;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; riscish experiment by Alban
;; ARM64 November 2021


;; reserved registers.
;; X18 reserved
;; X29 frame ptr
;; X30 aka LR
;; X28 data section pointer
;; X0-X7 and D0-D7, are used to pass arguments to assembly functions, 
;; X19-X28 callee saved
;; X8 indirect result 

;; related to the interpreter
; X16 is the data stack
; X15 is the interpreter pointer
; X14 is the return stack
; X13 is the dictionary pointer
; X12 is the tertiary pointer


;; X28 dictionary
;; X22 word 


 


.macro save_registers  
		STP		X12, X13, [SP, #-16]!
		STP		X14, X15, [SP, #-16]!
		STP		LR,  X16, [SP, #-16]!
.endm

.macro restore_registers  
	 	LDP     LR, X16, [SP], #16
		LDP		X14, X15, [SP], #16	
		LDP		X12, X13, [SP], #16	
.endm

.macro save_registers_not_stack  
		STP		X12, X13, [SP, #-16]!
		STP		X14, X15, [SP, #-16]!
		STP		LR,  XZR, [SP, #-16]!
.endm

.macro restore_registers_not_stack  
	 	LDP     LR, XZR, [SP], #16
		LDP		X14, X15, [SP], #16	
		LDP		X12, X13, [SP], #16	
.endm





; dictionary headers
;
; fixed size so we can use word indexes for execution tokens.
; contain data; so we can make some use of registers.
; must be short, e.g. can call about 50 words or less.
;
; a pointer which is passed to the word in X0
; a 16 byte (including zero) terminated ascii name
; a function pointer for run time action that is called.
; optional compile time function OR data
; data [24 bytes]
; a header contains up to 96 bytes of data
; the data can be used as pointers to other data
; or as literals for the word.

; 0 	pointr ..  8 
; 8  	name  ..  16
; 16	name  ..  24
; 24    run   ..  32
; 32    comp  ..  40
; 40    data  ..  48
; 48    data  ..  56
; 56    data  ..  64
; ..    64 bytes  128;


 

.macro makeword name:req, runtime=-1, comptime=-1, datavalue=1
	.quad   \datavalue
10:
	.asciz	"\name"
20:
	.zero	16 - ( 20b-10b )
	.quad	\runtime
	.quad   \comptime
	.quad   0
	.quad   0
	.quad   0
	.zero	64
 
.endm


; make a short text that is displayed
.macro makedisplay name:req, text="hello world\n"
	.quad   30f
10:
	.asciz	"\name"
20:
	.zero	16 - ( 20b-10b )
	.quad	sayit
	
30: 
	.asciz "\text"
40:
	.zero	64+32 - ( 40b-30b )
.endm

.macro makeshorttextconst name:req, text="hello world\n"
	.quad   30f
10:
	.asciz	"\name"
20:
	.zero	16 - ( 20b-10b )
	.quad  dvaraddz
30: 
	.asciz "\text"
40:
	.zero	64+32 - ( 40b-30b )
.endm


.macro makevarword name:req, v1=1, v2=0, v3=0, v4=0
	.quad   \v1
10:
	.asciz	"\name"
20:
	.zero	16 - ( 20b-10b )
	.quad	dvaraddz
	.quad   dvaraddc
	.quad   \v2
	.quad   \v3
	.quad   \v4
	.zero	64
.endm


.macro makebword name:req, runtime=-1, comptime=-1, datavalue=1
	.quad   \datavalue
	.byte	\name
	.zero   15
	.quad	\runtime
	.quad   \comptime
	.quad   0
	.quad   0
	.quad   0
	.zero	64
.endm

 .macro makeqvword name:req
 	.quad   8 * \name + ivars	
	.byte	\name
	.zero   15
	.quad	dvaraddz
	.quad   dvaraddc
	.quad   0
	.quad   0
	.quad   0
	.zero	64


.endm

;  
.macro makeemptywords n=32 
	.rept  \n
	.quad  -1
 	.quad  -1
	.zero  128-16 
	.endr
.endm



.data

.align 8

ver:    .double 0.35
tver:   .ascii  "Version %2.2f\n"
        .zero   4



.text

.global main 

.align 8			 


 		; get line from terminal
getline:

		ADRP	X8, ___stdinp@GOTPAGE
		LDR		X8, [X8, ___stdinp@GOTPAGEOFF]
		LDR		X2, [X8]
	    ADRP	X0, zpadsz@PAGE	   
		ADD     X1, X0, zpadsz@PAGEOFF
		ADRP	X0, zpadptr@PAGE	
		ADD     X0, X0, zpadptr@PAGEOFF
		save_registers
		BL		_getline
		restore_registers
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


saynotfound:
	 	ADRP	X0, tcomer4@PAGE	
		ADD		X0, X0, tcomer4@PAGEOFF
        B		sayit


sayerrlength:
	 	ADRP	X0, tlong@PAGE	
		ADD		X0, X0, tlong@PAGEOFF
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
	 	ADRP	X0,	 tunder@PAGE	
		ADD		X0, X0,	tunder@PAGEOFF
        B		sayit

sayeol:
		ADRP	X0, texit@PAGE	
		ADD		X0, X0, texit@PAGEOFF
		BL		sayit
		B		finish


; first print all defined words in the long word dictionary
; then print all the words in the bytewords dictionary.

dotwords:
	
		ADRP	X8, ___stdoutp@GOTPAGE
		LDR		X8, [X8, ___stdoutp@GOTPAGEOFF]
		LDR		X1, [X8]

	 	ADRP	X2, dend@PAGE	
		ADD		X2, X2, dend@PAGEOFF

20:		ADD		X2, X2, #128
		LDR		X0, [X2,#8]
		CMP     X0, #-1
		B.eq    10f
		CMP     X0, #0
		B.eq    15f
		LDR		X0, [X2,#8]
		ADD     X0, X2, #8
		STP		X2, X1, [SP, #-16]!
		save_registers
		BL		_fputs	 
 
		MOV     X0, #32
		BL      _putchar
		restore_registers
		LDP     X2, X1, [SP], #16


10:		; skip non word
		B		20b  

 
15:
		RET

sayit:		
     
		ADRP	X8, ___stdoutp@GOTPAGE
		LDR		X8, [X8, ___stdoutp@GOTPAGEOFF]
		LDR		X1, [X8]
   		save_registers
 		STP		X1, X1, [SP, #-16]!
		BL		_fputs	 
		ADD     SP, SP, #16 
		restore_registers
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

absz:			
		RET


addz:			; add tos to 2os leaving result tos
		LDR		X1, [X16, #-8]
		LDR		X2, [X16, #-16]
		ADD		X3, X1, X2
		STR		X3, [X16, #-16]
		SUB		X16, X16, #8
		RET

subz:			; add tos to 2os leaving result tos
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

		
12:		MOV		X0, X1 
		save_registers
 		STP		X0, X0, [SP, #-16]!
		BL		_putchar	 
		ADD     SP, SP, #16 
		restore_registers
		RET


emitchz:	; output X0 as char
		save_registers
 		STP		X0, X0, [SP, #-16]!
		BL		_putchar	 
		ADD     SP, SP, #16 
		restore_registers
		RET

emitchc:	; output X0 as char
		RET




reprintz:
	 
		LDP		X1, X0, [X16, #-16]
		SUB		X16, X16, #16
20:		CMP     X1, #0
		B.eq	10f
		STP     X0, X1,  [SP, #-16]!
		save_registers
 		STP		X0, X0, [SP, #-16]!
		BL		_putchar	 
		ADD     SP, SP, #16 
		restore_registers
		LDP     X0, X1, [SP], #16
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
20:		CMP     X1, #0
		B.eq	10f
		MOV     X0, #32
		STP     X0, X1,  [SP, #-16]!
		save_registers
 		STP		X0, X0, [SP, #-16]!
		BL		_putchar	 
		ADD     SP, SP, #16 
		restore_registers
		LDP     X0, X1, [SP], #16
		SUB		X1, X1, #1
		B		20b

10:
		RET


spacesc:	
		RET


print: ; prints int on top of stack		
	
		LDR		X1, [X16, #-8]
		SUB		X16, X16, #8	
12:

	 	ADRP	X0, tdec@PAGE	   
		ADD		X0, X0,tdec@PAGEOFF
		save_registers
		STP		X1, X0, [SP, #-16]!
		BL		_printf		 
		ADD     SP, SP, #16 
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
		B 			chkoverflow
		RET




chkunderflow: ; check for stack underflow
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
		RET

chkoverflow:; check for stack overflow

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
		save_registers
		STP		X1, X0, [SP, #-16]!
		BL		_printf		 
		ADD     SP, SP, #16  
		restore_registers
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


start_point: ; dictionary entry points are based on first letters in words
	
		ADRP	X22, zword@PAGE	   
	    ADD		X22, X22, zword@PAGEOFF
		
		LDRB 	W0,	[X22]	; first letter
		
		; lower case and check for a..z
		ORR		W0, W0, 0x20

		CMP		W0, #'z'	
		B.gt 	searchall
		
		CMP		W0, #'a'
		B.lt	searchall

		; We have a..z, A..Z, so narrow the search.

		CMP		W0, #'a'
		B.ne	201f
		ADRP	X28, adict@PAGE	   
	    ADD		X28, X28, adict@PAGEOFF	
		B		251f

201:	CMP		W0, #'b'
		B.ne	221f
		ADRP	X28, bdict@PAGE	   
	    ADD		X28, X28, bdict@PAGEOFF	
	 	B       251f


221:	CMP		W0, #'c'
		B.ne	202f
		ADRP	X28, cdict@PAGE	   
	    ADD		X28, X28, cdict@PAGEOFF	
	 	B       251f		 

202:	CMP		W0, #'d'
		B.ne	203f
		ADRP	X28, ddict@PAGE	   
	    ADD		X28, X28, ddict@PAGEOFF	
		B       251f
 
203:	CMP		W0, #'e'
		B.ne	204f
		ADRP	X28, edict@PAGE	   
	    ADD		X28, X28, edict@PAGEOFF	
		B       251f
 
204:	CMP		W0, #'f'
		B.ne	205f
		ADRP	X28, fdict@PAGE	   
	    ADD		X28, X28, fdict@PAGEOFF	
		B       251f

205:	CMP		W0, #'g'
		B.ne	206f
		ADRP	X28, gdict@PAGE	   
	    ADD		X28, X28, gdict@PAGEOFF	
		B       251f


206:	CMP		W0, #'h'
		B.ne	207f
		ADRP	X28, hdict@PAGE	   
	    ADD		X28, X28, hdict@PAGEOFF	
		B       251f

207:	CMP		W0, #'i'
		B.ne	208f
		ADRP	X28, idict@PAGE	   
	    ADD		X28, X28, idict@PAGEOFF	
		B       251f

208:	CMP		W0, #'j'
		B.ne	209f
		ADRP	X28, jdict@PAGE	   
	    ADD		X28, X28, jdict@PAGEOFF	
		B       251f

209:	CMP		W0, #'k'
		B.ne	210f
		ADRP	X28, kdict@PAGE	   
	    ADD		X28, X28, kdict@PAGEOFF	
		B       251f

210:	CMP		W0, #'l'
		B.ne	211f
		ADRP	X28, ldict@PAGE	   
	    ADD		X28, X28, ldict@PAGEOFF	
		B       251f

211:	CMP		W0, #'m'
		B.ne	212f
		ADRP	X28, mdict@PAGE	   
	    ADD		X28, X28, mdict@PAGEOFF	
		B       251f

212:	CMP		W0, #'n'
		B.ne	213f
		ADRP	X28, ndict@PAGE	   
	    ADD		X28, X28, ndict@PAGEOFF	
		B       251f

213:	CMP		W0, #'o'
		B.ne	214f
		ADRP	X28, odict@PAGE	   
	    ADD		X28, X28, odict@PAGEOFF	
		B       251f

214:	CMP		W0, #'p'
		B.ne	215f
		ADRP	X28, pdict@PAGE	   
	    ADD		X28, X28, pdict@PAGEOFF	
		B       217f

215:	CMP		W0, #'q'
		B.ne	216f
		ADRP	X28, qdict@PAGE	   
	    ADD		X28, X28, qdict@PAGEOFF	
		B       251f

216:	CMP		W0, #'r'
		B.ne	217f
		ADRP	X28, rdict@PAGE	   
	    ADD		X28, X28, rdict@PAGEOFF	
		B       251f

217:	CMP		W0, #'s'
		B.ne	218f
		ADRP	X28, sdict@PAGE	   
	    ADD		X28, X28, sdict@PAGEOFF	
		B       251f

218:	CMP		W0, #'t'
		B.ne	219f
		ADRP	X28, tdict@PAGE	   
	    ADD		X28, X28, tdict@PAGEOFF	
		B       251f

219:	CMP		W0, #'u'
		B.ne	220f
		ADRP	X28, udict@PAGE	   
	    ADD		X28, X28, udict@PAGEOFF	
		B       251f

220:	CMP		W0, #'v'
		B.ne	221f
		ADRP	X28, vdict@PAGE	   
	    ADD		X28, X28, vdict@PAGEOFF	
		B       251f

221:	CMP		W0, #'w'
		B.ne	222f
		ADRP	X28, wdict@PAGE	   
	    ADD		X28, X28, wdict@PAGEOFF	
		B       251f

222:	CMP		W0, #'x'
		B.ne	223f
		ADRP	X28, xdict@PAGE	   
	    ADD		X28, X28, xdict@PAGEOFF	
		B       251f

223:	CMP		W0, #'y'
		B.ne	224f
		ADRP	X28, ydict@PAGE	   
	    ADD		X28, X28, ydict@PAGEOFF	
		B       251f

224:	CMP		W0, #'z'
		B.ne	225f
		ADRP	X28, zdict@PAGE	   
	    ADD		X28, X28, zdict@PAGEOFF	
		B       251f		

225:

searchall:
		; search from bottom of dictionary
		; from here X28 is current word in sdict
		ADRP	X28, startdict@PAGE	   
	    ADD		X28, X28, startdict@PAGEOFF
251:	
		SUB		X28, X28, #128

		RET


;; start running here

main:	 
		 

init:	

		ADRP	X0, dsp@PAGE	   
	    ADD		X0, X0, dsp@PAGEOFF
		LDR		X16, [X0]  ;; <-- data stack pointer to X16


   	    BL  announce
		BL  dotwords
input: 	BL  chkoverflow
		BL  chkunderflow
		BL  sayok
		BL  resetword
		BL  resetline
		BL  getline

advance_word:

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
		save_registers
 		STP		X1, X0, [SP, #-16]!
		BL		_fputs	 
		ADD     SP, SP, #16 
		restore_registers
		MOV		X0, #0
		BL		_exit


		; outer interpreter
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
		CMP 	W0, #':' 	; do we enter the compiler ?
		B.eq	enter_compiler

		; check if we need to enter the compiler loop.
		LDRB	W0, [X22]
		CMP 	W0, #']' 	; do we enter the compiler ?
		B.eq	enter_compiler



fw1:
		BL		start_point	


252: 
		BL 		get_word
		 
		LDR		X21, [X28, #8]  ; name field
		CMP     X21, #0        ; end of list?
		B.eq    finish_list	
		CMP     X21, #-1       ; undefined entry in list?
		b.eq    251b

		CMP		X21, X22       ; is this our word?
		B.ne	251b

		; found word, exec function
 
		LDR     X2,	[X28, #24]  
		CMP		X2, #0 
		B.eq	finish_list
		LDR     X0,	[X28] ; data
		STP		X28, XZR, [SP, #-16]!

		BLR		X2	 ;; call function

		LDP		X28, XZR, [SP]
		B       advance_word

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
		LDR		X0, [X27, X0]
		STR		X0, [X16], #8	
		; todo check overflow.
		B       advance_word

ivset:	; from stack set variable
		LDRB 	W0,	[X22]
		LSL     X0, X0, #3
		LDR		X1, [X16, #-8]
		SUB		X16, X16, #8
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
		STR		X1, [X27]
		B		10b


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
		; we have a valid number, so translate it
		BL		word2number
		B       advance_word

		; OR the word may be a decimal number

decimal_number:
		; TODO: decimals





		; from here we are no longer interpreting the line.
		; we are compiling input until we get see a ';'

compiler:

		ADRP	X22, zword@PAGE	   
	    ADD		X22, X22, zword@PAGEOFF
		
		LDRB	W0, [X22]
		CMP 	W0, #':' 	; do we enter the compiler ?
		B.ne	not_compiling ; no..

		; yes, from here we compile a new word.

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



		; we need to repeat all of the parsing functions here in the compiling loop.
		; in this loop we compile each word rather than just executing it.
		; all words have a compile action, so they essentially compile themselves..

compile_word:



exit_compiler:


		; BL sayok

		B	advance_word ; back to main loop



not_compiling:

; at this point we have not found this word
; display word not found as an error.

		BL		saycr
		BL		saylb
		BL		sayword
		BL		sayrb
		BL 		saynotfound
		
		B		advance_word


exit_program:		

		MOV		X0,#0
        BL		_exit
		
		;brk #0xF000


; The inner interpreter - interprets 'compiled' code threads.
; a compiled word is a list of entries in the dictionary

; X16 is the data stack
; X15 is the interpreter pointer
; X14 is the return stack
; X13 is the dictionary pointer


; IP --> [WORD HEADER: data word]  
;		 etc

inner_interpreter:

exec_word:

		; X0 is address of word header
		MOV  	X15, X0 
 
next:	LDR		X1, [X15, #8]!
		LDR     X0,	[X1] ; data
		LDR		X1, [X1, #-16] ; run time function
		BLR		X1
		B		next




;; these functions are all single letter words.
;; z is run time, c is the optional compile time behaviour.

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
		LDP  	X0, X1,  [X16, #-16]  
		UDIV 	X2, X0, X1
		MSUB 	X3, X2, X1, X0 
		STR 	X3, [X16, #-16]
		SUB 	X16, X16, #8
		RET


		RET

dmodc: ; % 
		RET


dandz: ; & 
		B 	andz
		RET

dandc: ; & 
		RET



;; CREATION WORDS
;; add words to dictionary.
;; create, variable, constant

; create, creates a standard word header.

dcreatz:

		save_registers

		BL		advancespaces
		BL		collectword
		BL      get_word
		BL 		empty_wordQ
		B.eq	300f


		BL		start_point

100:	; find free word and start building it


		LDR		X1, [X28, #8] ; name field

		CMP     X1, #0        ; end of list?
		B.eq    280f		   ; not found 
		CMP     X1, #-1       ; undefined entry in list?
		b.ne    260f

		; undefined so build the word here

		; this is now the latest word being built.
		ADRP	X1, latest@PAGE	   
	    ADD		X1, X1, latest@PAGEOFF
		STR		X28, [X1]

		; copy text over
		LDR     X0, [X22]
		STR		X0, [X28, #8]
		ADD		X22, X22, #8
		LDR     X0, [X22]
		STR		X0, [X28, #16]

		ADRP	X1, runintz@PAGE	; high level word.   
	    ADD		X1, X1, runintz@PAGEOFF
		STR		X1, [X28, #24]

		ADD		X1,	X28, #32
		STR		X1, [X28]

		B		300f


260:	; try next word in dictionary
		SUB		X28, X28, #128
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
		BL      get_word
		BL 		empty_wordQ
		B.eq	300f


		BL		start_point

100:	; find free word and start building it


		LDR		X1, [X28, #8] ; name field

		CMP     X1, #0        ; end of list?
		B.eq    280f		   ; not found 
		CMP     X1, #-1       ; undefined entry in list?
		b.ne    260f

		; undefined so build the word here

		; this is now the latest word being built.
		ADRP	X1, latest@PAGE	   
	    ADD		X1, X1, latest@PAGEOFF
		STR		X28, [X1]

		; copy text for name over
		LDR     X0, [X22]
		STR		X0, [X28, #8]
		ADD		X22, X22, #8
		LDR     X0, [X22]
		STR		X0, [X28, #16]

		; variable code
		ADRP	X1, dconstz@PAGE	 
	    ADD		X1, X1, dconstz@PAGEOFF
		STR		X1, [X28, #24]

		;ADD		X1,	X28, #32
		;STR		X1, [X28]

		; set constant from tos.
		LDR 	X1, [X16, #-8] 	 
		SUB		X16, X16, #8
		STR		X1, [X28]

		B		300f


260:	; try next word in dictionary
		SUB		X28, X28, #128
		B		100b

280:	; error dictionary FULL


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
		BL      get_word
		BL 		empty_wordQ
		B.eq	300f


		BL		start_point

100:	; find free word and start building it


		LDR		X1, [X28, #8] ; name field

		CMP     X1, #0        ; end of list?
		B.eq    280f		   ; not found 
		CMP     X1, #-1       ; undefined entry in list?
		b.ne    260f

		; undefined so build the word here

		; this is now the latest word being built.
		ADRP	X1, latest@PAGE	   
	    ADD		X1, X1, latest@PAGEOFF
		STR		X28, [X1]

		; copy text for name over
		LDR     X0, [X22]
		STR		X0, [X28, #8]
		ADD		X22, X22, #8
		LDR     X0, [X22]
		STR		X0, [X28, #16]

		; variable code
		ADRP	X1, dvaraddz@PAGE	; high level word.   
	    ADD		X1, X1, dvaraddz@PAGEOFF
		STR		X1, [X28, #24]

		ADD		X1,	X28, #32
		STR		X1, [X28]

		; set variable from tos.
		LDR 	X1, [X16, #-8] 	 
		SUB		X16, X16, #8
		STR		X1, [X28, #32]

		B		300f


260:	; try next word in dictionary
		SUB		X28, X28, #128
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
 
		BL 		empty_wordQ
		B.eq	190f

		BL		start_point

120:
		LDR		X21, [X28, #8] ; name field

		CMP     X21, #0        ; end of list?
		B.eq    190f		   ; not found 
		CMP     X21, #-1       ; undefined entry in list?
		b.eq    170f

		; check word

		; display word seen
		;BL		saycr
		;ADD		X0, X28, #8
		;BL      sayit 

		BL      get_word
		LDR		X21, [X28, #8] ; name field
		CMP		X21, X22       ; is this our word?
		B.ne	170f

		; found word, stack address of word
 	

		MOV     X0,	X28  
		restore_registers

	 	B		stackit

170:	; next word in dictionary
		SUB		X28, X28, #128
		B		120b

190:	; error out 
		MOV	X0, #0
		restore_registers
		B   stackit


		RET

dtickc: ; '
		RET




dnthz: ; from address, what is our position.
 	 	ADRP	X2, dend@PAGE	
		ADD		X2, X2, dend@PAGEOFF
		LDR 	X1, [X16, #-8] 	 
		SUB		X1, X1, X2
		LSR		X1, X1, #7	 ; / 128
		STR 	X1, [X16, #-8] 	 
		RET

dnthc: ; '
		RET




daddrz: ; from our position, address
 	 	ADRP	X2, dend@PAGE	
		ADD		X2, X2, dend@PAGEOFF
		LDR 	X1, [X16, #-8] 	
		LSL		X1, X1, #7	 ; / 128 
		ADD		X1, X1, X2
		STR 	X1, [X16, #-8] 	 
		RET

daddrc: ; '
		RET



dcallz:	;  code field (from ' WORD on stack)

		LDR 	X1, [X16, #-8] 	 
		SUB		X16, X16, #8
		LDR     X0, [X1]
		LDR     X1, [X1, #24]
		BR      X1 		


dcallc:	; CALL code field (on stack)




runintz:	; interpret the code at X0
			; as halfword tokens.
			; until 0.

		MOV    X15, X0

		ADRP   X12, dend@PAGE	
		ADD	   X12, X12, dend@PAGEOFF

10:		; next token
		LDRH	W1,  [X15]
		ADD		X15, X15, #2
		CBZ     W1, 90f

		LSL		W1, W1, #7	 ;  *128 
		ADD		X1, X1, X12  ; + dend

		LDR     X0, [X1]		; words data
		LDR     X1, [X1, #24]	; words code

	 
		STP		LR,  X12, [SP, #-16]!
		BLR     X1 		
 
		LDP		LR, X12, [SP], #16	
	 

		B		10b
90:

		RET



dlrbz: ; (
		RET

dlrbc: ; (
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
		B  		subz
		RET

dsubc: ;  subtract
		RET

ddotz: ; . print tos
		B  		print
		RET

ddotc: ; 
		RET


ddivz: ; / divide
		B  		udivz
		RET

ddivc: ; 
		RET

dsdivz: ; \ divide
		B  		sdivz
		RET

dsdivc: ; 
		RET

dsmodz: ; /MOD
		LDP  	X0, X1,  [X16, #-16]  
		UDIV 	X2, X0, X1
		MSUB 	X3, X2, X1, X0 
		STP	 	X3, X2, [X16, #-16]  
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
		B  		addz
		RET

dplusc: ; 
		RET

ddropz: ;  
		SUB 	X16, X16, #8
		RET

ddropc: ;   
		RET	


ztypez:
		LDR 	X0, [X16, #-8] 
		B       sayit

ztypec:


ddupz: ;  
		LDR 	X0, [X16, #-8] 
		STR		X0, [X16], #8
		RET
	

dqdupc: ;   
		RET	


dqdupz: ;  ?DUP 
		LDR 	X0, [X16, #-8]
		CBZ		X0, 10f
		STR		X0, [X16], #8
10:		
		RET
	

ddupc: ;   
		RET	


dswapz: ;  
		LDP    X0, X1, [X16, #-16]
		STP    X1, X0, [X16, #-16]
		RET

dswapc: ;   
		RET	

drotz: ;  
		LDP		X1, X0, [X16, #-16] 
		LDR     X2, [X16, #-24]   
		STP		X0, X2, [X16, #-16]  
		STR		X1, [X16, #-24]  
		RET

drotc: ;   
		RET		



doverz: ;
		LDR 	X0, [X16, #-16] 
		STR		X0, [X16], #8
		RET

doverc:	
		RET


dpickc: ;   
	
		RET	

dpickz: ;  
		LDR		X0, [X16, #-8]!
		ADD     X0, X0, #1
		NEG     X0, X0
		LDR		X1, [X16, X0, LSL #3]
		STR		X1, [X16], #8
		RET

	

dnipc: ;   
		RET	

dnipz: ;  
	
		LDP		X0, X1, [X16, #-16]  
		STR 	X1, [X16, #-16]  
		SUB 	X16, X16, #8
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
		CMP  	X0, X1		
		B.gt	10f
		B.eq	10f
		MVN		X0, XZR ; true
		B		20f
10:
		MOV		X0, XZR
20:
		STR 	X0, [X16, #-16]
		SUB		X16, X16, #8
		RET


dltc: ;  "<"  
		RET		

dequz: ; "=" less than
	
equalz:
		LDR		X0, [X16, #-8] 
		LDR		X1, [X16, #-16]
		CMP  	X0, X1		
		B.ne	10f
		MVN		X0, XZR ; true
		B		20f
10:
		MOV		X0, XZR
20:
		STR 	X0, [X16, #-16]
		SUB		X16, X16, #8
		RET


dequc: ;  "="  
		RET		

dgtz: ; ">" greater than

greaterthanz:
		LDR		X0, [X16, #-8] 
		LDR		X1, [X16, #-16]
		CMP  	X0, X1		
		B.lt	10f
		B.eq	10f
		MVN		X0, XZR ; true
		B		20f
10:
		MOV		X0, XZR
20:
		STR 	X0, [X16, #-16]
		SUB		X16, X16, #8
		RET		


dgtc: ;  ">"  
		RET		

dqmz: ; "?" if zero
		RET

dqmc: ;  "?"  
		RET		

datz: ; "@" at - fetch 
		B 		atz
 

dhatc: ;  "@"  
		RET		

dhatz: ; "@" at - fetch 
		B 		hwatz
 

datc: ;  "@"  
		RET		


		



atz: ;  ( address -- n ) fetch var.
		LDR		X0, [X16, #-8] 
		LDR     X0, [X0]
		STR		X0, [X16, #-8]
		RET

storz:  ; ( n address -- )
		LDR		X0, [X16, #-8] 
		LDR		X1, [X16, #-16]
		STR 	X1, [X0]
		SUB		X16, X16, #16
		RET


hwatz: ;  ( address -- n ) fetch var.
		LDR		X0, [X16, #-8] 
		LDRH    W0, [X0]
		STR		X0, [X16, #-8]
		RET

hwstorz:  ; ( n address -- )
		LDR		X0, [X16, #-8] 
		LDR		X1, [X16, #-16]
		STRH 	W1, [X0]
		SUB		X16, X16, #16
		RET


nsubz:	;
		LDR		X1, [X16, #-8]
		SUB		X1, X1, X0
		STR		X1, [X16, #-8]
		RET

dnsubz:	
		B 		nsubz


dnsubc:	
		RET	



nplusz:	;
		LDR		X1, [X16, #-8]
		ADD		X1, X1, X0
		STR		X1, [X16, #-8]
		RET

dnplusz:
		B 		nplusz


dnplusc:
		RET	


nmulz:	; perform shift left to multiply
		LDR		X1, [X16, #-8]
		LSL		X1, X1, X0
		STR		X1, [X16, #-8]
		RET

dnmulz:
		B 		nmulz


dnmulc:
		RET	
		



ndivz:	; perform shift right to divide
		LDR		X1, [X16, #-8]
		LSR		X1, X1, X0
		STR		X1, [X16, #-8]
		RET

dndivz:
		B 		ndivz

dndivc:
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
	
 
		LDRH	W0, [X15], #2
		B		stackit 

dlitc: ; compile address of variable
		RET


dlitlz: ; next cell has address of quad literal, held in pool
		LDRH	W0, [X15], #2
		ADRP   X1, quadlits@PAGE	
		ADD	   X1, X1, quadlits@PAGEOFF
		LDR	   X0, [X1,X0, LSL #3]
		B		stackit 

dlitlc: ; compile address of variable
		RET


		; literal pool lookup
		; literal on stack, find or add it to LITERAL pool.

dfindlitz:

		LDR	   X0, [X16, #-8] 
 		ADRP   X1, quadlits@PAGE	
		ADD	   X1, X1, quadlits@PAGEOFF
		MOV    X3, XZR

10:
		LDR	   	X2, [X1]
		CMP	   	X2, X0
		B.eq   	80f
		CMP    	X2, #-1  
		B.eq   	70f
		CMP    	X2, #-2 ; end of pool ERROR  
		B.eq   	85f
		ADD	   	X3, X3, #1
		ADD	   	X1, X1, #8
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


85:		; error pool full

		; reset stack
		ADRP	X27, sp1@PAGE	   
	    ADD		X27, X27, sp1@PAGEOFF
		ADRP	X0, dsp@PAGE	   
	    ADD		X0, X0, dsp@PAGEOFF
		STR		X27, [X0]
		MOV		X16, X27 
		; report error
		B		sayerrpoolfullquad

90:	
		RET

dfindlitc:
		RET


dconstz: ; value of constant
		STR		X0, [X16], #8
		RET


dconstc: ; value of constant
		STR		X0, [X16], #8
		RET



diloopz: ; special I loop variable
		RET

djloopz: ; special J loop variable
		RET

dkloopz: ; special K loop variable
		RET

diloopc: ; special I loop variable
		RET

djloopc: ; special J loop variable
		RET

dkloopc: ; special K loop variable
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
		CMP 	X0,  #1
		CSNEG   X0, X0, X0, pl	
		STR     X0, [X16, #-8]
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

dlcbz: ;  {   lcb
		RET

dlcbc: ;  {   lcb
		RET



dpipez: ; |  pipe
		B 	orz
		RET


dpipec: ; |  pipe
		RET


drcbz: ;  }   rcb
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

.align 8
 

dpage: .zero 4
zstdin: .zero 16



;; text literals



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

.align 8
poolfullerr:
		.ascii "Error pool full."
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
tdec:	.ascii "%3ld"
		.zero 16

.align 	8
tovflr:	.ascii "\nstack over-flow"
		.zero 16

.align 	8
tunder:	.ascii "\nstack under-flow"
		.zero 16

.align 	8
tcomer1: .ascii "\nCompiler error ':' expects a word to define."
		.zero 16

.align 	8
tcomer3: .ascii "\nCompiler error  "
		.zero 16

.align 	8
tcomer4: .ascii "<-- Word was not recognized. "
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



; variables
.align 16
latest:	.quad 	-1		; latest word being updated.

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

		.rept  512   ; <-- increase if literal pool full error arises.
		.quad -1
		.endr
		.quad  -2 ; end of literal pool. 
		.quad  -2 

; used for line input
.align 16
zpad:    .ascii "ZPAD STARTS HERE"
		 .zero 1024

.align 8
zword: .zero 64

 .align 8
 dbye:		.ascii "BYE" 
			.zero 5
			.zero 8
			.quad 0
			.quad 0

			; WORD headers
 		    ; each word name is 16 bytes of zero terminated ascii	
			; a pointer to the adress of the run time machine code function to call.
			; a pointer to the adress of the compile time machine code function to call.
			; a data element
			; gaps for capacity are stacked up towards 'a'  
			;  

			; the end of the list - also the beginning of the same.

			.quad 0
			.quad 0
			.quad 0
			.quad 0

dend:		
			.quad -1 ; cdata - class data 
 			.quad -1 ; name
			.quad 0	; name
			.quad 0	; zptr - run time action
			.quad 0 ; cptr - compile time action
	
			.quad 0
			.quad 0
			.quad 0
			.zero 64
			; primitive code word headings.

		
		    makeemptywords 44

			makeword "ADDR" , daddrz, daddrc, 0

			makeword "ABS" , dabsz, dabsc, 0

			makeqvword 97
			makeword "A", dvaraddz, dvaraddc,  8 * 65 + ivars	 
	
		 
adict:

			makeemptywords 44

			makeword "BREAK",  dbreakz, dbreakc, 0
	  		makeword "BL",  dconstz, dconstz, 32
			
			makeqvword 98
			makeword "B", dvaraddz, dvaraddc,  8 * 66 + ivars	

bdict:
			makeemptywords 40

			makeword "CONSTANT", dcreatcz , dcreatcc, 0
			makeword "CREATE", 	dcreatz, dcreatc, 0
			makeword "CALL", 	dcallz, dcallc, 0
			makeword "CR", 		saycr, 0, 0
			makeqvword 99
			makeword "C", 		dvaraddz, dvaraddc,  8 * 67 + ivars	

cdict:
			makeemptywords 40

	 
			makevarword "DP"
			makeword "DUP", ddupz , ddupc, 0 
			makeword "DROP", ddropz , ddropc, 0 
		 	 	


			makeqvword 100
			makeword "D", dvaraddz, dvaraddc,  8 * 68 + ivars	

ddict:
			makeemptywords 40

			makeword "EMIT", emitz , 0, 0 
		 	
			makeqvword 101
			makeword "E", dvaraddz, dvaraddc,  8 * 69 + ivars	

edict:
			makeemptywords 40
		 	
			makeqvword 102
			makeword "F", dvaraddz, dvaraddc,  8 * 70 + ivars	
			makeword "FINDLIT", dfindlitz, dfindlitc,  0

fdict:		
			makeemptywords 39
			makeshorttextconst "GREET", "Hey how are you, hope you are keeping well in these strange times?"
			makeqvword 103
			makeword "G", dvaraddz, dvaraddc,  8 * 71 + ivars	
gdict:
			makeemptywords 38

			makeword "HW!", dhstorez, dhstorec,  0

			makeword "HW@", dhatz, dhatc, 0

			                  ; 32 char limit.
						 	  ;012345678-012345678-012345678-12	
			makedisplay "HI", "Hello please enjoy the session\n"

			makeqvword 104

			makeword "H", dvaraddz, dvaraddc,  8 * 72 + ivars	
hdict:

			makeemptywords 36
			makeqvword 105
			makeword "I", diloopz, diloopc,  0

idict:
			makeemptywords 36
			makeqvword 106
			makeword "J", djloopz, djloopc,  0
jdict:
			makeemptywords 34
			makeqvword 107
			makeword "K", dkloopz, dkloopc,  0
kdict:
			makeemptywords 34
			
			makeword "LATEST", dvaraddz, dvaraddc,  latest
			makeqvword 108
			makeword "L", dvaraddz, dvaraddc,  8 * 76 + ivars	
			makeword "LITS", dlitz, dlitc,  0
			makeword "LITL", dlitlz, dlitlc,  0
			makeword "LITBASE", dvaraddz, dvaraddc,  quadlits
ldict:
			makeemptywords 31

			makeword "MOD", dmodz, dmodc, 0	

			makeemptywords 38

			makeqvword 109
			makeword "M", dvaraddz, dvaraddc,  8 * 77 + ivars	
mdict:
			makeemptywords 34


			makeword "NTH", dnthz, dnthc, 0	

			makeword "NIP", dnipz, dnipc, 0	

			makeqvword 110
			makeword "N", dvaraddz, dvaraddc,  8 * 78 + ivars	

ndict:		
			makeemptywords 32


			makeword "OVER", doverz, doverc, 0
			makeqvword 111
			makeword "O", dvaraddz, dvaraddc,  8 * 79 + ivars	
		
odict:
			makeemptywords 32

			makevarword "PAD", zpad

			makeword "PRINT", print, 0, 0

			makeword "PICK", dpickz, dpickc, 0

			makeqvword 112
			makeword "P", dvaraddz, dvaraddc,  8 * 80 + ivars	


pdict:
			makeemptywords 32
			makeqvword 113
			makeword "Q", dvaraddz, dvaraddc,  8 * 81 + ivars	

qdict:
			makeemptywords 30

			makeword "REPRINT", reprintz , reprintc, 0 
	 

			makeword "ROT", drotz , drotc, 0 

			makeqvword 114
			makeword "R", dvaraddz, dvaraddc,  8 * 82 + ivars	

rdict:

			makeemptywords 30


			; use asm to build a high level 'demo' word

			.quad   30f	; address of halfword token code.
			10:
				.asciz	"SQUARE"
			20:
				.zero	16 - ( 20b-10b )
				.quad	runintz   ; interpret
			30:  ; halfword token list
				.hword  507     ; LIT
				.hword  2       ; lit index
				.hword  507     ; LIT
				.hword  3       ; lit index
				.hword	1097	; +
				.hword	183		; DUP
				.hword  1096    ; *
				.hword  1100    ; .
				.hword  0       ; END OF WORD
			40:
				.zero	128 - ( 40b-30b ) - 32		

			; to get the tokens 
			; ' DUP NTH .
			; ' * NTH .
			; ' . NTH .
			; The tokens change if a new word is added 
			; using the assmbler, WITHOUT reducing the empty
			; word count above it.


			makeword "SWAP", dswapz , dswapc, 0 
	

			makeword "SPACES", spacesz , spacesc, 0 
		

			makeword "SPACE", emitchz , emitchc, 32

			makevarword "SP", dsp

			makeqvword 115 
			makeword "S", dvaraddz, dvaraddc,  8 * 83 + ivars	

sdict:
			makeemptywords 30

			makeword "TYPEZ", ztypez, ztypec, 0	
		
			makeqvword 116
			makeword "T", dvaraddz, dvaraddc,  8 * 84 + ivars	

tdict:

			makeemptywords 30
			makeqvword 117
			makeword "U", dvaraddz, dvaraddc,  8 * 85 + ivars	

udict:


	
			makeemptywords 28
			makeword "VERSION", announce , 0, 0


			makeword "VARIABLE", dcreatvz , dcreatvc, 0

			makeqvword 118
			makeword "V", dvaraddz, dvaraddc,  8 * 86 + ivars	
 		
vdict:
			makeemptywords 28

			makeword "WORDS", dotwords , 0, 0 
		 
	
			makeqvword 119
 			makeword "W", dvaraddz, dvaraddc,  8 * 87 + ivars	
			
			
wdict:

			makeemptywords 28
			 
			makeqvword 120
			makeword "X", dvaraddz, dvaraddc,  8 * 88 + ivars	
xdict:
			makeemptywords 28
			
 
			makeqvword 121
			makeword "Y", dvaraddz, dvaraddc,  8 * 89 + ivars	
			

ydict:
			makeemptywords 24

		 	makeqvword 122
			makeword "Z", dvaraddz, dvaraddc,  8 * 90 + ivars	

zdict:

			makeemptywords 20

			makeword "-1", dconstz, dconstc,  -1
			makeword "-2", dconstz, dconstc,  -2
			makeword "1+", dnplusz , 0, 1 
			makeword "2+", dnplusz , 0, 2
			makeword "4+", dnplusz , 0, 4
			makeword "1-", dnsubz , 0, 1
			makeword "2-", dnsubz , 0, 2
			makeword "2*", dnmulz , 0, 2
			makeword "2/", dndivz , 0, 2
			makeword "4*", dnmulz , 0, 2
			makeword "4/", dndivz , 0, 2

			makeword "8-", dnsubz , 0, 8
			makeword "8+", dnplusz , 0, 8 
			makeword "8*", dnmulz , 0, 3
			makeword "8/", dndivz , 0, 3


			makeword "16-", dnsubz , 0, 4
			makeword "16+", dnplusz , 0, 4 
			makeword "16*", dnmulz , 0, 4
			makeword "16/", dndivz , 0, 4

			makeword "24+", dnplusz , 0, 24
			makeword "24-", dnsubz , 0, 24
			
			makeword "/MOD", dsmodz , dsmodc, 0

			makeword ".VERSION", announce , 0, 0

			makeword "?DUP", dqdupz, dqdupc, 0

 			


zbytewords:
			makeemptywords 33
			makebword 33,	 dstorez,	dstorec,	0
			makebword 34,	 dquotz,	dquotc,		0
			makebword 35,	 dhashz,	dhashc,		0
			makebword 36,	 ddollarz,	ddollarz,	0
			makebword 37,	 dmodz,		dmodc,		0
			makebword 38,	 dandz,		dandz,		0
			makebword 39,	 dtickz,	dtickc,		0
			makebword 40,	 dlrbz,		dlrbc,		0
			makebword 41,	 drrbz,		drrbc,		0
			makebword 42,	 dstarz,	dstarz,		0
			makebword 43,	 dplusz,	dplusc,		0
			makebword 44,	 dcomaz,	dcomac,		0
			makebword 45,	 dsubz,		dsubc,		0
			makebword 46,	 ddotz,		ddotc,		0
			makebword 47,	 dsdivz,	dsdivz,		0
			makebword 48,	 stackit,	stackit,	0
	 		makebword 49,	 stackit,	stackit,	1
			makebword 50,	 stackit,	stackit,	2
			makebword 51,	 stackit,	stackit,	3
			makebword 52,	 stackit,	stackit,	4
			makebword 53,	 stackit,	stackit,	5
			makebword 54,	 stackit,	stackit,	6
			makebword 55,	 stackit,	stackit,	7
			makebword 56,	 stackit,	stackit,	8
			makebword 57,	 stackit,	stackit,	9

			makebword 58,	 dcolonz,	dcolonc,	0
 			makebword 59,	 dsemiz,	dsemic,		0
			makebword 60,	 dltz,		dltc,		0
 			makebword 61,	 dequz,		dequc,		0
			makebword 62,	 dgtz,		dgtc,		0
 			makebword 63,	 dqmz,		dqmc,		0
			makebword 64,	 datz,		datc,		0
 			
			makeemptywords 91-64
 			
			makebword 91,	 dlsbz,		dlsbz,		0
			makebword 92,	 dshlashz,	dshlashc,	0
			makebword 93,	 drsbz,		drsbc,		0
			makebword 94,	 dtophatz,	dtophatz,	0
			makebword 95,	 dunderscorez,	dunderscorez,	0
			makebword 96,	 dbacktkz,		dbacktkz,		0
		

			makeemptywords 123-96

			makebword 123,	 dlcbz,		dlcbc,		0

			makebword 124,	 dpipez,	dpipec,		0
			makebword 125,	 drcbz,		drcbc,		0
			makebword 126,	 dtildez,	dtildec,	0
			makebword 127,	 ddelz,		ddelz,		0
			
			makeemptywords 128

 duserdef:

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
zpos:    .quad 0
zpadsz:  .quad 1024
zpadptr: .quad zpad

.align 8
addressbuffer:
		.zero 128*8


			   



