;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; M1 MICRO FORTH by Alban
;; This is a small non-standard FORTH like interpreter for Apple Silicon
;; implemented in assembly language
;; Copyright 2022 Alban Read
;; Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
;; 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
;; 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
;; 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


;; reserved registers.
;; X18 reserved for OS
;; X29 frame ptr for OS/C
;; X30 aka LR (the return register)
;; X28 data section pointer
;; X0-X7 and D0-D7, are used to pass arguments to assembly functions, 
;; X19-X28 callee 
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
;; X29 the start of the current word.

;; X22 word (text)
;; X23 also used for text

   

.macro reset_data_stack
 
	ADRP	X0, dsp@PAGE		
	ADD		X0, X0, dsp@PAGEOFF
	LDR		X1, [X0]
	ADD		X1, X1, #48
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
	STP		X2,  X3,  [SP, #-16]!
 	STP		X22,  X24,  [SP, #-16]!
 
.endm

.macro restore_registers  
 	LDP		X22, X24, [SP], #16
	LDP		X2, X3, [SP], #16
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
; These are separate from the token space, or literal pools
; contain the name of a word, the runtime and compile time functions
; and a small ammount of data for the functions use.


; data 		(argument for runtime)
; runtime	function address when running
; data		(argument for compile time)
; comptime	function address when compiling
; data		spare data
; data
; name 		the words name
 
.macro makeword name:req, runtime=-1, comptime=-1, datavalue=1, dvalue2=0, dvalue3=0, dvalue4=0
	.quad	\datavalue
	.quad	\runtime
	.quad	\dvalue2				; data
	.quad	\comptime
	.quad	\dvalue3	
	.quad	\dvalue4
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

.macro copy_word_name
	; copy words name text over
	LDR		X0, [X22]
	STR		X0, [X28, #48]
	ADD		X22, X22, #8
	LDR		X0, [X22]
	STR		X0, [X28, #56]
.endm

; trace words, check for X6<>0 
; and print a trace of the inner interpreter

.macro  trace_show_word

	CBZ		X6, 	999f

	STP		LR,  X0, [SP, #-16]!
 
	
	ADD		X2,  X1, #48
	MOV		X0,  X1
	BL		X0addrprln
	 
	LDRH	W0, [X15]
	BL		X0halfpr

 
	MOV		X0, X2
	LDRH    W1, [X15,#-2] 
 
 	ADRP	X0, literal_name@PAGE	
	ADD		X0, X0, literal_name@PAGEOFF	
	
20:
	BL		X0prname

	BL		ddotsz
998:
 
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

998:	
	LDP		LR, X0, [SP], #16	
999:

.endm


.data

data_base:

.align 8
;; VERSION OF THE APP
ver:	.double 0.831
tver:	.ascii  "M1 MICRO FORTH %2.2f TOKEN THREADED 2022\n"
	.zero	4

.text

.global main 

.align 8			



beloud:
	ADRP	X0, bequiet@PAGE
	ADD		X0, X0, bequiet@PAGEOFF
	MOV 	X1, #0
	STR		X1, [X0]
	RET

from_startup:
	save_registers
	ADRP	X0, startup_file@PAGE		
	ADD		X0, X0, startup_file@PAGEOFF
 	ADRP	X1, mode_read@PAGE		
	ADD		X1, X1, mode_read@PAGEOFF
	BL		_fopen
	ADRP	X1, input_file@PAGE
	ADD		X1, X1, input_file@PAGEOFF
	STR		X0,	[X1]
	restore_registers
	RET

dfrom_startup:
	B	from_startup


from_stdin:
	
	ADRP	X8, ___stdinp@GOTPAGE
	LDR		X8, [X8, ___stdinp@GOTPAGEOFF]
	LDR		X2, [X8]

	ADRP	X0, input_file@PAGE
	ADD		X0, X0, input_file@PAGEOFF
	STR		X2,	[X0]

 	ADRP	X0, bequiet@PAGE
	ADD		X0, X0, bequiet@PAGEOFF
	MOV 	X1, #0
	STR		X1, [X0]

	RET


; get line from terminal into PAD
getline:
	ADRP	X0, input_file@PAGE
	ADD		X0, X0, input_file@PAGEOFF
	LDR		X2,	[X0]
	ADRP	X0, zpadsz@PAGE		
	ADD		X1, X0, zpadsz@PAGEOFF
	ADRP	X0, zpadptr@PAGE	
	ADD		X0, X0, zpadptr@PAGEOFF
	save_registers
	BL		_getline
	CMP		X0, #-1 ; end of file
	B.ne	10f 

	; close file on end of file.
	ADRP	X0, input_file@PAGE
	ADD		X0, X0, input_file@PAGEOFF
	LDR		X0,	[X0]
	BL		_fclose

	BL 		from_stdin ; revert to stdin
10:
    ; store count read in accepted
	ADRP	X1, accepted@PAGE
	ADD		X1, X1, accepted@PAGEOFF
	STR		X0, [X1]
	restore_registers
	RET

; accept text from user

dacceptz:
 
	ADRP	X0, input_file@PAGE
	ADD		X0, X0, input_file@PAGEOFF
	LDR		X2,	[X0]
	ADRP	X1, acceptcap@PAGE		
	ADD		X1, X1, acceptcap@PAGEOFF
	ADRP	X0, acceptptr@PAGE	; ** accept_string
	ADD		X0, X0, acceptptr@PAGEOFF
	save_registers
	BL		_getline
	CMP		X0, #-1 ; end of file
	B.ne	10f 

	ADRP	X1, acceptlen@PAGE
	ADD		X1, X1, acceptlen@PAGEOFF 
	STR		X0, [X1]

	; close file on end of file.
	ADRP	X0, input_file@PAGE
	ADD		X0, X0, input_file@PAGEOFF
	LDR		X0,	[X0]
	BL		_fclose

	BL 		from_stdin ; revert to stdin
10:
    ; store count read in accepted

	restore_registers

	STP		LR,  XZR, [SP, #-16]!
	STP		X12,  X13, [SP, #-16]!
	STP		X3,  X5, [SP, #-16]!
	B intern_string_from_buffer
 
	RET


cls:
dpagez:
	ADRP	X0, clear_screen@PAGE	
	ADD		X0, X0, clear_screen@PAGEOFF
	B		sayit

datxyz:
	ADRP	X0, screen_at@PAGE	
	ADD		X0, X0, screen_at@PAGEOFF
	save_registers
 	LDP 	X1, X2, [X16,#-16]
	STP		X1, X2, [SP, #-16]!
	BL		_printf		
	ADD		SP, SP, #16 
	restore_registers  
	SUB 	X16, X16, #16
	RET



datcolr:
	ADRP	X0, screen_textcolour@PAGE	
	ADD		X0, X0, screen_textcolour@PAGEOFF
	save_registers
	MOV     X2, #0
	MOV     X1, #33
 	LDR 	X1, [X16, #-8]
	STP		X1, XZR, [SP, #-16]!
	BL		_printf		
	ADD		SP, SP, #16 
	restore_registers  
	SUB 	X16, X16, #8
	RET


; intern a copy of a string.

intern:
	; string assumed to be in string_buffer
	STP		LR,  XZR, [SP, #-16]!
	STP		X12,  X13, [SP, #-16]!
	STP		X3,  X5, [SP, #-16]!
	B intern_string_from_buffer



; Lots of little messages

; Ok prompt
; only say OK when reading stdin.

sayok:	

	ADRP	X1, input_file@PAGE
	ADD		X1, X1, input_file@PAGEOFF
	LDR		X0,	[X1]

	ADRP	X8, ___stdinp@GOTPAGE
	LDR		X8, [X8, ___stdinp@GOTPAGEOFF]
	LDR		X2, [X8]
	CMP 	X0, X2
	B.ne	quietly

	ADRP	X0, tok@PAGE	
	ADD		X0, X0, tok@PAGEOFF
	B		sayit

quietly:
	RET


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
	B		sayit_err

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
			

 
calloc_failed: ; yes it can fail and yes that is totally fatal.
 	STP		LR,  XZR, [SP, #-16]!
 	ADRP	X0, calloc_error@PAGE	
 	ADD		X0, X0, calloc_error@PAGEOFF
 	BL 		sayit
 	MOV		X0, #-1
 	BL		_exit ; thats that.
 	; ... this never happens.
 	LDP		LR, XZR, [SP], #16
 	RET

sayoverflow:
	STP		LR,  XZR, [SP, #-16]!
	BL		saycr
	BL		saylb
	LDR		X0, [X26, #-72]	 ; self
	ADD		X0, X0, #48
	BL 		sayit
	BL		sayrb
	BL		saylb
	MOV 	X0, X16 
	BL 		X0addrpr
	BL		sayrb
	BL		saylb
	ADRP	X0, spu@PAGE		
	ADD		X0, X0, spu@PAGEOFF
	LDR		X0, [X0]
	BL 		X0addrpr
	BL		sayrb
	BL		saylb
	ADRP	X0, spo@PAGE		
	ADD		X0, X0, spo@PAGEOFF
	LDR		X0, [X0]
	BL 		X0addrpr
	BL		sayrb

	LDP		LR, XZR, [SP], #16

	ADRP	X0, tovflr@PAGE	
	ADD		X0, X0, tovflr@PAGEOFF
	B		sayit_err_word

sayunderflow:
	STP		LR,  XZR, [SP, #-16]!
	BL		saycr
	BL		saylb
	LDR		X0, [X26, #-72]	 ; self
	ADD		X0, X0, #48
	BL 		sayit
	BL		sayrb
	BL		saylb
	MOV 	X0, X16 
	BL 		X0addrpr
	BL		sayrb
	BL		saylb
	ADRP	X0, dsp@PAGE		
	ADD		X0, X0, dsp@PAGEOFF
	LDR		X0, [X0]
	BL 		X0addrpr
	BL		sayrb


	LDP		LR, XZR, [SP], #16
	ADRP	X0, 	tunder@PAGE	
	ADD		X0, X0, 	tunder@PAGEOFF
	B		sayit_err_word

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
; not used as implemented in FORTH

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

	ADRP	X8, rmargin@PAGE	
	ADD		X8, X8, rmargin@PAGEOFF
	LDR 	X3, [X8]

20:	ADD		X2, X2, #64
	LDR		X0, [X2, #48]
	CMP		X0, #-1
	B.eq	10f
	CMP		X0, #0
	B.eq	15f

	LDRB	W0, [X2, #48]
	CBZ 	W0, 10f


	LDRB	W0, [X2, #48]
	ADD		X0, X2,  #48 

	MOV 	X4, X0
	MOV     X5, X0
510:
	LDRB	W0, [X5], #1
	CBZ		W0, 520f
	B 		510b
520:

	SUB 	X8, X5, X4
	SUB 	X3, X3, X8
	
 
	MOV 	X0, X4	 
530:
	STP		X2, X1, [SP, #-16]!
	save_registers
	BL		_fputs	
	restore_registers
	MOV		X0, #32
	save_registers
	BL		_putchar
	restore_registers
	CMP		X3, #0
	B.gt	540f
	save_registers
	BL		saycr
	restore_registers
	ADRP	X8, rmargin@PAGE	
	ADD		X8, X8, rmargin@PAGEOFF
	LDR 	X3, [X8]
540:
	LDP		X2, X1, [SP], #16
 

10:	; skip non word
	B		20b  

15:
	RET


; displays a message
sayit:	
	ADRP	X8, ___stdoutp@GOTPAGE
	LDR		X8, [X8, ___stdoutp@GOTPAGEOFF]
	LDR		X1, [X8]
	save_registers
	BL		_fputs	
	restore_registers
	RET

; displays message and sets the error flag
sayit_err:	
	ADRP	X8, ___stdoutp@GOTPAGE
	LDR		X8, [X8, ___stdoutp@GOTPAGEOFF]
	LDR		X1, [X8]
	save_registers
	BL		_fputs	
	restore_registers
	MOV		X0, #-1 ; flag err for compiler
	RET


sayit_err_word:
	

	save_registers
	MOV 	X5, X0
	BL		saycr
	BL		saylb
	LDR		X0, [X26, #-72]	 ; self
	ADD		X0, X0, #48
	BL 		sayit
	BL		sayrb
 

	ADRP	X8, ___stdoutp@GOTPAGE
	LDR		X8, [X8, ___stdoutp@GOTPAGEOFF]
	LDR		X1, [X8]
	MOV		X0, X5
 
	BL		_fputs	
	restore_registers
	MOV		X0, #-1 ; flag err for compiler
	RET



; WORD scanning routines

resetword: ; clear word return x22
	ADRP	X22, zword@PAGE		
	ADD		X22, X22, zword@PAGEOFF
	STP		XZR, XZR, [X22]
	STP		XZR, XZR, [X22, #48]
	RET


; zaps the line storage for the terminal input
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


; Skip over spaces in the input

advancespaces: ; byte ptr in x23, advance past spaces until zero

10:	LDRB	W0, [X23] 
	CMP		W0, #0
	B.eq	90f	
	CMP		W0, #32
	b.gt	90f
	ADD		X23, X23, #1
	B 		10b

90:	RET


; some simple maths operations
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
		

; some simple logical operations

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


; maths operations

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



; char output 

emitz:	; output tos as char
	LDR		X1, [X16, #-8]
	SUB		X16, X16, #8

	
12:	MOV		X0, X1 

X0emit:	
	save_registers
	BL		_putchar	
	; we need to flush
	ADRP	X8, ___stdoutp@GOTPAGE
	LDR		X8, [X8, ___stdoutp@GOTPAGEOFF]
	LDR		X0, [X8]
	BL		_fflush
	restore_registers
	RET

; lazy buffered version
emitchz:	; output X0 as char
	save_registers
	BL		_putchar	
	restore_registers
	RET

emitchc:	; output X0 as char
	RET


 


; flush the stdout stream
dflushz:
	save_registers
	ADRP	X8, ___stdoutp@GOTPAGE
	LDR		X8, [X8, ___stdoutp@GOTPAGEOFF]
	LDR		X0, [X8] 
	BL		_fflush
	restore_registers
	RET



 

; TERMINAL commands

; No echo - needed when using KEY? and KEY

noecho:
	save_registers

	ADRP	X1, saved_termios@PAGE	
	ADD		X1, X1, saved_termios@PAGEOFF
	ADRP	X0, current_termios@PAGE	
	ADD		X0, X0, current_termios@PAGEOFF
	; X0=DEST current. X1=SRC saved, 72 bytes (sizeof TERMIOS)
 	MOV    	X2, #72
	BL		_memcpy
	ADRP	X0, current_termios@PAGE	
	ADD		X0, X0, current_termios@PAGEOFF
	LDR		X1, [X0, #24]
	AND		X1, X1, #0xfffffffffffffeff ; & ~ICANON (do not wait for newline)
	AND		X1, X1, #0xfffffffffffffff7 ; & ~ECHO (do not echo key)
	STR		X1, [X0, #24]
	MOV		X2, X0
	MOV 	X0, #0
	MOV     X1, #0
	BL  	_tcsetattr
	restore_registers
	RET

; restore terminal (after NOECHO)
; restore to the state the program started
reterm:
 	save_registers
	MOV		X0, #0
	MOV		X1, #0
	ADRP	X2, saved_termios@PAGE	
	ADD		X2, X2, saved_termios@PAGEOFF
	BL		_tcsetattr
	restore_registers
	RET


; KEY for UNIX terminal
; set NOECHO first
dkeyz:

	save_registers
	ADRP	X1, getchar_buf@PAGE	
	ADD		X1, X1, getchar_buf@PAGEOFF
	MOV     X0, #0 ; into start of buffer
	MOV     X2, #1 ; 1 key
	BL		_read	
	restore_registers

	; stack the key pressed.
 	ADRP	X1, getchar_buf@PAGE	
	ADD		X1, X1, getchar_buf@PAGEOFF
	LDR		X0, [X1]
	B 		stackit


; KEY? for UNIX terminal
; I could not be *bothered* (polite term) with
; translating FD_ISSET and assorted C MACROS again.
; See addons.c

dkeyqz:
	save_registers
	BL 		_kb_hit
  	ADRP	X1, bytes_waiting@PAGE	
	ADD		X1, X1, bytes_waiting@PAGEOFF
	STR		X0, [X1]
	restore_registers
  	ADRP	X1, bytes_waiting@PAGE	
	ADD		X1, X1, bytes_waiting@PAGEOFF
	LDR		X0, [X1]
	B 		nequalzz


; like spaces for char n
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



; special display words 

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
	MOV		X1, X0
	B		12f	
		
12:

	ADRP	X0, thalfpr@PAGE		
	ADD		X0, X0, thalfpr@PAGEOFF
	save_registers
	STP		X1, X0, [SP, #-16]!
	BL		_printf		
	ADD		SP, SP, #16 
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
	MOV		X1, X0
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
	ADD		SP, SP, #16 
	restore_registers  
	RET

X0hexprint:
	MOV	X1, X0
	B		12f

dhexprintz: ; prints int on top of stack in hex	
	
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


; Standard printing functions

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

fprint: ; prints float on top of stack		
	
	LDR		X1, [X16, #-8]
	SUB		X16, X16, #8	
		
12:
	ADRP	X0, fdec@PAGE		
	ADD		X0, X0, fdec@PAGEOFF
	save_registers
	STP		X1, X0, [SP, #-16]!
	BL		_printf		
	ADD		SP, SP, #16 
	restore_registers  
	RET


; number conversions

word2number:	; converts ascii at word to number
			; IN X16

	ADRP	X0, zword@PAGE		
	ADD		X0, X0, zword@PAGEOFF


	save_registers
	MOV 	W1, #0
	MOV     W2, #0
	BL		_strtol
	restore_registers  
	
	STR		X0, [X16], #8

	; check for overflow
	B			chkoverflow
	RET

word2fnumber:	; converts ascii at word to float number
			; IN X16

	ADRP	X0, zword@PAGE		
	ADD		X0, X0, zword@PAGEOFF

	save_registers
	BL		_atof
	restore_registers  
	
	STR		D0, [X16], #8

	; check for overflow
	B			chkoverflow
	RET


; delay functions

dsleepz: ; sleep for ms		
	save_registers
	LDR		X0, [X16, #-8]
	MOV 	X1, #1000
	MUL 	X0, X0, X1
	BL		_usleep 
	restore_registers  
	SUB		X16, X16, #8	
	RET



; stack over/underflow checks

chkunderflow: ; check for stack underflow
 
	ADRP	X0, spu@PAGE		
	ADD		X0, X0, spu@PAGEOFF
	LDR		X0, [X0]
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
	LDR		X0, [X0]
	CMP		X16, X0
	b.lt	95f

	; reset stack
	reset_data_stack
	; report overfow
	
	B		sayoverflow

95:
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
	; BROKEN as we never stacked these in init.
finish: 
	MOV		X0, #0
	LDR		LR, [SP], #16
	LDP		X19, X20, [SP], #16
	RET

; WORD - ignores aliased words
collectwordnoalias:  ; byte ptr in x23, x22 
		; copy and advance byte ptr until space.

	STP		LR, X16, [SP, #-16]!
	STP		X13, XZR, [SP, #-16]!
	; reset word to zeros;
	BL		resetword

	MOV		W1, #0

10:	LDRB	W0, [X23], #1
	CMP		W0, #32
	b.eq	90f
	CMP		W0, #9
	B.eq	90f
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
		
90:	
	MOV		W0, #0X00
	STRB	W0, [X22], #1
	STRB	W0, [X22], #1
	 
  
95:	LDP		X13, XZR, [SP], #16
	LDP		LR, X16, [SP], #16
	RET




; this is the equivalent of WORD that reads the next
; word from the input, it will also swap the word with
; an alias word if it sees one.

collectword:  ; byte ptr in x23, x22 
		; copy and advance byte ptr until space.

	STP		LR, X16, [SP, #-16]!
	STP		X13, X12, [SP, #-16]!
	; reset word to zeros;
	BL		resetword

	MOV		W1, #0

10:	LDRB	W0, [X23], #1
	CMP		W0, #32
	b.eq	90f
	CMP		W0, #9
	B.eq	90f
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
		
90:	
	MOV		W0, #0X00
	STRB	W0, [X22], #1
	STRB	W0, [X22], #1
	
100: 

	; look for ALIAS, up to 4 levels.
	.rept 4

	save_registers
	ADRP	X1, alias_table@PAGE
	ADD		X1, X1, alias_table@PAGEOFF
	MOV		W2, #256
	MOV		W3, #32
	ADRP	X4, aliassort@PAGE
	add		X4, X4, aliassort@PAGEOFF
	ADRP	X0, zword@PAGE		
	ADD		X0, X0, zword@PAGEOFF

	BL		_bsearch
	restore_registers

 
	; alias not found
	CBZ		X0, 150f 

	MOV 	X12, X0 
	ADRP	X22, zword@PAGE		
	ADD		X22, X22, zword@PAGEOFF

	LDP		X0, X1, [X12, #16]
	STP		X0, X1, [X22]

	.endr

150: 
95:	LDP		X13, X12, [SP], #16
	LDP		LR, X16, [SP], #16
	RET


; process the word

get_word: ; get word from zword into x22
	ADRP	X22, zword@PAGE		
	ADD		X22, X22, zword@PAGEOFF
	LDR		X22, [X22]
	RET

get_word2: ; get word from zword into x22
	ADRP	X22, zword@PAGE		
	ADD		X22, X22, zword@PAGEOFF
	LDR		X22, [X22, #8]
	RET
	
empty_wordQ: ; is word empty?
	ADRP	X22, zword@PAGE		
	ADD		X22, X22, zword@PAGEOFF
	LDRB	W0, [X22]
	CMP		W0, #0 
	RET


; the dictionary has fixed start points for each letter.
; so the order of predefined words is always fixed.

start_point: ; finds where to start searching the dictionary
 
	ADRP	X22, zword@PAGE		
	ADD		X22, X22, zword@PAGEOFF
	
	LDRB	W0, 	[X22]	; first letter
	
	CMP		W0, #'#'	
	B.eq	150f

	CMP		W0, #'$'	
	B.eq	155f

	CMP		W0, #'('	
	B.ne	200f

150:
	ADRP	X28, hashdict@PAGE		
	ADD		X28, X28, hashdict@PAGEOFF	
	B		251f

155:
	ADRP	X28, dollardict@PAGE		
	ADD		X28, X28, dollardict@PAGEOFF	
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
	B		251f

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


; RESET try and RESET as much as possible to a sane state.
dresetz:
	CBNZ    X15, 10f	; only from interpreter level

	reset_data_stack
	reset_return_stack
	
 	ADRP	X0, sp1@PAGE		
	ADD		X0, X0, sp1@PAGEOFF
	MOV 	X1, #0
	MOV     X2, #512
	LSL		X2, X2,#3
	BL 		fill_mem
	
	ADRP	X0, rp1@PAGE		
	ADD		X0, X0, rp1@PAGEOFF
	MOV 	X1, #0
	MOV     X2, #512
	LSL		X2, X2,#3
	BL 		fill_mem

	;  disable tracing, X6 = 0
	MOV		X6, #0
	BL 		beloud

	; restore terminal
	save_registers
	MOV		X0, #0
	MOV		X1, #0
	ADRP	X2, saved_termios@PAGE	
	ADD		X2, X2, saved_termios@PAGEOFF
	BL		_tcsetattr
	restore_registers
  
	ADRP	X0, screen_textcolour@PAGE	
	ADD		X0, X0, screen_textcolour@PAGEOFF
	save_registers
	MOV     X2, #0
	MOV     X1, #0 ; reset colour
	STP		X1, XZR, [SP, #-16]!
	BL		_printf		
	ADD		SP, SP, #16 
	restore_registers  
	B 		input

10:
 
	RET



heapsize:
	LDR		X0, [X16, #-8]
	SUB 	X16, X16, #8
	save_registers
	BL		_malloc
	restore_registers
	ADRP	X1, heap_ptr@PAGE	
	ADD		X1, X1, heap_ptr@PAGEOFF
	STR		X0, [X1]

	RET

; these words initialize the stack sizes.

; the script can set the real stack size here
create_dstack:

	LDR		X0, [X16, #-8]
	SUB 	X16, X16, #8
	ADD		X0, X0, #32
	LSL		X0, X0, #3
	MOV 	X13, X0
	save_registers
	BL		_malloc
	restore_registers
	ADRP	X1, heap_ptr@PAGE	
	ADD		X1, X1, heap_ptr@PAGEOFF
	STR		X0, [X1]
	MOV 	X12, X0
	B 		make_stack


mini_stack: ; default tiny stack

	ADRP	X2, dsp@PAGE		
	ADD		X2, X2, dsp@PAGEOFF
	LDR 	X0, [X2]
	ADD		X0, X0, #256
	MOV		X16, X0
	RET

make_stack: ; X12 base, X13 size


	ADRP	X1, spu@PAGE			 
	ADD		X1, X1, spu@PAGEOFF
	MOV 	X0, X12
	ADD		X0, X0, #8*4
	STR		X0, [X1]

	MOV 	X0, X12
	ADD		X0, X0, #8*5

	ADRP	X1, sp1@PAGE			 
	ADD		X1, X1, sp1@PAGEOFF

	ADRP	X2, dsp@PAGE		
	ADD		X2, X2, dsp@PAGEOFF
	STR		X0, [X1]
	STR		X0, [X2]
	MOV		X16, X0

	ADD		X0, X12, X13
	SUB 	X0, X0, #8*40
	ADRP	X1, spo@PAGE		 
	ADD		X1, X1, spo@PAGEOFF
	STR		X0, [X1]			 


 

	RET


create_rstack:


	RET



;; Program Start

; we start running here

main:	

	; here we set some global values
	; the dictionary end, the data (parameter) stack
	; and the return stack.
	

init:	

	BL mini_stack
	
 
    save_registers
	BL _init_string_pool
	restore_registers

	; seed RNG
	BL 		randomize


	; save terminal state
	MOV		X0, #0
	ADRP	X1, saved_termios@PAGE	
	ADD		X1, X1, saved_termios@PAGEOFF
	BL		_tcgetattr ; saved TERMIOS
 

	ADRP	X27, dend@PAGE	;; <-- dictionary end
	ADD		X27, X27, dend@PAGEOFF
 

	ADRP	X0, rsp@PAGE		
	ADD		X0, X0, rsp@PAGEOFF
	LDR		X14, [X0]  ;; <-- return stack pointer to X14

	ADRP	X26, lsp@PAGE		
	ADD		X26, X26, lsp@PAGEOFF

	; give the interpreter some context
	MOV     X1, #51 ; (FORTH)
	LSL		X1, X1, #6	; / 64 
	ADD		X1, X1, X27
	MOV 	X0, #0

	STP		X0,  X1,  [X26],#16 ; data and word address
	STP		XZR, XZR, [X26],#16
	STP		XZR, XZR, [X26],#16
	STP		XZR, XZR, [X26],#16
	STP		XZR, XZR, [X26],#16
	; TROFF
	MOV		X6, #0

	MOV 	X0, #0 ; not appending
	ADRP	X1, append_ptr@PAGE		
	ADD		X1, X1, append_ptr@PAGEOFF
	STR		X0, [X1]

	; start of outer interpreter/compiler
	
	; load text from forth.forth

	BL 	dfrom_startup

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
	
	; look for BYE - to exit app.
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
	BL		_exit ; thats that.


	; outer interpreter (called QUIT in typical FORTH)
	; look for each word - when found, execute the words function	
	; if the word is not found check if it is a number, and if so stack it.
	; If we recognize a word we execute its code.

outer:	
	

interpret_word:	

	ADRP	X22, zword@PAGE		
	ADD		X22, X22, zword@PAGEOFF
	LDRB	W0, [X22, #1]
	CMP		W0, #0
	B.ne	fW1	

short_words:

	; we have a byte length word.

	; check if we need to enter the compiler loop.
	LDRB	W0, [X22]
	CMP		W0, #':'	; do we enter the compiler ?
	B.eq	enter_compiler

	; helps prevent crashes if there is a typo  
semicheck:
	CMP		W0, #';'	
	B.ne	endsemicheck
	ADRP	X0, tcomer39@PAGE
	ADD		X0, X0, tcomer39@PAGEOFF
	BL		sayit_err	 
	CBNZ	X15, semicheck2
	B 		endsemicheck
semicheck2: ; if compiler awake..
	BL		clean_last_word
endsemicheck:

	; check if we need to enter the compiler loop.
	CBZ		X15, fW1  	; compiler is not working on a word.
	LDRB	W0, [X22]
	CMP		W0, #']'	; do we re-enter the compiler ?
	B.eq	reenter_compiler

fW1:
	BL		start_point	
	B 		252f

251:	 
	SUB		X28, X28, #64
 

252: 
	ADRP	X22, zword@PAGE		
	ADD		X22, X22, zword@PAGEOFF
	LDR		X22, [X22]
	
	LDR		X21, [X28, #48]		; name field
	CMP		X21, #0				; end of list?
	B.eq	finish_list	
	CMP		X21, #-1			; undefined entry in list?
	b.eq	251b

	CMP		X21, X22		; is this our word?
	B.ne	251b			; that was 8 bytes..

	ADRP	X22, zword@PAGE		
	ADD		X22, X22, zword@PAGEOFF
	LDR		X22, [X22, #8]
	LDR		X21, [X28, #56] ; next 8
	CMP		X21, X22		;  
	B.ne	251b			; that was 16 bytes..



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

	; look for number

	ADRP	X22, zword@PAGE		
	ADD		X22, X22, zword@PAGEOFF


	; look for a number made of hex digits.
	; If found immediately push it onto our Data Stack

	LDRB	W0, [X22]
	CMP		W0, #'0'
	B.ne 	chkdec
	LDRB    W0, [X22, #1]
	CMP		W0, #'x' 
	B.ne	chkdec
	; we have a hex number in X22
	B 		litint
	; tolerate a negative number

chkdec:

	MOV 	X3, #0 ; not float

	LDRB	W0, [X22]
	CMP		W0, #'-'
	B.ne	positv
	ADD		X22, X22, #1
	LDRB	W0, [X22]

positv:

	CMP		W0, #'9'
	B.gt	exnum
	CMP		W0, #'0'
	B.lt	exnum

ntxtdigit:
 	ADD		X22, X22, #1
	LDRB	W0, [X22]
	CMP		W0, #0 ; end
	B.eq	digend
	CMP		W0, #'.'
	B.eq	fltsig

	CMP		W0, #'9'
	B.gt	exnum
	CMP		W0, #'0'
	B.lt	exnum
	
	B		ntxtdigit

fltsig: ; signal we have a float
	MOV 	X3, #-1
	B 		ntxtdigit

digend:

	CBZ 	X3, litint

litfloat:
 
	BL		word2fnumber
	B		advance_word

litint:
 
	BL		word2number
	B		advance_word

	
exnum:	; exit number
 
	
; ------- interpreter ends

	ADRP	X0, bequiet@PAGE
	ADD		X0, X0, bequiet@PAGEOFF
	MOV 	X1, #-1
	STR		X1, [X0]

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
	b.eq	next_half	

	b 		scan_next

next_half:
	LDR		X1, [X28, #56] ; its a word of 
	LDR		X0, [X22, #8]  ; two halves
	CMP		X1, X0
	B.eq	exit_compiler_word_exists; word exists


scan_next:
	CMP		X1, #0		; end of list?
	B.eq	exit_compiler ; no room in dictionary

	CMP		X1, #-1		; undefined entry in list?
	b.ne	try_next_word

	; undefined word found so build the word here

	; this is now the last_word word being built.
	ADRP	X1, last_word@PAGE		
	ADD		X1, X1, last_word@PAGEOFF
	STR		X28, [X1]

	copy_word_name

	CBZ		X6, faster_mode

	ADRP	X1, runintz@PAGE	
	ADD		X1, X1, runintz@PAGEOFF
	STR		X1, [X28, #8]
	B		set_word_runtime

faster_mode:

	ADRP	X1, fastrunintz@PAGE	; high level word.	
	ADD		X1, X1, fastrunintz@PAGEOFF
	STR		X1, [X28, #8]

set_word_runtime:

	ADRP	X8, here_ptr@PAGE	
	ADD		X8, X8, here_ptr@PAGEOFF
	LDR		X15, [X8]

	ADRP	X8, lasthere_ptr@PAGE	
	ADD		X8, X8, lasthere_ptr@PAGEOFF
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
	;LDR		X1, [X1]
	;SUB		X0, X15, X1
	;CMP		X0, #124
	;B.gt	exit_compiler_word_full

reenter_compiler:
	; get next word from line
	BL 		advancespaces
	BL 		collectword
	BL		get_word
	BL		empty_wordQ
	B.eq	exit_compiler_no_words

	BL		start_point

	ADRP	X22, zword@PAGE		
	ADD		X22, X22, zword@PAGEOFF
	LDRB	W0, [X22]
	CMP		W0, #';'	; do we exit the compiler now ?
	B.eq	exit_compiler
	CMP		W0, #'['	; do we exit the compiler now ?
	B.eq	advance_word ; back to interpret


find_word_token:

	LDR		X21, [X28, #48] ; name field 1
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

	ADRP	X22, zword@PAGE		
	ADD		X22, X22, zword@PAGEOFF
	LDR		X22, [X22, #8]
	LDR		X21, [X28, #56] ; name field 2
	CMP		X21, X22		; is this our word?
	B.ne	keep_finding_tokens
	
	; yes we have found our word
	;MOV		X0, #'.'
	;BL		X0emit


	; found word (at X28), get token.
	MOV		X1, X28
	MOV		X2, X27 ; dend
	SUB		X1, X1, X2
	LSR		X1, X1, #6	; * 64

	; X1 is token store halfword in [X15]
	STRH	W1, [X15]


	; if the word has a compile time action, we will call it.

	; check word type and skip if not primitive.
	; high level words use X15 as IP to run and we use it to compile.
	; preventing the use of high level words for compilation
	; a design flaw for sure.

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

	ADRP	X1, flatrunintz@PAGE	; high level word.	
	ADD		X1, X1, flatrunintz@PAGEOFF
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

	; words that assist the compiler 
	; must return 0, or -1 in X0 for status

	CMP		X0, #-1 ; failed compile time call.
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



	MOV     X3, #0 ; not float
20:
	; look for an integer number  
	; If found  store a literal in our word.

	ADRP	X22, zword@PAGE		
	ADD		X22, X22, zword@PAGEOFF

	LDRB	W0, [X22]
	CMP		W0, #'0'
	B.ne 	chkdec2
	LDRB    W0, [X22, #1]
	CMP		W0, #'x' 
	B.ne	chkdec2
	; we have a hex number in X22


	ADRP	X0, zword@PAGE		
	ADD		X0, X0, zword@PAGEOFF

	save_registers
	MOV 	W1, #0
	MOV     W2, #0
	BL		_strtol
	restore_registers  
	

	B 		check_number_size


chkdec2:

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
	B.eq	405f
	CMP		W0, #'9'
	B.gt	30f
	CMP		W0, #'0'
	B.lt	30f
	
	B		23b

405: ; we have a float
	MOV 	X3, #-1
	;MOV		X0, #'f'
	;BL		X0emit
	B 		23b 

24:
	;MOV		X0, #'*'
	;BL		X0emit

	CBZ 	X3, its_an_it
	save_registers
	ADRP	X0, zword@PAGE		
	ADD		X0, X0, zword@PAGEOFF
	BL 		_atof
	restore_registers 
	FMOV  	X0, D0	; float 
	B 		25f 	; process as long word
 
its_an_it:
	save_registers
	ADRP	X0, zword@PAGE		
	ADD		X0, X0, zword@PAGEOFF
	BL 		_atoi
	restore_registers 
 

check_number_size:
	
	; halfword numbers ~32k
	MOV		X3, #4000
	LSL		X3, X3, #3  
	MOV		X1, X0
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

	STR		X0, [X1]	; into the pool
	
	;MOV		X0, #'|'
	;BL		X0emit
	
	MOV		X0, #2 ; #LITL

	STRH	W0, [X15]
	ADD		X15, X15, #2

	STRH	W3, [X15]	; value
	ADD		X15, X15, #2

	B		compile_next_word

80:
	; found the literal

	;MOV		X0, #'-'
	;BL		X0emit

	MOV		X0, #2 ; #LITL
	STRH	W0, [X15]
	ADD		X15, X15, #2
	STRH	W3, [X15]	; value
	ADD		X15, X15, #2

	B		compile_next_word

30:	; exit number means word not found/not number
	;MOV		X0, #'?'
	;BL		X0emit
	B		exit_compiler_unrecognized


; word not recognized
exit_compiler_unrecognized:
	SUB		X14, X14, #16
	BL	saylb
	BL	sayword
	BL	sayrb
	BL	saynotfound
	BL	saycr
	BL	clean_last_word
	BL	dresetz


; literal pool  is full.
exit_compiler_pool_full:
	SUB		X14, X14, #16
	reset_data_stack
	BL		clean_last_word
	ADRP	X0, poolfullerr@PAGE	
	ADD		X0, X0, poolfullerr@PAGEOFF
	B		carry_on

exit_compiler_compile_time_err:
	SUB		X14, X14, #16
	reset_data_stack
	BL		clean_last_word
	; compile time function returned error
	ADRP	X0, tcomer9@PAGE	
	ADD		X0, X0, tcomer9@PAGEOFF
	B		carry_on


exit_compiler_unbalanced_loops:
	BL		clean_last_word
	BL		saycr
	BL		ddotsz
	BL		saycr
	BL		ddotrz
	BL		saycr
	reset_data_stack
	;
 	ADRP	X0, tcomer30@PAGE	
	ADD		X0, X0, tcomer30@PAGEOFF
	B		carry_on

exit_compiler_word_empty:
	SUB		X14, X14, #16
	reset_data_stack
	; : was followed by nothing which is an error.
	ADRP	X0, tcomer1@PAGE	
	ADD		X0, X0, tcomer1@PAGEOFF
	B		carry_on
	

exit_compiler_word_full:
	SUB		X14, X14, #16
	; TODO reset new  word, and stack
	reset_data_stack
	BL		clean_last_word
	BL		sayerrlength
	BL		beloud
	B		input ; 


exit_compiler_word_exists:
	SUB		X14, X14, #16
	reset_data_stack
	BL		err_word_exists
	BL		beloud
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
	
	ADRP	X8, here_ptr@PAGE	
	ADD		X8, X8, here_ptr@PAGEOFF
	STR		X15, [X8]

	ADRP	X8, lasthere_ptr@PAGE	
	ADD		X8, X8, lasthere_ptr@PAGEOFF
	LDR		X0, [X8]

	SUB		X0, X15, X0
	;BL		X0print
	;BL		saycompfin
	MOV 	X15, #0
 
	B		advance_word ; back to main loop

not_compiling:

; at this point we have not found this word
; display word not found as an error and reset

	BL		saycr
	BL		saylb
	BL		sayword
	BL		sayrb
	BL		saynotfound
	BL 		dresetz
	B		advance_word


carry_on:	; say the error loudly and resume interpreting
	BL		sayit
	BL 		beloud
	B		input ; back to immediate mode

exit_program:	

	MOV		X0, #0
	BL		_exit
	
	;brk #0xF000
	
190:	
	RET

; Return stack
; The word execution uses the machine stack pointer
; So the return stack is NOT actually used for return addresses
; it is used to stack a few LOOP addresses

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





; LOCALS accessors
; This is a LOCALS stack indexed by X26
; 0..  7 A
; 8.. 15 B
; 16..23 C
; 24..39
; 40..47
; 48..55
; 56..63
;
;

; specialized to read LOCALS as array

dlocalsvalz: ; X0=data, X1=word
	LDR		X2, [X16, #-8]	; X2 = index
	LDR		X1, [X1, #32]   ; X1 array size 
	CMP		X2, X1
	B.gt	darrayaddz_index_error
	LSL		X2, X2, #3 ; full word 8 bytes
	SUB		X1, X26, X2 ; LOCALS + index 
	SUB 	X1, X1, #8
	LDR		X0, [X1]
	STR		X0, [X16, #-8]	; value of data
	RET


dlocalsWvalz: ; X0=data, X1=word
	LDR		X2, [X16, #-8]	; X2 = index
	LDR		X1, [X1, #32]   ; X1 array size 
	CMP		X2, X1
	B.gt	darrayaddz_index_error
	LSL		X2, X2, #2 ; word 4
	SUB		X1, X26, X2 ; LOCALS + index 
	SUB 	X1, X1, #4
	LDR		W0, [X1]		; word
	STR		X0, [X16, #-8]	; value of data
	RET


dlocaz:	; LOCAL A
	LDR		X0, [X26, #-8]	
	STR		X0, [X16], #8
	RET

dlocasz: 
	LDR		X0,	[X16, #-8]!
	STR		X0, [X26, #-8]
	RET

dlocasppz:
	LDR		X0, [X26, #-8]	
	ADD		X0, X0, #1
	STR		X0, [X26, #-8]
	RET

dlocbz:	; LOCAL B
	LDR		X0, [X26, #-16]	
	STR		X0, [X16], #8
	RET

dlocbsz:
	LDR		X0,	[X16, #-8]!
	STR		X0, [X26, #-16]
	RET

dlocbsppz:
	LDR		X0, [X26, #-16]	
	ADD		X0, X0, #1
	STR		X0, [X26, #-16]
	RET


dloccz:	; LOCAL C
	LDR		X0, [X26, #-24]	
	STR		X0, [X16], #8
	RET

dloccsz:
	LDR		X0,	[X16, #-8]!
	STR		X0, [X26, #-24]
	RET

dloccsppz:
	LDR		X0, [X26, #-24]	
	ADD		X0, X0, #1
	STR		X0, [X26, #-24]
	RET



dlocdz:	; LOCAL D
	LDR		X0, [X26, #-32]	
	STR		X0, [X16], #8
	RET

dlocdsz:
	LDR		X0,	[X16, #-8]!
	STR		X0, [X26, #-32]
	RET

dlocdsppz:
	LDR		X0, [X26, #-32]	
	ADD		X0, X0, #1
	STR		X0, [X26, #-32]
	RET


dlocez:	; LOCAL E
	LDR		X0, [X26, #-40]	
	STR		X0, [X16], #8
	RET

dlocesz:
	LDR		X0,	[X16, #-8]!
	STR		X0, [X26, #-40]
	RET

dlocfz:	; LOCAL F
	LDR		X0, [X26, #-48]	
	STR		X0, [X16], #8
	RET

dlocfsz:
	LDR		X0,	[X16, #-8]!
	STR		X0, [X26, #-48]
	RET

dlocgz:	; LOCAL G
	LDR		X0, [X26, #-56]	
	STR		X0, [X16], #8
	RET

dlocgsz:
	LDR		X0,	[X16, #-8]!
	STR		X0, [X26, #-56]
	RET

dlochz:	; LOCAL H
	LDR		X0, [X26, #-64]	
	STR		X0, [X16], #8
	RET

dlochsz:
	LDR		X0,	[X16, #-8]!
	STR		X0, [X26, #-64]
	RET

; SELF and CODE pointers
dlociz:	;   
	LDR		X0, [X26, #-72]	
	STR		X0, [X16], #8
	RET

dlochiz:
	LDR		X0,	[X16, #-8]!
	STR		X0, [X26, #-72]
	RET


dlocjz:	;  CODE 
	LDR		X0, [X26, #-80]	
	STR		X0, [X16], #8
	RET

dlochjz:
	LDR		X0,	[X16, #-8]!
	STR		X0, [X26, #-80]
	RET


; SIMPLE non standard single WORD repeater

; n TIMESDO word 
; execute single word, n times, as quickly as we can.

; compiled times do
dtimescz: 

	STP		LR,  X15, [SP, #-16]!

	LDP		X3, X1, [X16,#-16]		; X1 word base, X3 count  
	SUB 	X16, X16, #16

	LDR		X0, [X1]		; words data
	LDR		X2, [X1, #8]	; exec address

10:
	; unrolling the loop speeds it up
	.rept	32

	STP		X0, X1,  [SP, #-16]!
	STP		X2, X3,  [SP, #-16]!

	BLR		X2 ; call function with X0=data, X1=address

	LDP		X2, X3, [SP], #16
	LDP 	X0, X1, [SP], #16

	SUB 	X3, X3,	#1
	CBZ		X3, 20f 
	.endr

	B 		10b

20:
 	LDP 	LR, X15, [SP], #16
	MOV     X0, #0
	RET


dtimesdoz:

100:	
	save_registers_not_stack
	
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

	LDR		X21, [X28, #56] ; next 8
	BL		get_word2
	CMP		X21, X22		;  
	B.ne	170f			; that was 16 bytes..


	; found word in X28, stack address of word

	LDR		X3, [X16,#-8] ; count to X3
	SUB 	X16, X16, #8
	MOV     X1, X28   ; word base
	LDR		X0, [X28] ; data (argument)
	LDR		X2, [X28, #8]  ; X2 to call
	CBZ		X2,  190f

; unrolling loop speeds it up

	.rept	32

	STP		X0, X1,  [SP, #-16]!
	STP		X2, X3,  [SP, #-16]!

	BLR		X2 ; call function with X0=data, X1=address

	LDP		X2, X3, [SP], #16
	LDP 	X0, X1, [SP], #16

	SUB 	X3, X3,	#1
	CBZ		X3, 20f 
	.endr

	B 		10b

20:
	restore_registers_not_stack

	RET

170:	; next word in dictionary
	SUB		X28, X28, #64
	B		120b

190:	 

	restore_registers_not_stack
	MOV		X0, #-1
	RET

; compile timesdo
dtimesdoc:

100:	
	STP		LR,  XZR, [SP, #-16]!
	
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

	LDR		X21, [X28, #56] ; next 8
	BL		get_word2
	CMP		X21, X22		;  
	B.ne	170f			; that was 16 bytes..


	; found word in X28, stack address of word

	LDR		X3, [X16,#-8] ; count to X3
	SUB 	X16, X16, #8
	MOV     X1, X28   ; word base
	CBZ		X2,  190f
  
	MOV 	X0, X1
	BL		longlitit
	ADD		X15, X15, #2
	MOV 	W0, #47 ;(TIMESDO)
	STRH	W0, [X15] 
 

	LDP		LR, X16, [SP], #16
	RET

170:	; next word in dictionary
	SUB		X28, X28, #64
	B		120b

190:	 

	LDP		LR, X16, [SP], #16
	MOV		X0, #-1
	RET



; DO LOOP  
; The definite loops
; Not compliant with standard FORTH.
;

; DO .. LOOP, +LOOP uses the return stack when compiling.
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


stckqdoargsz: ; (?DO)

	STP		LR,  X12, [SP, #-16]!
	MOV		X12, X15
	; Get my arguments
	LDP 	X0, X1,  [X16, #-16]  
	SUB		X16, X16, #16
	SUB 	X0, X0, #1

	; Stack arguments 21, literal address, start, limit
	
	MOV		X2,  #21 ; DO
	STP		X2,  X12, [X14], #16
	STP		X0,  X1,  [X14], #16

	LDP		LR, X12, [SP], #16

	RET



; as above but includes skip forwards

dinvalintz:
	CBZ     X15, dinterp_invalid
	RET

ddoerz:
	CBZ     X15, dinterp_invalid
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

	; stack loop arguments for LOOP and I,J,K to read
	; Stack arguments 21, literal address, start, limit
	MOV		X2,  #21 ; DO
	STP		X2,  X12, [X14], #16
	STP		X0,  X1,  [X14], #16

	; Check my loop arguments
	CMP		X0, X1
	B.lt	skip_do_loop 
	; if no need to loop skip

	B		200f



ddowndoerz:
	CBZ     X15, dinterp_invalid
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
	; if no need to loop skip

	B		200f


dochecker:

// only in the case where the arguments mean no loop needed

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
	CBZ     X15, dinterp_invalid
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
	CBZ     X15, dinterp_invalid
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
	CBZ     X15, dinterp_invalid
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

	LDP		X14, XZR, [SP], #16
	LDP		LR, X15, [SP], #16	; unstack word
	ADRP	X0, tcomer18@PAGE	
	ADD		X0, X0, tcomer18@PAGEOFF
	B		sayit
	RET	

; compile in DO LOOP, +LOOP, DOWNDO -LOOP

dqoerc:
	MOV	X0, #26 ; 
	STRH W0, [X15] ; replace code
	RET
	

doerc:
	MOV	X0, #21 ; 
	STRH W0, [X15] ; replace code
	RET
	

ddownerc:
	MOV	X0, #22 ; 
	STRH W0, [X15] ; replace code
	RET

// check for LEAVE at COMPILE TIME 
dloopc:		; COMPILE time LOOP

	MOV	X0, #19
	STRH W0, [X15] ; replace code

	LDP		X1, X12,  [X14, #-16] ; X5 is branch
	CMP		X1, #13 ; (LEAVE) we MAY have a leave to patch
	B.ne 	20f

	SUB		X0, X15, X12 ; dif between LOOP and (LEAVE).
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
	CBZ     X15, dinterp_invalid
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
 

; : t2 BEGIN 1+ DUP DUP . CR 10 >  UNTIL .' fini '  ;

duntilz: ; UNTIL runtime
	CBZ     X15, dinterp_invalid
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
170:	
	RET

	; true I am finishing
180:
	SUB		X14, X14, #16
	RET 

 

duntilc: ; COMPILE in UNTIL


	STP		LR,  X12, [SP, #-16]!
	
	LDP		X1, X12,  [X14, #-16] ; X5 is branch
	CMP		X1, #13 ; (LEAVE) we MAY have a leave to patch
	B.ne 	20f

	; FIX UP (LEAVE)
	SUB		X0, X15, X12 ; dif between REPEAT/AGAIN and (LEAVE).
	ADD		X0, X0, #2
	STRH	W0, [X12]	 ; store that

20:
	SUB		X14, X14, #16
	CMP		X1, #'B' ; was that a BEGIN we saw?
	B.eq 	30f
	
	; check under leave
	LDP		X0, XZR,  [X14, #-16] ; X5 is branch
	SUB		X14, X14, #16
	CMP		X0, #'B' ; BEGIN - WE MUST HAVE a BEGIN or error
	B.ne	190f

30:
 
	MOV		X0, #0
	LDP		LR, X12, [SP], #16	
 
	RET

190:	; UNTIL needs BEGIN

	ADRP	X0, tcomer23@PAGE	
	ADD		X0, X0, tcomer23@PAGEOFF
	BL		sayit
	LDP		LR, X12, [SP], #16	
	MOV		X0, #-1
	RET



; : t3 BEGIN  1 + DUP 10 < WHILE DUP . CR REPEAT ;
dwhilez: ; WHILE needs a foward branch to REPEAT
	CBZ     X15, dinterp_invalid
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
170:
	RET 

180:
 
 	ADD		X15, X15, #2
	RET

190:	; UNTIL/AGAIN needs BEGIN

	ADRP	X0, tcomer23@PAGE	
	ADD		X0, X0, tcomer23@PAGEOFF
	BL		sayit
	LDP		X14, XZR, [SP], #16
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
	CBZ     X15, dinterp_invalid
	do_trace

	LDP		X2, X5,  [X14, #-16] ; X5 is branch
	CMP		X2, #'B' ;BEGIN
	B.ne	190f

	MOV		X15, X5	; back we go
170:
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
	SUB 	X14, X14, #16

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

	CBZ     X15, dinterp_invalid

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
	SUB		X14, X14, #16
	CMP		X1, #'B' ; was that a BEGIN we saw?
	B.eq 	30f
	
	; check under leave
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
; : t2 BEGIN 1+ DUP 10 > IF LEAVE THEN DUP . CR AGAIN .' fini ' ;
; : t3 BEGIN 1+ DUP 10 > IF EXIT THEN DUP . CR AGAIN .' fini ' ;

dleavez:	; just LEAVE the enclosing loop
	CBZ     X15, dinterp_invalid
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
170:
	RET


100: ; LOOP exit

	SUB		X14, X14, #32
	LDRH	W0, [X15, #2]
	ADD		X15, X15, X0 ; change IP
	RET



190:	; not leaving a loop? leave whole word.
	do_trace
	LDP		LR, X5, [SP], #16	
	LDP		X14, XZR, [SP], #16
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
	LDR		X0, [X0]
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


ddepthrz: 

	ADRP	X0, rpu@PAGE		
	ADD		X0, X0, rpu@PAGEOFF
	CMP		X14, X0
	b.gt	50f	

	; reset stack we are under
	reset_return_stack
	
50:
	ADRP	X8, rsp@PAGE		
	ADD		X8, X8, rsp@PAGEOFF
	LDR		X0, [X8]
	SUB		X0, X14,X0

	LSR		X0, X0, #3
	STR		X0, [X16], #8	
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


	ADRP	X8, lasthere_ptr@PAGE	
	ADD		X8, X8, lasthere_ptr@PAGEOFF
	LDR		X0, [X8]

	ADRP	X8, here_ptr@PAGE	
	ADD		X8, X8, here_ptr@PAGEOFF
	STR		X0, [X8]
	
	MOV 	X15, #0 ; we failed. compilation stopped.

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
	

;; Introspection and inspection
;; displays the layout of a word, to see what the compiler did.


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



12010:

	ADRP	X2, dvaluez@PAGE		
	ADD		X2, X2, dvaluez@PAGEOFF
	LDR		X0, [X28, #8]
	CMP		X0, X2
	B.ne	12020f

	ADRP	X0, word_desc8@PAGE		
	ADD		X0, X0, word_desc8@PAGEOFF
	BL		sayit

	BL		saylb
	
	LDR		X0, [X28]
	LDR		X0, [X0]

	BL		X0addrpr
	BL		sayrb


	B		12095f


12020:

	; anotate the data word
	ADRP	X2, dCarrayaddz@PAGE		
	ADD		X2, X2, dCarrayaddz@PAGEOFF
	LDR		X0, [X28, #8]
	CMP		X0, X2
	B.ne	12040f

	ADRP	X0, word_desc17@PAGE		
	ADD		X0, X0, word_desc17@PAGEOFF
	BL		sayit

	LDR		X0, [X28, 32]
	BL		X0halfpr

	B		12095f

12030:

	ADRP	X2, dHWarrayaddz@PAGE		
	ADD		X2, X2, dHWarrayaddz@PAGEOFF
	LDR		X0, [X28, #8]
	CMP		X0, X2
	B.ne	12040f

	ADRP	X0, word_desc16@PAGE		
	ADD		X0, X0, word_desc16@PAGEOFF
	BL		sayit

	LDR		X0, [X28, 32]
	BL		X0halfpr

	B		12095f


12040:

	ADRP	X2, dWarrayaddz@PAGE		
	ADD		X2, X2, dWarrayaddz@PAGEOFF
	LDR		X0, [X28, #8]
	CMP		X0, X2
	B.ne	12050f

	ADRP	X0, word_desc15@PAGE		
	ADD		X0, X0, word_desc15@PAGEOFF
	BL		sayit

	LDR		X0, [X28, 32]
	BL		X0halfpr

	B		12095f



12050:


	ADRP	X2, darrayaddz@PAGE		
	ADD		X2, X2, darrayaddz@PAGEOFF
	LDR		X0, [X28, #8]
	CMP		X0, X2
	B.ne	12060f

	ADRP	X0, word_desc14@PAGE		
	ADD		X0, X0, word_desc14@PAGEOFF
	BL		sayit

	LDR		X0, [X28, 32]
	BL		X0halfpr

	B		12095f

12060:

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

	ADRP	X2, flatrunintz@PAGE		
	ADD		X2, X2, flatrunintz@PAGEOFF
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
; returns address of data space
; which may be updated with ALLOT

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

	copy_word_name
 

	ADRP	X1, dvaraddz@PAGE	; high level word traceable	
	ADD		X1, X1, dvaraddz@PAGEOFF
	STR		X1, [X28, #8]
 

160:
	ADD		X1, X28, #32
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

	copy_word_name

	; variable code
	ADRP	X1, dvaraddz@PAGE	; high level word.	
	ADD		X1, X1, dvaraddz@PAGEOFF
	STR		X1, [X28, #8]

	ADD		X1, X28, #32
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


; FILLs

dfillz:

	LDR		X1, [X16, #-8]
	LDR		X2, [X16, #-16]
	LDR		X0, [X16, #-24]
	SUB		X16, X16, #24


; fill block of memory
; Copyright (c) 2016-2020, ARM Limited and Contributors. All rights reserved. BSD.

; X1 = fill; X2=count; X0=address 
fill_mem:

	cbz	W2, exit		 
	MOV	X3, X0			 
	tst	X0, #7
	b.eq	aligned			 

unaligned:
	strb	W1, [X3], #1
	subs	W2, W2, #1
	b.eq	exit			 
	tst	X3, #7
	b.ne	unaligned		 

/* 8-bytes aligned */
aligned:
	cbz	X1, X1_zero
	bfi	W1, W1, #8, #8		 
	bfi	W1, W1, #16, #16
	bfi	X1, X1, #32, #32


X1_zero:
	ands	W4, W2, #~0X3f
	b.eq	less_64
 

write_64:
	.rept	4
	stp	X1, X1, [X3], #16	/* write 64 bytes in a loop */
	.endr
	subs	W4, W4, #64
	b.ne	write_64
	ands	W2, W2, #0X3f
	b.eq	exit			/* exit if 0 */

	
less_64:tbz	W2, #5, less_32		/* < 32 bytes */
	stp	X1, X1, [X3], #16	/* write 32 bytes */
	stp	X1, X1, [X3], #16
	ands	W2, W2, #0X1f
	b.eq	exit

less_32:tbz	W2, #4, less_16		/* < 16 bytes */
	stp	X1, X1, [X3], #16	/* write 16 bytes */
	ands	W2, W2, #0xf
	b.eq	exit

less_16:tbz	W2, #3, less_8		/* < 8 bytes */
	str	X1, [X3], #8		/* write 8 bytes */
	ands	W2, W2, #7
	b.eq	exit

less_8:	tbz	W2, #2, less_4		/* < 4 bytes */
	str	W1, [X3], #4		/* write 4 bytes */
	ands	W2, W2, #3
	b.eq	exit

less_4:	tbz	W2, #1, less_2		/* < 2 bytes */
	strh	W1, [X3], #2		/* write 2 bytes */
	tbz	W2, #0, exit
less_2:	strb	W1, [X3]		/* write 1 byte */
exit:	ret

 


;; ARRAYS 


; MAPARRAY word array newarray
; exec word against every element in array
; creating new array

dmaparray:

RET


; n FILLARRAY array_name
dfillarrayz: ; RUNTIME at command line

; get word address
100:	
	save_registers
	
	BL		advancespaces
	BL		collectword

 
	BL		empty_wordQ
	B.eq	190f

	BL		start_point

120:
	LDR		X21, [X28, #48] ; name field

	CMP		X21, #0		    ; end of list?
	B.eq	195f			; not found 
	CMP		X21, #-1		; undefined entry in list?
	b.eq	170f

	BL		get_word
	LDR		X21, [X28, #48] ; name field
	CMP		X21, X22		; is this our word?
	B.ne	170f

	LDR		X21, [X28, #56] ; next 8
	BL		get_word2
	CMP		X21, X22		;  
	B.ne	170f			; that was 16 bytes..


	; found word 
	restore_registers

	MOV 	X1, 	X28			; base
	LDR		X0, 	[X28]  		; data pointer
	LDR		X2, 	[X28, #8]	; runtime code
	LDR		X3,		[X28, #32]  ; index size


	ADRP	X8, darrayaddz@PAGE		
	ADD		X8, X8, darrayaddz@PAGEOFF
	CMP		X2, X8
	B.eq	darrayaddz_fill

	ADRP	X8, darrayvalz@PAGE		
	ADD		X8, X8, darrayvalz@PAGEOFF
	CMP		X2, X8
	B.eq	darrayaddz_fill

	ADRP	X8, dWarrayaddz@PAGE		
	ADD		X8, X8, dWarrayaddz@PAGEOFF
	CMP		X2, X8
	B.eq	dWarrayaddz_fill
	
	ADRP	X8, dWarrayvalz@PAGE		
	ADD		X8, X8, dWarrayvalz@PAGEOFF
 	CMP		X2,	X8
	B.eq	dWarrayaddz_fill


	ADRP	X8, dHWarrayaddz@PAGE		
	ADD		X8, X8, dHWarrayaddz@PAGEOFF
	CMP		X2,	X8
	B.eq	dHWarrayaddz_fill


	ADRP	X8, dHWarrayvalz@PAGE		
	ADD		X8, X8, dHWarrayvalz@PAGEOFF
 	CMP		X2,	X8
	B.eq	dHWarrayaddz_fill

	ADRP	X8, dCarrayaddz@PAGE		
	ADD		X8, X8, dCarrayaddz@PAGEOFF
 	CMP		X2,	X8
	B.eq	dCarrayaddz_fill

	ADRP	X8, dCarrayvalz@PAGE		
	ADD		X8, X8, dCarrayvalz@PAGEOFF
 	CMP		X2,	X8
	B.eq	dCarrayaddz_fill

	ADRP	X8, dlocalsvalz@PAGE		
	ADD		X8, X8, dlocalsvalz@PAGEOFF
 	CMP		X2,	X8
	B.eq	dlocalsvalz_fill


	ADRP	X8, dlocalsWvalz@PAGE		
	ADD		X8, X8, dlocalsWvalz@PAGEOFF
 	CMP		X2,	X8
	B.eq	dlocalsWvalz_fill


	ADRP	X0, tcomer34@PAGE		
	ADD		X0, X0, tcomer34@PAGEOFF
	B 		sayit 

170:	; next word in dictionary
	SUB		X28, X28, #64
	B		120b



dfillarrayc: ; COMPILE array fill operations

; get word address
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
	B.eq	195f			; not found 
	CMP		X21, #-1		; undefined entry in list?
	b.eq	170f

	BL		get_word
	LDR		X21, [X28, #48] ; name field
	CMP		X21, X22		; is this our word?
	B.ne	170f

	LDR		X21, [X28, #56] ; next 8
	BL		get_word2
	CMP		X21, X22		;  
	B.ne	170f			; that was 16 bytes..


	; found word 
	restore_registers

	MOV 	X1, 	X28			; base
	LDR		X0, 	[X28]  		; data pointer
	LDR		X2, 	[X28, #8]	; runtime code
	LDR		X3,		[X28, #32]  ; index size


	ADRP	X8, darrayaddz@PAGE		
	ADD		X8, X8, darrayaddz@PAGEOFF
	CMP		X2, X8
	B.eq	compile_darrayaddz_fill

	ADRP	X8, dlocalsvalz@PAGE		
	ADD		X8, X8, dlocalsvalz@PAGEOFF
	CMP		X2, X8
	B.eq	compile_localsvalz_fill

	ADRP	X8, dlocalsWvalz@PAGE		
	ADD		X8, X8, dlocalsWvalz@PAGEOFF
	CMP		X2, X8
	B.eq	compile_localsWvalz_fill


	ADRP	X8, darrayvalz@PAGE		
	ADD		X8, X8, darrayvalz@PAGEOFF
 	CMP		X2,	X8
	B.eq	compile_darrayaddz_fill

	ADRP	X8, dWarrayaddz@PAGE		
	ADD		X8, X8, dWarrayaddz@PAGEOFF
	CMP		X2, X8
	B.eq	compile_dWarrayaddz_fill


	ADRP	X8, dWarrayvalz@PAGE		
	ADD		X8, X8, dWarrayvalz@PAGEOFF
	CMP		X2, X8
	B.eq	compile_dWarrayaddz_fill

	ADRP	X8, dHWarrayaddz@PAGE		
	ADD		X8, X8, dHWarrayaddz@PAGEOFF
	CMP		X2,	X8
	B.eq	compile_dHWarrayaddz_fill
	
	ADRP	X8, dHWarrayvalz@PAGE		
	ADD		X8, X8, dHWarrayvalz@PAGEOFF
	CMP		X2,	X8
	B.eq	compile_dHWarrayaddz_fill


	ADRP	X8, dCarrayaddz@PAGE		
	ADD		X8, X8, dCarrayaddz@PAGEOFF
 	CMP		X2,	X8
	B.eq	compile_dCarrayaddz_fill


	ADRP	X8, dCarrayvalz@PAGE		
	ADD		X8, X8, dCarrayvalz@PAGEOFF
 	CMP		X2,	X8
	B.eq	compile_dCarrayaddz_fill


	ADRP	X0, tcomer34@PAGE		
	ADD		X0, X0, tcomer34@PAGEOFF
	B		sayit_err 
 

170:	; next word in dictionary
	SUB		X28, X28, #64
	B		120b


195: 
	ADRP	X0, tcomer35@PAGE		
	ADD		X0, X0, tcomer35@PAGEOFF
	BL 		sayit 
	restore_registers
	RET

190:	; error out 
	ADRP	X0, tcomer34@PAGE		
	ADD		X0, X0, tcomer34@PAGEOFF
	BL 		sayit 
	restore_registers
	MOV		X0, #-1

	RET


;;; ARRAY 1 dimensional cells

darrayvalz: ; X0=data, X1=word
	LDR		X2, [X16, #-8]	; X2 = index
	LDR		X1, [X1, #32]   ; X1 array size 
	CMP		X2, X1
	B.gt	darrayaddz_index_error
	LSL		X2, X2, #3 ; full word 8 bytes
	ADD		X1, X0, X2 ; data + index 
	LDR		X0, [X1]
	STR		X0, [X16, #-8]	; value of data
	RET

;; ( n -- address )
darrayaddz: ; X0=data, X1=word
	LDR		X2, [X16, #-8]	; X2 = index
	LDR		X1, [X1, #32]   ; X1 array size 
	CMP		X2, X1
	B.gt	darrayaddz_index_error
	LSL		X2, X2, #3 ; full word 8 bytes
	ADD		X1, X0, X2 ; data + index 
	STR		X1, [X16, #-8]	; address of data
	RET

darrayaddz_index_error:
	STR		XZR, [X16, #-8]	; null.. trapped by ! and @
	ADRP	X0, tcomer32@PAGE	
	ADD		X0, X0, tcomer32@PAGEOFF
	B		sayit_err
	RET


dA1FILLAz:	; fetch stacked base and index

	LDP		X0,	X3, [X16, #-16]	 
	SUB  	X16, X16, #16


darrayaddz_fill: ; X1 base, X0 data, X2 runtime, X3 index
	LDR		X1,	[X16, #-8]	; fill with
	SUB  	X16, X16, #8
	LSL		X3, X3, #1
	ADD		X3, X3, #2

10:
	SUB		X3, X3, #1
	STP		X1, X1,	[X0], #16

	CBNZ	X3, 10b 
	MOV		X2, #0
	RET


; LOCALS are a special case, they are referenced by a stack on X26

dALFILLAz:	; fetch stacked base and index

	LDP		X0,	X3, [X16, #-16]	 
	SUB  	X16, X16, #16


dlocalsvalz_fill:  
	LDR		X1,	[X16, #-8]	; fill with
	SUB  	X16, X16, #8
	SUB 	X26, X26, #64		; it is always this size
	STP		X1, X1, [X26],#16   ; fill
	STP		X1, X1, [X26],#16
	STP		X1, X1, [X26],#16
	STP		X1, X1, [X26],#16
	RET


dWALFILLAz:	; fetch stacked base and index

	LDP		X0,	X3, [X16, #-16]	 
	SUB  	X16, X16, #16


dlocalsWvalz_fill:  ; (32 bit)
	LDR		X1,	[X16, #-8]	; fill with
	SUB  	X16, X16, #8
	SUB 	X26, X26, #64		; it is always this size
	STP		W1, W1, [X26],#8  ; fill w pair
	STP		W1, W1, [X26],#8
	STP		W1, W1, [X26],#8
	STP		W1, W1, [X26],#8
	STP		W1, W1, [X26],#8  ; fill w pair
	STP		W1, W1, [X26],#8
	STP		W1, W1, [X26],#8
	STP		W1, W1, [X26],#8
	RET


; WORD 32 bit array

dWarrayvalz: ; X0=data, X1=word

 	LDR		X2, [X16, #-8]	; X2 = index
	LDR		X1, [X1, #32]   ; X1 array size 
	CMP		X2, X1
	B.gt	darrayaddz_index_error
	LSL		X2, X2, #2 ;  word 4 bytes

	ADD		X1, X0, X2 ; data + index 
	LDR		W0, [X1]
	STR		X0, [X16, #-8]	; value of data
	RET


;; ( n -- address )
dWarrayaddz: ; X0=data, X1=word
	LDR		X2, [X16, #-8]	; X2 = index
	LDR		X1, [X1, #32]   ; X1 array size 
	CMP		X2, X1
	B.gt	darrayaddz_index_error
	LSL		X2, X2, #2 ;  word 4 bytes
	ADD		X1, X0, X2 ; data + index 
	STR		X1, [X16, #-8]	; address of data
	RET

dWarrayaddz_index_error:
	STR		XZR, [X16, #-8]	; null.. trapped by ! and @
	ADRP	X0, tcomer32@PAGE	
	ADD		X0, X0, tcomer32@PAGEOFF
	B		sayit
	RET


dW1FILLAz:

	LDP		X0,	X3, [X16, #-16]	 
	SUB  	X16, X16, #16

dWarrayaddz_fill: ; X1 base, X0 data, X2 runtime, X3 index

	LDR		X1,	[X16, #-8]	; fill with
	SUB  	X16, X16, #8

10:
	STR		W1,	[X0], #4
	SUB		X3, X3, #1
	CBNZ	X3, 10b 
	MOV		X2, #0
	RET



;  HALF WORD 16 bit array


dHWarrayvalz: ; X0=data, X1=word

 	LDR		X2, [X16, #-8]	; X2 = index
	LDR		X1, [X1, #32]   ; X1 array size 
	CMP		X2, X1
	B.gt	darrayaddz_index_error
	LSL		X2, X2, #1 ;  word 4 bytes

	ADD		X1, X0, X2 ; data + index 
	LDRH	W0, [X1]
	STR		X0, [X16, #-8]	; value of data
	RET


;; ( n -- address )
dHWarrayaddz: ; X0=data, X1=word
	LDR		X2, [X16, #-8]	; X2 = index
	LDR		X1, [X1, #32]   ; X1 array size 
	CMP		X2, X1
	B.gt	darrayaddz_index_error
	LSL		X2, X2, #1 ;  HW 2 BYTES
	ADD		X1, X0, X2 ; data + index 
	STR		X1, [X16, #-8]	; address of data
	RET

dHWarrayaddz_index_error:
	STR		XZR, [X16, #-8]	; null.. trapped by ! and @
	ADRP	X0, tcomer32@PAGE	
	ADD		X0, X0, tcomer32@PAGEOFF
	B		sayit
	RET


dHW1FILLAz:

	LDP		X0,	X3, [X16, #-16]	 
	SUB  	X16, X16, #16

dHWarrayaddz_fill: ; X1 base, X0 data, X2 runtime, X3 index

	LDRH	W1,	[X16, #-8]	; fill with
	SUB  	X16, X16, #8

10:
	STRH	W1,	[X0], #2
	SUB		X3, X3, #1
	CBNZ	X3, 10b 
	MOV		X2, #0
	RET


; BYTE 8 bit array

dCarrayvalz: ; X0=data, X1=word
	LDR		X2, [X16, #-8]	; X2 = index
	LDR		X1, [X1, #32]   ; X1 array size 
	CMP		X2, X1
	B.gt	darrayaddz_index_error
	LSL		X2, X2, #3 ; full word 8 bytes
	ADD		X1, X0, X2 ; data + index 
	LDRB	W0, [X1]
	STR		X0, [X16, #-8]	; value of data
	RET

;; ( n -- address )
dCarrayaddz: ; X0=data, X1=word
	LDR		X2, [X16, #-8]	; X2 = index
	LDR		X1, [X1, #32]   ; X1 array size 
	CMP		X2, X1
	B.gt	darrayaddz_index_error
	ADD		X1, X0, X2 ; data + index 
	STR		X1, [X16, #-8]	; address of data
	RET

dCarrayaddz_index_error:
	STR		XZR, [X16, #-8]	; null.. trapped by ! and @
	ADRP	X0, tcomer32@PAGE	
	ADD		X0, X0, tcomer32@PAGEOFF
	B		sayit
	RET

; appends values to the LAST c array
dcarraycommafromstack:
	LDR		X2, [X16, #-8]
	SUB 	X16, X16, #8
	LDR		X3, [X1, #40] ; used as offset
	LDR 	X4, [X1, #32]
	CMP		X3, X4 
	B.ge	darrayaddz_index_error
	LDR		X4, [X1] ; data 
	ADD		X0, X3, X4 
	STRB 	W2, [X0]
	ADD		X3, X3, #1
	STR 	X3, [X1, #40]	
	RET

; appends values to the LAST  array
darraycommafromstack:

	LDR		X2, [X16, #-8]
	SUB 	X16, X16, #8
	LDR		X3, [X1, #40] ; used as offset
	LDR 	X4, [X1, #32]
	CMP		X3, X4 
	B.ge	darrayaddz_index_error
	LDR		X4, [X1] ; data 
	LSL 	X3, X3, #3 ; * 8
	ADD		X0, X3, X4 
	STR 	X2, [X0]
	LSR 	X3, X3, #3  
	ADD		X3, X3, #1
	STR 	X3, [X1, #40]	
	RET


dHWarraycommafromstack:
 	LDR		X2, [X16, #-8]
	SUB 	X16, X16, #8
	LDR		X3, [X1, #40] ; used as offset
	LDR 	X4, [X1, #32]
	CMP		X3, X4 
	B.ge	darrayaddz_index_error
	LDR		X4, [X1] ; data 
	LSL 	X3, X3, #1 ; 
	ADD		X0, X3, X4 
	STRH  	W2, [X0]
 	LSR 	X3, X3, #1  
    ADD		X3, X3, #1
	STR 	X3, [X1, #40]	
	RET


dWarraycommafromstack:
 	LDR		X2, [X16, #-8]
	SUB 	X16, X16, #8
	LDR		X3, [X1, #40] ; used  s offset
	LDR 	X4, [X1, #32]
	CMP		X3, X4 
	B.ge	darrayaddz_index_error
	LDR		X4, [X1] ; data 
	LSL 	X3, X3, #2 ;
	ADD		X0, X3, X4 
	STR  	W2, [X0]
 	LSR 	X3, X3, #2  
	ADD		X3, X3, #1
	STR 	X3, [X1, #40]	
	RET


dC1FILLAz:

	LDP		X0,	X3, [X16, #-16]	 
	SUB  	X16, X16, #16

dCarrayaddz_fill: ; X1 base, X0 data, X2 runtime, X3 index

	LDRB	W1,	[X16, #-8]	; fill with
	SUB  	X16, X16, #8

; X1 = fill; X2=count; X0=address 
	MOV 	X2, X3
	B fill_mem

; compiling various fill commands.
; based on array types.
; stack base and index, compile fill instruction


; special for locals
compile_localsWvalz_fill: ; 
	STP		LR,  X16, [SP, #-16]!
	BL		longlitit	; X0 = data
	ADD		X15, X15, #2
	MOV		X0,	X3
	BL		longlitit	; X3 = index
	ADD		X15, X15, #2
	MOV		X0, #41 ; (WALFILLARRAY)
	STR		X0, [X15]	
	LDP		LR, X16, [SP], #16
	MOV		X0, #0
	RET

compile_localsvalz_fill: ; 
	STP		LR,  X16, [SP, #-16]!
	BL		longlitit	; X0 = data
	ADD		X15, X15, #2
	MOV		X0,	X3
	BL		longlitit	; X3 = index
	ADD		X15, X15, #2
	MOV		X0, #40 ; (ALFILLARRAY)
	STR		X0, [X15]	
	LDP		LR, X16, [SP], #16
	MOV		X0, #0
	RET

compile_darrayaddz_fill:
	STP		LR,  X16, [SP, #-16]!
	BL		longlitit	; X0 = data
	ADD		X15, X15, #2
	MOV		X0,	X3
	BL		longlitit	; X3 = index
	ADD		X15, X15, #2
	MOV		X0, #32 ; (A1FILLARRAY)
	STR		X0, [X15]	
	LDP		LR, X16, [SP], #16
	MOV		X0, #0
	RET

compile_dWarrayaddz_fill:
	STP		LR,  X16, [SP, #-16]!
	BL		longlitit	; X0 = data
	ADD		X15, X15, #2
	MOV		X0,	X3
	BL		longlitit	; X3 = index
	ADD		X15, X15, #2
	MOV		X0, #33  ; (W1FILLARRAY)
	STR		X0, [X15]	
	LDP		LR, X16, [SP], #16
	MOV		X0, #0
	RET

compile_dHWarrayaddz_fill:
	STP		LR,  X16, [SP, #-16]!
	BL		longlitit	; X0 = data
	ADD		X15, X15, #2
	MOV		X0,	X3
	BL		longlitit	; X3 = index
	ADD		X15, X15, #2
	MOV		X0, #34 ;   ; (HW1FILLARRAY)
	STR		X0, [X15]	
	LDP		LR, X16, [SP], #16
	MOV		X0, #0
	RET

compile_dCarrayaddz_fill:
	STP		LR,  X16, [SP, #-16]!
	BL		longlitit	; X0 = data
	ADD		X15, X15, #2
	MOV		X0,	X3
	BL		longlitit	; X3 = index
	ADD		X15, X15, #2
	MOV		X0, #35 ; (C1FILLARRAY)
	STR		X0, [X15]	
	LDP		LR, X16, [SP], #16
	MOV		X0, #0
	RET


; ALLOT X0 cells
; cell size is LSL X3
; X3 = 0, 1, 2, 3

.macro allotation

	ADRP	X12, allot_ptr@PAGE	
	ADD		X12, X12, allot_ptr@PAGEOFF

	ADRP	X13, allot_last@PAGE	
	ADD		X13, X13, allot_last@PAGEOFF

	LDR		X1, [X12] ; pointer to memory 
	LSL		X0, X0, X3	; x n
	ADD		X0, X1, X0 
	ADD		X1, X1, #16
	ADD		X0, X0, #7
	AND		X0, X0, #-8
	STR		X0, [X12]	; bump pointer

	LDR		X0, [X13]
	STR		X0, [X28]	; word points to last allotted

	; update last for next allotment
	LDR		X0, [X12]
	STR		X0, [X13]

	ADRP	X12, allot_limit@PAGE	
	ADD		X12, X12, allot_limit@PAGEOFF
	LDR 	X12, [X12]

 .endm


.macro find_free_word

	save_registers_not_stack
	BL		advancespaces
	BL		collectword
	BL		get_word
	BL		empty_wordQ
	B.ne	789f

	; dictionary full..
	restore_registers_not_stack
	RET

789:
	BL		start_point

.endm


;; ARRAY returns addresses
;; VALUES returns value
dcreatvalues:
 	find_free_word
	ADRP	X8, darrayvalz@PAGE	; high level word.	
	ADD		X8, X8, darrayvalz@PAGEOFF
	MOV		X3, #3
	B 		arrayvaluecreator

dcreatstringvalues:
 	find_free_word
	ADRP	X8, darrayvalz@PAGE	; high level word.	
	ADD		X8, X8, darrayvalz@PAGEOFF
	MOV		X3, #3
	B 		arrayvaluecreator

dcreatarray:
	find_free_word
	ADRP	X8, darrayaddz@PAGE	; high level word.	
	ADD		X8, X8, darrayaddz@PAGEOFF
	MOV		X3, #3
	B 		arrayvaluecreator

dWcreatvalues:
 	find_free_word
	ADRP	X8, dWarrayvalz@PAGE	; high level word.	
	ADD		X8, X8, dWarrayvalz@PAGEOFF
	MOV		X3, #2
	B 		arrayvaluecreator

dWcreatarray:
 	find_free_word
	ADRP	X8, dWarrayaddz@PAGE	; high level word.	
	ADD		X8, X8, dWarrayaddz@PAGEOFF
	MOV		X3, #2
	B 		arrayvaluecreator

dHWcreatvalues:
 	find_free_word
	ADRP	X8, dHWarrayvalz@PAGE	; high level word.	
	ADD		X8, X8, dHWarrayvalz@PAGEOFF
	MOV		X3, #1
	B 		arrayvaluecreator

dHWcreatarray:
 	find_free_word
	ADRP	X8, dHWarrayaddz@PAGE	; high level word.	
	ADD		X8, X8, dHWarrayaddz@PAGEOFF
	MOV		X3, #1
	B 		arrayvaluecreator

dCcreatvalues:
	 find_free_word
	ADRP	X8, dCarrayvalz@PAGE	; high level word.	
	ADD		X8, X8, dCarrayvalz@PAGEOFF
	MOV		X3, #0
	B 		arrayvaluecreator

dCcreatarray:
 	find_free_word
	ADRP	X8, dCarrayaddz@PAGE	; high level word.	
	ADD		X8, X8, dCarrayaddz@PAGEOFF
	MOV		X3, #0
	B 		arrayvaluecreator



arrayvaluecreator:

100:	; find free word and start building it

	LDR		X1, [X28, #48] ; name field
	LDR		X0, [X22]
	CMP		X1, X0
	B.eq	290b

	CMP		X1, #0		; end of list?
	B.eq	280f		; not found 
	CMP		X1, #-1		; undefined entry in list?
	b.ne	260f

	; undefined so build the word here
	; this is now the last_word word being built.
	ADRP	X1, last_word@PAGE		
	ADD		X1, X1, last_word@PAGEOFF
	STR		X28, [X1]

	copy_word_name

	; store runtime code

	STR		X8, [X28, #8]

	ADD		X1, X28, #32
	STR		X1, [X28]

	; set array size from tos.
	LDR		X0, [X16, #-8]	
	SUB		X16, X16, #8
	STR		X0, [X28, #32] ; array size 

	
	save_registers
	MOV 	W1, W3
	BL		_calloc
	restore_registers
	CBZ 	X0, calloc_failed 
	STR 	X0, [X28]
 

B		300f


260:	; try next word in dictionary
	SUB		X28, X28, #64
	B		100b

280:	; error dictionary FULL


300:
	restore_registers_not_stack

	RET
 
 ;; End of ARRAYS   

;; STACKS

dstackz:

	LDR 	X0, [X1, #16] ; stack pos
	SUB		X0, X0, #1
	STR		X0, [X1, #16] ; stack pos
	CMP 	X0, #0
	B.lt	empty_stack 

	LSL		X0, X0, #3
	LDR		X2, [X1]
	ADD		X2, X2, X0
	LDR		X0, [X2] 
	STR		X0, [X16], #8
	
	RET

empty_stack:
	MOV 	X0, #0
	STR		X0, [X1, #16] ; stack pos
	B	darrayaddz_index_error 

dcreatstack:

	find_free_word	
	ADRP	X8, dstackz@PAGE	; high level word.	
	ADD		X8, X8, dstackz@PAGEOFF
	MOV		X3, #3
 
100:	; find free word and start building it

	LDR		X1, [X28, #48] ; name field
	LDR		X0, [X22]
	CMP		X1, X0
	B.eq	290b

	CMP		X1, #0		; end of list?
	B.eq	280f		; not found 
	CMP		X1, #-1		; undefined entry in list?
	b.ne	260f

	; undefined so build the word here
	; this is now the last_word word being built.
	ADRP	X1, last_word@PAGE		
	ADD		X1, X1, last_word@PAGEOFF
	STR		X28, [X1]


	copy_word_name

	; store runtime code
	ADRP	X8, dstackz@PAGE	; high level word.	
	ADD		X8, X8, dstackz@PAGEOFF
	STR		X8, [X28, #8]

	; set stack size from tos.
	LDR		X0, [X16, #-8]	
	SUB		X16, X16, #8
	STR		X0, [X28, #32] ; array size 

	MOV 	X3, #3
	allotation
	CMP		X0, X12
	B.gt	allot_memory_full
	B		300f


260:	; try next word in dictionary
	SUB		X28, X28, #64
	B		100b

280:	; error dictionary FULL


300:
	restore_registers_not_stack

	RET



dselectit:


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

	BL		get_word
	LDR		X21, [X28, #48] ; name field
	CMP		X21, X22		; is this our word?
	B.ne	170f

	LDR		X21, [X28, #56] ; next 8
	BL		get_word2
	CMP		X21, X22		;  
	B.ne	170f			; that was 16 bytes..

	; found word, stack address of word
	restore_registers
 	ADRP	X1, last_word@PAGE		
	ADD		X1, X1, last_word@PAGEOFF
	STR 	X28, [X1]
	RET

170:	; next word in dictionary
	SUB		X28, X28, #64
	B		120b

190:	; error out 
	MOV		X0, #0
	restore_registers
	B	stackit
	RET


dtickz: ; ' - get address of NEXT words data field

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

	BL		get_word
	LDR		X21, [X28, #48] ; name field
	CMP		X21, X22		; is this our word?
	B.ne	170f

	LDR		X21, [X28, #56] ; next 8
	BL		get_word2
	CMP		X21, X22		;  
	B.ne	170f			; that was 16 bytes..



	; found word, stack address of word

	MOV	X0, 	X28  
	restore_registers
	B  stackit


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
	CBZ     X15, dinterp_invalid
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


dendifz: ; AKA THEN AKA ENDIF
	CBZ     X15, dinterp_invalid
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
	CBZ     X15, dinterp_invalid
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
	SUB		X14, X14, #16
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

	LDR		X1, [X16, #-8]!
	CBNZ	X1, 90f

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



dtickc: ; `` at compile time, turn address of word into literal


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

	LDR		X21, [X28, #56] ; next 8
	BL		get_word2
	CMP		X21, X22		;  
	B.ne	170f			; that was 16 bytes..


	MOV 	X0, X28 
	BL 		longlitit
	B 		200f


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



dcallz:	;  EXECUTE code field (from ' WORD on stack)

	LDR		X1, [X16, #-8]	
	SUB		X16, X16, #8
	LDR		X0, [X1]
	LDR		X1, [X1, #8]
	BR		X1		


dcallc:	; CALL code field (on stack)
	RET


; TRACE DISPLAY ON/OFF 

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
	MRS		X0, cntpct_el0
	B		stackit


dtimeitz: ; time the next words execution

	save_registers

	BL		advancespaces
	BL		collectword

	BL		empty_wordQ
	B.ne	10f

	restore_registers
	ADRP	X0, tcomer43@PAGE	
	ADD		X0, X0, tcomer43@PAGEOFF
	BL		sayit_err
	RET

10:
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

	LDR		X21, [X28, #56] ; next 8
	BL		get_word2
	CMP		X21, X22		;  
	B.ne	170f			; that was 16 bytes..


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
 	restore_registers
	ADRP	X0, tcomer43@PAGE	
	ADD		X0, X0, tcomer43@PAGEOFF
	B		sayit_err
 

200:
	restore_registers
	RET

 dtimeitc:
	ADRP	X0, tcomer44@PAGE	
	ADD		X0, X0, tcomer44@PAGEOFF
	B		sayit_err
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

	LDR		X21, [X28, #56] ; next 8
	BL		get_word2
	CMP		X21, X22		;  
	B.ne	170f			; that was 16 bytes..


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

	CMP		X21, #0			; end of list?
	B.eq	190f			; not found 
	CMP		X21, #-1		; undefined entry in list?
	b.eq	170f

	BL		get_word
	LDR		X21, [X28, #48] ; name field
	CMP		X21, X22		; is this our word?
	B.ne	170f

	LDR		X21, [X28, #56] ; next 8
	BL		get_word2
	CMP		X21, X22		;  
	B.ne	170f			; that was 16 bytes..


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

	CMP		X21, #0			; end of list?
	B.eq	190f			; not found 
	CMP		X21, #-1		; undefined entry in list?
	b.eq	170f

	BL		get_word
	LDR		X21, [X28, #48] ; name field
	CMP		X21, X22		; is this our word?
	B.ne	170f

	LDR		X21, [X28, #56] ; next 8
	BL		get_word2
	CMP		X21, X22		;  
	B.ne	170f			; that was 16 bytes..

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


; run with parents locals
dflat:

	save_registers

	BL		advancespaces
	BL		collectword

	BL		empty_wordQ
	B.eq	190f

	BL		start_point

120:
	LDR		X21, [X28, #48] ; name field

	CMP		X21, #0			; end of list?
	B.eq	190f			; not found 
	CMP		X21, #-1		; undefined entry in list?
	b.eq	170f

	BL		get_word
	LDR		X21, [X28, #48] ; name field
	CMP		X21, X22		; is this our word?
	B.ne	170f

	LDR		X21, [X28, #56] ; next 8
	BL		get_word2
	CMP		X21, X22		;  
	B.ne	170f			; that was 16 bytes..



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
	
	B 		180f

140:

	ADRP	X0, flatrunintz@PAGE	
	ADD		X0, X0, flatrunintz@PAGEOFF
	STR		X0, [X28, #8]	
	B		200f


170:	; next word in dictionary
	SUB		X28, X28, #64
	B		120b


180:	; error out 


	restore_registers
	ADRP	X0, tcomer38@PAGE	
	ADD		X0, X0, tcomer38@PAGEOFF
	B		sayit_err


190:	; error out 
 
	restore_registers
	ADRP	X0, tcomer37@PAGE	
	ADD		X0, X0, tcomer37@PAGEOFF
	B		sayit_err
 

200:
	restore_registers
	RET



; run with parents locals
dflattrace:

	save_registers

	BL		advancespaces
	BL		collectword

	BL		empty_wordQ
	B.eq	190f

	BL		start_point

120:
	LDR		X21, [X28, #48] ; name field

	CMP		X21, #0			; end of list?
	B.eq	190f			; not found 
	CMP		X21, #-1		; undefined entry in list?
	b.eq	170f

	BL		get_word
	LDR		X21, [X28, #48] ; name field
	CMP		X21, X22		; is this our word?
	B.ne	170f

	LDR		X21, [X28, #56] ; next 8
	BL		get_word2
	CMP		X21, X22		;  
	B.ne	170f			; that was 16 bytes..


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
	
	B 		180f

140:

	ADRP	X0, flattracerunintz@PAGE	
	ADD		X0, X0, flattracerunintz@PAGEOFF
	STR		X0, [X28, #8]	
	B		200f


170:	; next word in dictionary
	SUB		X28, X28, #64
	B		120b


180:	; error out 


	restore_registers
	ADRP	X0, tcomer38@PAGE	
	ADD		X0, X0, tcomer38@PAGEOFF
	B		sayit_err


190:	; error out 
 
	restore_registers
	ADRP	X0, tcomer37@PAGE	
	ADD		X0, X0, tcomer37@PAGEOFF
	B		sayit_err
 

200:
	restore_registers
	RET




; fast not traceable, otherwise the same as runintz below.

fastrunintcz: ; interpret the list of tokens at word + 

	; over ride X0 to compile time token address

	LDR		X0, [X1, #40]		; compile mode tokens


fastrunintz:; interpret the list of tokens at X0
	; until (END)


	; SAVE IP 
	STP		LR,  X15, [SP, #-16]!
	STP		X14, X26, [SP, #-16]! 

	; zero locals

	STP		X0,  X1,  [X26],#16 ; data and word address
	STP		XZR, XZR, [X26],#16
	STP		XZR, XZR, [X26],#16
	STP		XZR, XZR, [X26],#16
	STP		XZR, XZR, [X26],#16

	; IP
	SUB		X15, X0, #2
 

	; unrolling the loop here X16 makes this a lot faster, 
10:	; next token
	
	.rept	16

		LDRH	W1, [X15, #2]!
		CBZ		W1, 90f
		LSL 	W1, W1, #6
		
		ADD		X1, X1, X27
		LDP		X0, X2, [X1]
		CBZ		X2, 10b
	
		BLR		X2		; with X0 as data and X1 as address	
 
	.endr

	b		10b


90:
	LDP		X14, X26, [SP], #16
	LDP		LR, X15, [SP], #16	
	RET



; flat - no local stacking
flattracerunintz:; interpret the list of tokens at X0

	; SAVE IP 
	STP		LR,  X15, [SP, #-16]!
	STP		X14, X26, [SP, #-16]! 
	SUB		X15, X0, #2
	MOV		X20, X15

	; unrolling the loop here X16 makes this a lot faster, 
10:	; next token
	
	.rept	32

		LDRH	W1, [X15, #2]!
		CBZ		W1, 90f
		LSL 	W1, W1, #6
		
		ADD		X1, X1, X27
		LDP		X0, X2, [X1]
		CBZ		X2, 10b
	
		BLR		X2		; with X0 as data and X1 as address	
	
		do_trace

	.endr

	b		10b

90:
	LDP		X14, X26, [SP], #16
	LDP		LR, X15, [SP], #16	
	RET

flatrunintz:; interpret the list of tokens at X0

	; SAVE IP 
	STP		LR,  X15, [SP, #-16]!
	STP		X14, XZR, [SP, #-16]! 
	SUB		X15, X0, #2
	MOV		X20, X15

	; unrolling the loop here X16 makes this a lot faster, 
10:	; next token
	
	.rept	32

		LDRH	W1, [X15, #2]!
		CBZ		W1, 90f
		LSL 	W1, W1, #6
		
		ADD		X1, X1, X27
		LDP		X0, X2, [X1]
		CBZ		X2, 10b
	
		BLR		X2		; with X0 as data and X1 as address	
	
	.endr

	b		10b

90:
	LDP		X14, XZR, [SP], #16
	LDP		LR, X15, [SP], #16	
	RET


; only run the word for STEPPING steps.
; allow word to be tested a few steps at a time. 
; 

stepoutz:

	MOV		X25, #-1
	B 		step_away

limitrunintz:; interpret the list of tokens at X0


	STP		X0,  X1,  [X26],#16 ; data and word address
	STP		XZR, XZR, [X26],#16
	STP		XZR, XZR, [X26],#16
	STP		XZR, XZR, [X26],#16
	STP		XZR, XZR, [X26],#16
	
	; SAVE IP 

	SUB		X15, X0, #2
 
	 
step_in_runz: ; take more steps

	ADRP	X0, step_limit@PAGE	
	ADD		X0, X0, step_limit@PAGEOFF
	LDR     X25, [X0] ; steps to run for 
	 
step_away:
	CBZ		X15, 98f	; we finished 
	STP		LR,  XZR, [SP, #-16]!
 

	; unrolling the loop here X16 makes this a lot faster, 
10:	; next token


	SUB     X25, X25, #1
	CBZ		X25, 80f
	LDRH	W1, [X15, #2]!

	CBZ		W1, 90f
	LSL 	W1, W1, #6
		
	ADD		X1, X1, X27
	LDP		X0, X2, [X1]
	CBZ		X2, 10b
	
	BLR		X2		; with X0 as dat

	; this is why we are a little slower.
	do_trace

	b		10b

80: 
	LDP		LR, XZR, [SP], #16	
	RET

90:
	SUB		X26, X26, #80
	LDP		LR, XZR, [SP], #16	
	RET

95: ; we finish so mark IP as invalid

	LDP		LR, XZR, [SP], #16
	MOV		X15, #0
98:
	SUB		X26, X26, #80
	RET

; traceable version

runintcz: ; interpret the list of tokens at word + 

	; over ride X0 to compile time token address

	LDR		X0, [X1, #32]		; compile mode tokens


runintz:; interpret the list of tokens at X0

	; SAVE IP, RP, LOCALS
	STP		LR,  X15, [SP, #-16]!
	STP		X14, X26, [SP, #-16]! 

 
	STP		X0,  X1,  [X26],#16 ; data and word address
	STP		XZR, XZR, [X26],#16
	STP		XZR, XZR, [X26],#16
	STP		XZR, XZR, [X26],#16
	STP		XZR, XZR, [X26],#16


	SUB		X15, X0, #2
 

	; unrolling the loop here X16 makes this a lot faster, 
10:	; next token

	.rept	16
	
		LDRH	W1, [X15, #2]!
		CBZ		W1, 90f
		LSL 	W1, W1, #6
		
		ADD		X1, X1, X27
		LDP		X0, X2, [X1]
		CBZ		X2, 10b
	
		BLR		X2	 

 
		do_trace

	.endr

	b		10b
	
dendz:	; EXIT interpreter - called by exit

90:
	LDP		X14, X26, [SP], #16
	LDP		LR, X15, [SP], #16	
	SUB		X26, X26, #80
	RET


difexitz: ; IFEXIT

	CBZ     X15, dinterp_invalid
	LDR 	X0, [X16, #-8]
	SUB 	X16, X16, #8
	CBZ		X0, 170f

	; unwind stack
	LDP		X14, X26, [SP], #16
	LDP		LR, X15, [SP], #16	
 
	
170:	
	RET


difzexitz: ; IF0EXIT

	CBZ     X15, dinterp_invalid	 
	LDR 	X0, [X16, #-8]
	SUB 	X16, X16, #8
	CBNZ	X0, 170f
	; unwind stack
	LDP		X14, X26, [SP], #16
	LDP		LR, X15, [SP], #16	
170:	
	RET


dexitz: ; EXIT
	CBZ     X15, dinterp_invalid
	LDP		X14, X26, [SP], #16
	LDP		LR, X15, [SP], #16	
	RET

dexitc: ; EXIT compiles end
	MOV		X0, #0 ; (EXIT)
	STRH	W0, [X15]
190:
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


dcomacz: ; , compiled in action for comma
dcomaz: ; ,  run time comma action



	; if last word was a C array, we can append to it
	ADRP	X1, last_word@PAGE		
	ADD		X1, X1, last_word@PAGEOFF
	LDR 	X1, [X1]
	LDR 	X0, [X1, #8]

10:
	ADRP	X8, dCarrayaddz@PAGE	; high level word.	
	ADD		X8, X8, dCarrayaddz@PAGEOFF
	CMP		X0, X8
	B.ne 	20f  
	B 		dcarraycommafromstack

20:
	; if last word was an array, we can append to it
	 
	ADRP	X8, darrayaddz@PAGE	; high level word.	
	ADD		X8, X8, darrayaddz@PAGEOFF
	CMP		X0, X8
	B.ne 	30f  
	B 		darraycommafromstack


30:
	; if last word was an warray, we can append to it
 
	ADRP	X8, dWarrayaddz@PAGE	; high level word.	
	ADD		X8, X8, dWarrayaddz@PAGEOFF
	CMP		X0, X8
	B.ne 	40f  
	B 		dWarraycommafromstack


40:
	; if last word was an hwarray, we can append to it
 
	ADRP	X8, dHWarrayaddz@PAGE	; high level word.	
	ADD		X8, X8, dHWarrayaddz@PAGEOFF
	CMP		X0, X8
	B.ne 	50f  
	B 		dHWarraycommafromstack

50:
	; if last word was a C values, we can append to it
 
	ADRP	X8, dCarrayvalz@PAGE	; high level word.	
	ADD		X8, X8, dCarrayvalz@PAGEOFF
	CMP		X0, X8
	B.ne 	60f  
	B 		dcarraycommafromstack

60:
	; if last word was an array of values, we can append to it
 
	ADRP	X8, darrayvalz@PAGE	; high level word.	
	ADD		X8, X8, darrayvalz@PAGEOFF
	CMP		X0, X8
	B.ne 	70f  
	B 		darraycommafromstack


70:
	; if last word was an warray of values, we can append to it
 
	ADRP	X8, dWarrayvalz@PAGE	; high level word.	
	ADD		X8, X8, dWarrayvalz@PAGEOFF
	CMP		X0, X8
	B.ne 	80f  
	B 		dWarraycommafromstack


80:
	; if last word was an hwarray of values, we can append to it
 
	ADRP	X8, dHWarrayvalz@PAGE	; high level word.	
	ADD		X8, X8, dHWarrayvalz@PAGEOFF
	CMP		X0, X8
	B.ne 	90f  
	B 		dHWarraycommafromstack

90:

	ADRP	X8, dSTRINGz@PAGE	; high level word.	
	ADD		X8, X8, dSTRINGz@PAGEOFF
	CMP		X0, X8
	B.ne 	100f  
	B 		dcarraycommafromstack

100: 
	; we may be appending a string
	ADRP	X1, append_ptr@PAGE		
	ADD		X1, X1, append_ptr@PAGEOFF
	LDR		X1, [X1]
	CBZ 	X1, 200f
	B 		dstrappendcomma 

200:
	RET

dcomac: ; , 
	MOV		X0, #43 ; (,)
	STR		X0, [X15]	
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


fdotz: ; . print tos
	B 		fprint
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
	LDP		X0, X1, [X16, #-16]
	ADD		X0, X0, X1
	STR		X0, [X16, #-16]
	SUB		X16, X16, #8
	RET


fplusz: ; f+
	LDR		D0, [X16, #-8]
	LDR		D1, [X16, #-16]
	FADD	D0, D0, D1
	STR		D0, [X16, #-16]
	SUB		X16, X16, #8
	RET

fminusz: ; f-
	LDR		D0, [X16, #-8]
	LDR		D1, [X16, #-16]
	FSUB	D0, D1, D0
	STR		D0, [X16, #-16]
	SUB		X16, X16, #8
	RET

fmulz: ; f*
	LDR		D0, [X16, #-8]
	LDR		D1, [X16, #-16]
	FMUL	D0, D1, D0
	STR		D0, [X16, #-16]
	SUB		X16, X16, #8
	RET

fdivz: ; f/
	LDR		D0, [X16, #-8]
	LDR		D1, [X16, #-16]
	FDIV	D0, D1, D0
	STR		D0, [X16, #-16]
	SUB		X16, X16, #8
	RET

fnegz:	;  fnegate 
	LDR		D0, [X16, #-8]
	FNEG	D0, D0
	STR		D0, [X16, #-8]
	RET		

fabsz:	;  fnegate 
	LDR		D0, [X16, #-8]
	FABS	D0, D0
	STR		D0, [X16, #-8]
	RET	

ftosz: ; f>s float to int
	LDR		D0, [X16, #-8]
	fcvtzs	X0, D0
	STR		X0, [X16, #-8]
	RET

fstofz: ; s>f int to float
 	LDR		X0, [X16, #-8] 
    scvtf	D0, X0
	STR		D0, [X16, #-8]
	RET
	 
fsqrt:
	LDR		D0, [X16, #-8] 
    fsqrt	D0, D0
	STR		D0, [X16, #-8]
	RET

fgtz:
	LDR		D0, [X16, #-8]
	LDR		D1, [X16, #-16]
	SUB     X16, X16, #16
	MOV 	X0, #0
	FCMP 	D0, D1
	CINV    X0, X0, gt 
	STR		X0, [X16], #8
	RET

fgtez:
	LDR		D0, [X16, #-8]
	LDR		D1, [X16, #-16]
	SUB     X16, X16, #16
	MOV 	X0, #0
	FCMP 	D0, D1
	CINV    X0, X0, ge 
	STR		X0, [X16], #8
	RET

fltz:
	LDR		D0, [X16, #-8]
	LDR		D1, [X16, #-16]
	SUB     X16, X16, #16
	MOV 	X0, #0
	FCMP 	D0, D1
	CINV    X0, X0, lt 
	STR		X0, [X16], #8
	RET

fltezz:
	LDR		D0, [X16, #-8]
	LDR		D1, [X16, #-16]
	SUB     X16, X16, #16
	MOV 	X0, #0
	FCMP 	D0, D1
	CINV    X0, X0, pl
	MVN     X0, X0
	STR		X0, [X16], #8
	RET


fgtzz:
	LDR		D0, [X16, #-8]
	LDR		D1, [X16, #-16]
	SUB     X16, X16, #16
	MOV 	X0, #0
	FCMP 	D0, D1
	CINV    X0, X0, pl
	STR		X0, [X16], #8
	RET


fltez:
	LDR		D0, [X16, #-8]
	LDR		D1, [X16, #-16]
	SUB     X16, X16, #16
	MOV 	X0, #0
	FCMP 	D0, D1
	CINV    X0, X0, le 
	STR		X0, [X16], #8
	RET


feqz:
	LDR		D0, [X16, #-8]
	LDR		D1, [X16, #-16]
	SUB     X16, X16, #16
	MOV 	X0, #0
	FCMP 	D0, D1
	CINV    X0, X0, eq
	STR		X0, [X16], #8
	RET


fneqz:
	LDR		D0, [X16, #-8]
	LDR		D1, [X16, #-16]
	SUB     X16, X16, #16
	MOV 	X0, #0
	FCMP 	D0, D1
	CINV    X0, X0, ne
	STR		X0, [X16], #8
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

ddrop2z: ;  
	SUB		X16, X16, #16
	RET

ddropc: ;	
	RET	


ztypez: ; AKA $.

	LDR		X0, [X16, #-8] 
	SUB 	X16, X16, #8
	CBZ		X0, nothing_to_say

	ADRP	X8, data_base@PAGE		
	ADD		X8, X8, data_base@PAGEOFF
	CMP 	X0, X8
	B.lt 	nothing_to_say


	B		sayit

nothing_to_say:
	RET


ztypec:
	RET

d2dupz: ;  
	LDR		X0, [X16, #-8] 
	STR		X0, [X16], #8
	LDR		X0, [X16, #-8] 
	STR		X0, [X16], #8
	RET

ddupz: ;  
	LDR		X0, [X16, #-8] 
	STR		X0, [X16], #8
	RET
	
ddup2z: ;  
	LDP		X0, X1, [X16, #-16] 
	STP		X0, X1,  [X16], #16
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

doverswap:
	LDR		X0, [X16, #-16] 
	STR		X0, [X16], #8
	LDP		X0, X1, [X16, #-16]
	STP		X1, X0, [X16, #-16]
	RET

dtuckz: ; SWAP OVER
	LDP		X0, X1, [X16, #-16]
	STP		X1, X0, [X16, #-16]
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



dnequalzz:	; 0<>

	LDR		X0, [X16, #-8] 
	SUB		X16, X16, #8
nequalzz:

	CMP		X0, #0
	B.eq	20f
	MOV		X0, XZR  
	B		10f
10:
	MVN		X0, XZR   
20:
	STR		X0, [X16], #8
	RET



dequalzz:	; 0=

	LDR		X0, [X16, #-8] 
	SUB		X16, X16, #8
	CMP		X0, #0
	B.eq	10f
	MOV		X0, XZR  
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
egtzz:	
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


dtruez:
	MVN		X0, XZR
	STR		X0, [X16], #8
	RET

dfalsez:
	MOV		X0, XZR
	STR		X0, [X16], #8
	RET

dinvertz:	; INVERT

	LDR		X0, [X16, #-8] 
	MVN     X0, X0
	STR		X0, [X16, #-8]
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

	
dalign8:
	LDR		X0, [X16, #-8] 
	ADD		X0, X0, #7
	AND		X0, X0, #-8
	STR		X0, [X16, #-8]
	RET

dalign16:
	LDR		X0, [X16, #-8] 
	ADD		X0, X0, #15
	AND		X0, X0, #-16
	STR		X0, [X16, #-8]
	RET

atz: ;  ( address -- n ) fetch var.
	LDR		X0, [X16, #-8] 
	CBZ		X0, itsnull
	LDR		X0, [X0]
	STR		X0, [X16, #-8]
	RET


dwatz:
	LDR		X0, [X16, #-8] 	
	CBZ		X0, itsnull
	LDR		W0, [X0]
	STR		X0, [X16, #-8]
	RET

itsnull: ; error word_desc13
	MOV		X0, #0
	STR		X0, [X16, #-8]
	STP		LR,  XZR, [SP, #-16]!
	BL		saycr
	BL		saylb
	LDR		X0, [X26, #-72]	 ; self
	ADD		X0, X0, #48
	BL 		sayit
	BL		sayrb
	ADRP	X0, word_desc13@PAGE		
	ADD		X0, X0, word_desc13@PAGEOFF
	BL		sayit_err
	LDP		LR, XZR, [SP], #16

itsnull2: ; error word_desc13
	SUB		X16, X16, #16
	STP		LR,  XZR, [SP, #-16]!
	BL		saycr
	BL		saylb
	LDR		X0, [X26, #-72]	 ; self
	ADD		X0, X0, #48
	BL 		sayit
	BL		sayrb
	ADRP	X0, word_desc13@PAGE		
	ADD		X0, X0, word_desc13@PAGEOFF
	BL		sayit_err
	LDP		LR, XZR, [SP], #16
	RET

storz:  ; ( n address -- )
	LDR		X0, [X16, #-8] 
	LDR		X1, [X16, #-16]
	CBZ		X0, itsnull2
	STR		X1, [X0]
	SUB		X16, X16, #16
	RET

dwstorz:  ; ( n address -- )
	LDR		X0, [X16, #-8] 
	LDR		X1, [X16, #-16]
	CBZ		X0, itsnull2
	STR		W1, [X0]
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

; used for reading char BYTE sized values, from words, strings and allotment.

catz: ;  ( address -- n ) fetch var.
	LDR		X0, [X16, #-8] 
	CBZ		X0, itsnull2
 
	ADRP	X12, data_base@PAGE		
	ADD		X12, X12, data_base@PAGEOFF
	CMP 	X0, X12
	B.lt	itsnull

	LDRB	W0, [X0]
	STR		X0, [X16, #-8]
	RET

cstorz:  ; ( n address -- )
	LDR		X0, [X16, #-8] 
	LDR		X1, [X16, #-16]
	CBZ		X0, itsnull2

	ADRP	X12, data_base@PAGE		
	ADD		X12, X12, data_base@PAGEOFF
	CMP 	X0, X12
	B.lt	itsnull

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

; create an N plus word
; 1 ADDER 1+
dcreatndivz:

	find_free_word
	ADRP	X8, ndivz@PAGE	; high level word.	
	ADD		X8, X8, ndivz@PAGEOFF
	MOV		X3, #3
	B 		100f

dcreatnmulz:
	
	find_free_word
	ADRP	X8, nmulz@PAGE	; high level word.	
	ADD		X8, X8, nmulz@PAGEOFF
	MOV		X3, #3
	B 		100f

creatsubber:

 	find_free_word
	ADRP	X8, nsubz@PAGE	; high level word.	
	ADD		X8, X8, nsubz@PAGEOFF
	MOV		X3, #3
	B 		100f

creatadder:


 	find_free_word
	ADRP	X8, nplusz@PAGE	; high level word.	
	ADD		X8, X8, nplusz@PAGEOFF
	MOV		X3, #3
 

100:	; find free word and start building it


	LDR		X1, [X28, #48] ; name field
	LDR		X0, [X22]
	CMP		X1, X0
	B.eq	290b

	CMP		X1, #0		; end of list?
	B.eq	280f		; not found 
	CMP		X1, #-1		; undefined entry in list?
	b.ne	260f

; undefined so build the word here

	; this is now the last_word word being built.
	ADRP	X1, last_word@PAGE		
	ADD		X1, X1, last_word@PAGEOFF
	STR		X28, [X1]

	copy_word_name

	; store runtime code

	STR		X8, [X28, #8]

	ADD		X1, X28, #32
	STR		X1, [X28]

	; set adder
	LDR		X0, [X16, #-8]	
	SUB		X16, X16, #8
	STR		X0, [X28, #0] ; value to add
	B		300f


260:	; try next word in dictionary
	SUB		X28, X28, #64
	B		100b

280:	; error dictionary FULL


300:
	restore_registers_not_stack

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
	STP		X1, X3, [SP, #-16]!
	STP		X2, X4, [SP, #-16]!
	; halfword numbers ~32k
	MOV		X3, #4000
	LSL		X3, X3, #3  
	MOV		X1, X0
	CMP		X0, X3 
	B.gt	25f  ; too big to be

	MOV		X0, #1 ; #LITS
	STRH	W0, [X15]
	ADD		X15, X15, #2
	STRH	W1, [X15]	; value

	; short literal done
 	LDP		X2, X4, [SP], #16	
	LDP		X1, X3, [SP], #16	
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
	B.eq	exit_compiler_pool_full ; TODO: test
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
	LDP		X2, X4, [SP], #16	
	LDP		X1, X3, [SP], #16	
	RET


80:
	; found the literal
	MOV		X0, #2 ; #LITL
	STRH	W0, [X15]
	ADD		X15, X15, #2
	MOV		X1, X3
	STRH	W1, [X15]	; value = index

	LDP		X2, X4, [SP], #16	
	LDP		X1, X3, [SP], #16	

	;LDP		LR, X0, [SP], #16
	RET


stackit: ; push X0 to stack.

	STR		X0, [X16], #8
	RET

; interpreter pointer exposed

; IP@
dipatz:
	CBZ     X15, dip_invalid
	STR		X15, [X16], #8
	RET

; IP!
dipstrz:
	CBZ     X15, dip_invalid
	LDR		X0, [X16,#-8]
	MOV 	X15, X0
	SUB 	X16, X16, #8
	RET

; IP2+
dip2plusz:
	CBZ     X15, dip_invalid
	ADD		X15, X15, #2
	RET

; IP+
dipplusz:
	CBZ     X15, dip_invalid
	LDR		X0, [X16,#-8]
	ADD		X15, X15, X0
	SUB 	X16, X16, #8
	RET

; HW@IP - get hw from HP; e.g. the TOKEN
; which will be itself in a high level word.
dhatipz:

	CBZ     X15, dip_invalid
	LDRH    W0, [X15]
	STR		X0, [X16], #8
	RET


; different variable sizes

dWvaraddz:


dHWvaraddz:


dCvaraddz:


dvaraddz: ; address of variable
	STR		X0, [X16], #8
	RET

dvaraddc: ; compile address of variable
	RET


dconsz: ; value of constant
	STR		X0, [X16], #8
	RET

dconsc: ; compile value of constant

	RET


; VALUES are less hazardous variables updated by TO rather than !
; they return their value rather than their address
; e.g. 10 VALUE test 
;      test . =>  10


dvaluez:	; read the value from the address
	LDR		X0,  [X1]
	LDR		X0,	 [X0]
	STR		X0, [X16], #8
	RET


dvaluec:    ; 
	RET


; create value 

dcreatevalz:

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
	B.eq	280f		; not found 
	CMP		X1, #-1		; undefined entry in list?
	b.ne	260f

; undefined so build the word here

	; this is now the last_word word being built.
	ADRP	X1, last_word@PAGE		
	ADD		X1, X1, last_word@PAGEOFF
	STR		X28, [X1]

	; copy text for name over
	copy_word_name

	; variable code
	ADRP	X1, dvaluez@PAGE	; high level word.	
	ADD		X1, X1, dvaluez@PAGEOFF
	STR		X1, [X28, #8]


	ADD		X1, X28, #32
	STR		X1, [X28]

	; set value from tos.
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

 
dcreatevalc:

	RET


; INCR quickly and safely increment a value
; e.g. INCR myValue

dincrcz:

	RET 


ddecrcz:

	RET


dincrz: ; INTERPRETER increment

	RET


ddecrz: ; INTERPRETER decrement

	RET 



dincrc: ; COMPILE increment

	RET


ddecrc: ; COMPILE decrement

	RET 





; TO safely change the values of variables and arrays.

; TO e.g. 10 TO MyVALUE



; SPECIALIZED TO WORDS
; LIKE TO but only for Word Sized objects

dwtocz:	

	LDR		X3, [X16, #-8] 		
	SUB		X16, X16, #8

toWupdateit:

	LDR		X2,	 [X3, #8] 

	ADRP	X1, dWvaraddz@PAGE	; high level word.	
	ADD		X1, X1, dWvaraddz@PAGEOFF
	CMP 	X2, X1
	B.eq	135f 

	ADRP	X1, dWarrayaddz@PAGE	; high level word.
	ADD		X1, X1, dWarrayaddz@PAGEOFF
	CMP 	X2, X1
	B.eq	130f 

	ADRP	X1, dWarrayvalz@PAGE	; high level word.
	ADD		X1, X1, dWarrayvalz@PAGEOFF
	CMP 	X2, X1
	B.eq	130f 


	ADRP	X1, dlocalsWvalz@PAGE	; high level word.
	ADD		X1, X1, dlocalsWvalz@PAGEOFF
	CMP 	X2, X1
	B.eq	170f 

	; not a word we understand
	B		190f


; LIKE TO but only for byte Sized objects
dctocz:	

	LDR		X3, [X16, #-8] 		
	SUB		X16, X16, #8

toCupdateit:

	LDR		X2,	 [X3, #8] 

	ADRP	X1, dCarrayaddz@PAGE	; high level word.
	ADD		X1, X1, dCarrayaddz@PAGEOFF
	CMP 	X2, X1
	B.eq	145f 


	ADRP	X1, dCarrayvalz@PAGE	; high level word.
	ADD		X1, X1, dCarrayvalz@PAGEOFF
	CMP 	X2, X1
	B.eq	150f 

	; not a word we understand

	B		190f


; LIKE TO but only for 64bit quad L Sized objects

dltocz:

	LDR		X3, [X16, #-8] 		
	SUB		X16, X16, #8

toLupdateit:

	LDR		X2,	 [X3, #8] 

	ADRP	X1, dvaraddz@PAGE	; high level word.	
	ADD		X1, X1, dvaraddz@PAGEOFF
	CMP 	X2, X1
	B.eq	155f 
	
	ADRP	X1, dvaluez@PAGE	; high level word.	
	ADD		X1, X1, dvaluez@PAGEOFF
	CMP 	X2, X1
	B.eq	155f 

	ADRP	X1, darrayaddz@PAGE	; high level word.
	ADD		X1, X1, darrayaddz@PAGEOFF
	CMP 	X2, X1
	B.eq	160f 

	ADRP	X1, darrayvalz@PAGE	; high level word.
	ADD		X1, X1, darrayvalz@PAGEOFF
	CMP 	X2, X1
	B.eq	160f 


	ADRP	X1, dlocalsvalz@PAGE	; high level word.
	ADD		X1, X1, dlocalsvalz@PAGEOFF
	CMP 	X2, X1
	B.eq	180f 

	ADRP	X1, dstackz@PAGE	; high level word.
	ADD		X1, X1, dstackz@PAGEOFF
	CMP 	X2, X1
	B.eq	100f 

	; not a word we understand

	B		190f



; Generic TO checks type of word and changes the data
; more specialized TO words can check fewer word types.
;


dtocz: ; (TO) expects address of word to update in X2


	LDR		X3, [X16, #-8] 
	SUB		X16, X16, #8

toupdateit:

	LDR		X2,	 [X3, #8] 

	; check type of word and select right update functions

	ADRP	X1, dvaraddz@PAGE	; high level word.	
	ADD		X1, X1, dvaraddz@PAGEOFF
	CMP 	X2, X1
	B.eq	155f 
	
	ADRP	X1, dvaluez@PAGE	; high level word.	
	ADD		X1, X1, dvaluez@PAGEOFF
	CMP 	X2, X1
	B.eq	155f 

	ADRP	X1, darrayaddz@PAGE	; high level word.
	ADD		X1, X1, darrayaddz@PAGEOFF
	CMP 	X2, X1
	B.eq	160f 


	ADRP	X1, darrayvalz@PAGE	; high level word.
	ADD		X1, X1, darrayvalz@PAGEOFF
	CMP 	X2, X1
	B.eq	160f 


	ADRP	X1, dlocalsvalz@PAGE	; high level word.
	ADD		X1, X1, dlocalsvalz@PAGEOFF
	CMP 	X2, X1
	B.eq	180f 


	ADRP	X1, dCarrayaddz@PAGE	; high level word.
	ADD		X1, X1, dCarrayaddz@PAGEOFF
	CMP 	X2, X1
	B.eq	145f 


	ADRP	X1, dCarrayvalz@PAGE	; high level word.
	ADD		X1, X1, dCarrayvalz@PAGEOFF
	CMP 	X2, X1
	B.eq	150f 

	ADRP	X1, dSTRINGz@PAGE	; high level word.
	ADD		X1, X1, dSTRINGz@PAGEOFF
	CMP 	X2, X1
	B.eq	158f 


	ADRP	X1, dWarrayaddz@PAGE	; high level word.
	ADD		X1, X1, dWarrayaddz@PAGEOFF
	CMP 	X2, X1
	B.eq	130f 


	ADRP	X1, dWarrayvalz@PAGE	; high level word.
	ADD		X1, X1, dWarrayvalz@PAGEOFF
	CMP 	X2, X1
	B.eq	130f 


	ADRP	X1, dlocalsWvalz@PAGE	; high level word.
	ADD		X1, X1, dlocalsWvalz@PAGEOFF
	CMP 	X2, X1
	B.eq	170f 


	ADRP	X1, dHWarrayaddz@PAGE	; high level word.
	ADD		X1, X1, dHWarrayaddz@PAGEOFF
	CMP 	X2, X1
	B.eq	120f 


	ADRP	X1, dHWarrayvalz@PAGE	; high level word.
	ADD		X1, X1, dHWarrayvalz@PAGEOFF
	CMP 	X2, X1
	B.eq	120f 

	ADRP	X1, dstackz@PAGE	; high level word.
	ADD		X1, X1, dstackz@PAGEOFF
	CMP 	X2, X1
	B.eq	100f 


	; not a word we understand

	B		190f



; The TO updaters follow


100:	; push onto stack
	LDR		X0, [X3] ; base address
	LDR		X1, [X3, #32] ; max depth
	LDR 	X2, [X3, #16] ; stack pos
	CMP		X2,  X1
	B.eq	darrayaddz_index_error

	LSL		X2, X2, #3
	ADD		X1, X2, X0
	LDR		X0, [X16, #-8] 
	STR		X0, [X1]  ; store on stack

	SUB		X16, X16, #8

	LDR 	X2, [X3, #16] ; stack pos
	ADD		X2, X2, #1
	STR 	X2, [X3, #16] ; stack pos
	RET

120:
	LDR		X2, [X16, #-8] 
	LDR		X0, [X3] ; var or val address
	LDR		X1, [X3, #32]
	CMP		X2,  X1
	B.gt	darrayaddz_index_error

	LSL		X2, X2, #1
	ADD		X1, X2, X0
	LDR		W0, [X16, #-16] 
	STRH	W0, [X1]  ; store 
	SUB		X16, X16, #16
	RET


125:	; HW word

	LDR		X1, [X16, #-8] 
	LDRH	W0, [X3] ; var or val address
	STRH	W1, [X0]  ; store 
	SUB		X16, X16, #8
	RET


135:	; W word

	LDR		X1, [X16, #-8] 
	LDR		W0, [X3] ; var or val address
	STR		W1, [X0]  ; store 
	SUB		X16, X16, #8
	RET


130:

	LDR		X2, [X16, #-8] 
	LDR		X0, [X3] ; var or val address
	LDR		X1, [X3, #32]
	CMP		X2,  X1
	B.gt	darrayaddz_index_error

	LSL		X2, X2, #2
	ADD		X1, X2, X0
	LDR		W0, [X16, #-16] 
	STR   	W0, [X1]  ; store 
	SUB		X16, X16, #16
	RET


145:	; C byte
	LDR		X1, [X16, #-8] 
	LDR		W0, [X3] ; var or val address
	STRB	W1, [X0]  ; store 
	SUB		X16, X16, #8
	RET



150:
	LDR		X2, [X16, #-8] 
	LDR		X0, [X3] ; var or val address
	LDR		X1, [X3, #32]
	CMP		X2,  X1
	B.gt	darrayaddz_index_error

	ADD		X1, X2, X0
	LDR		W0, [X16, #-16] 
	STRB   	W0, [X1]  ; store 
	SUB		X16, X16, #16
	RET	



155:

	; get variable to change

	LDR		X1, [X16, #-8] 
	LDR		X0, [X3] ; var or val address
	STR		X1, [X0]  ; store 
	SUB		X16, X16, #8
	RET


158:

	LDR		X1, [X16, #-8] 
	STR		X1, [X3]  ; store 
	SUB		X16, X16, #8
	RET



160:
	LDR		X2, [X16, #-8] 
	LDR		X0, [X3] ; var or val address
	LDR		X1, [X3, #32]
	CMP		X2,  X1
	B.gt	darrayaddz_index_error

	LSL		X2, X2, #3
	ADD		X1, X2, X0
	LDR		X0, [X16, #-16] 
	STR		X0, [X1]  ; store 
	SUB		X16, X16, #16
	RET


170: ; update LOCALS (32bit W) (offset from X26)

 	LDR		X2, [X16, #-8] 
	LDR		X0, [X3] ; var or val address
	LDR		X1, [X3, #32]
	CMP		X2,  X1
	B.gt	darrayaddz_index_error
	LSL		X2, X2, #2 ;  
	SUB		X1, X26, X2 ; LOCALS + index 
	SUB 	X1, X1, #4
	LDR		X0, [X16, #-16] 
	STR		W0, [X1]  ; store 
	SUB		X16, X16, #16
	RET


180: ; update LOCALS (64bit) (offset from X26)

 	LDR		X2, [X16, #-8] 
	LDR		X0, [X3] ; var or val address
	LDR		X1, [X3, #32]
	CMP		X2,  X1
	B.gt	darrayaddz_index_error
	LSL		X2, X2, #3 ; full word 8 bytes
	SUB		X1, X26, X2 ; LOCALS + index 
	SUB 	X1, X1, #8
	LDR		X0, [X16, #-16] 
	STR		X0, [X1]  ; store 
	SUB		X16, X16, #16
	RET




; The TO error

190:	; error out 

	ADRP	X0, tcomer33@PAGE	; high level word.
	ADD		X0, X0, tcomer33@PAGEOFF
	B		sayit_err	
	 
	RET


; TO (interpreted)  just uses generic TO

dtoz:

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
	B.eq	190f		; not found 

	CMP		X21, #-1	; undefined entry in list?
	b.eq	170f

	BL		get_word
	LDR		X21, [X28, #48] ; name field
	CMP		X21, X22		; is this our word?
	B.ne	170f


	LDR		X21, [X28, #56] ; next 8
	BL		get_word2
	CMP		X21, X22		;  
	B.ne	170f			; that was 16 bytes..


	; found word, update it
 
	restore_registers

	MOV		X3,  X28
	
	B 		toupdateit


170:	; next word in dictionary
	SUB		X28, X28, #64
	B		120b

190:	; error out 
	restore_registers
	SUB 	X16, X16, #8
	ADRP	X0, tcomer40@PAGE
	ADD		X0, X0, tcomer40@PAGEOFF
	B		sayit_err	 
 

	RET


; when compiling in TO we want to check that the words are TO able or fail.
; we compile in more specific TOs when available.

dtoc:	; COMPILE in address of next word followed by (*TO)


	STP		LR,  XZR, [SP, #-16]!

	BL		advancespaces
	BL		collectword
 
	BL		empty_wordQ
	B.eq	190f

	BL		start_point

200:
	LDR		X21, [X28, #48] ; name field

	CMP		X21, #0		; end of list?
	B.eq	190f		; not found 
	CMP		X21, #-1	; undefined entry in list?
	b.eq	170f

	BL		get_word
	LDR		X21, [X28, #48] ; name field
	CMP		X21, X22		; is this our word?
	B.ne	170f

	LDR		X21, [X28, #56] ; next 8
	BL		get_word2
	CMP		X21, X22		;  
	B.ne	170f			; that was 16 bytes..


	LDR		X2,	 [X28, #8] 

	; variables in four sizes

	ADRP	X1, dvaraddz@PAGE	; high level word.	
	ADD		X1, X1, dvaraddz@PAGEOFF
	CMP 	X2, X1
	B.eq	160f 

	ADRP	X1, dWvaraddz@PAGE	; high level word.	
	ADD		X1, X1, dWvaraddz@PAGEOFF
	CMP 	X2, X1
	B.eq	130f 

	ADRP	X1, dWarrayvalz@PAGE	; high level word.	
	ADD		X1, X1, dWarrayvalz@PAGEOFF
	CMP 	X2, X1
	B.eq	130f 

	ADRP	X1, dHWvaraddz@PAGE	; high level word.	
	ADD		X1, X1, dHWvaraddz@PAGEOFF
	CMP 	X2, X1
	B.eq	120f 


	ADRP	X1, dCvaraddz@PAGE	; high level word.	
	ADD		X1, X1, dCvaraddz@PAGEOFF
	CMP 	X2, X1
	B.eq	140f 

	; values
	
	ADRP	X1, dvaluez@PAGE	; high level word.	
	ADD		X1, X1, dvaluez@PAGEOFF
	CMP 	X2, X1
	B.eq	160f 


	; arrays in four sizes
	ADRP	X1, darrayaddz@PAGE	; high level word.
	ADD		X1, X1, darrayaddz@PAGEOFF
	CMP 	X2, X1
	B.eq	160f 

	ADRP	X1, dWarrayaddz@PAGE	; high level word.
	ADD		X1, X1, dWarrayaddz@PAGEOFF
	CMP 	X2, X1
	B.eq	130f 


	ADRP	X1, dlocalsWvalz@PAGE	; high level word.
	ADD		X1, X1, dlocalsWvalz@PAGEOFF
	CMP 	X2, X1
	B.eq	130f 

	ADRP	X1, dHWarrayaddz@PAGE	; high level word.
	ADD		X1, X1, dHWarrayaddz@PAGEOFF
	CMP 	X2, X1
	B.eq	120f 

	ADRP	X1, dCarrayaddz@PAGE	; high level word.
	ADD		X1, X1, dCarrayaddz@PAGEOFF
	CMP 	X2, X1
	B.eq	140f 


	; value arrays in four sizes.

	ADRP	X1, darrayvalz@PAGE	; high level word.
	ADD		X1, X1, darrayvalz@PAGEOFF
	CMP 	X2, X1
	B.eq	160f 


	ADRP	X1, dstackz@PAGE	; high level word.
	ADD		X1, X1, dstackz@PAGEOFF
	CMP 	X2, X1
	B.eq	160f 

	; LOCALS
	ADRP	X1, dlocalsvalz@PAGE	; high level word.
	ADD		X1, X1, dlocalsvalz@PAGEOFF
	CMP 	X2, X1
	B.eq	160f 

	ADRP	X1, dCarrayvalz@PAGE	; high level word.
	ADD		X1, X1, dCarrayvalz@PAGEOFF
	CMP 	X2, X1
	B.eq	150f 

	ADRP	X1, dSTRINGz@PAGE	; high level word.
	ADD		X1, X1, dSTRINGz@PAGEOFF
	CMP 	X2, X1
	B.eq	150f 

	; not a word we understand 
	B 		190f



; we may specialize (TO) for the Q(L), W, HW, C data sizes

120:	; HW word

	

130:	; TO for W sized word

 	MOV		X0, X28 ; word address
	BL 		longlitit
	ADD		X15, X15, #2
	MOV  	X0, #44; (WTO) just wide types
	STRH    W0, [X15]     
	LDP		LR, XZR, [SP], #16	
	RET


140:	; C byte

 

150:	; GENERIC  TO knows about all TO-able words

	MOV		X0, X28 ; word address
	BL 		longlitit
	ADD		X15, X15, #2
	MOV  	X0, #31; (TO) generic
	STRH    W0, [X15]     
	LDP		LR, XZR, [SP], #16	
	RET

	
160:	; LONG QUAD 64bits 

	MOV		X0, X28 ; word address
	BL 		longlitit
	ADD		X15, X15, #2
	MOV  	X0, #46; (LTO) generic
	STRH    W0, [X15]     
	LDP		LR, XZR, [SP], #16	
	RET


	B  		190f  ; not a word we can update 

170:	; next word in dictionary
	SUB		X28, X28, #64
	B		200b

190:	; error out 

	ADRP	X0, tcomer33@PAGE	; high level word.
	ADD		X0, X0, tcomer33@PAGEOFF
	BL		sayit_err

	LDP		LR, XZR, [SP], #16	
	MOV		X0, #-1	; not a word TO can use
 
	RET



; LITERALS 


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


loopdepth:
	LDR		X1, [SP]
	SUB		X0, X14, X1	  ; local words R depth
	STR 	X0, [X16], #8
	RET


diloopz: ; special I loop variable
	CBZ		X15, dont_crash_in_interpreter
	LDR		X1, [SP]
	SUB		X0, X14, X1	  ; local words R depth
	CMP		X0, #32
	B.lt 	loop_index_err

	LDP		X0, X1,  [X14, #-16]
	LDP		X2, XZR, [X14, #-32]	
	B		loop_var_check	

djloopz: ; special J loop variable
	CBZ		X15, dont_crash_in_interpreter
 	LDR		X1, [SP]
	SUB		X0, X14, X1	  ; local words R depth
	CMP		X0, #64
	B.lt 	loop_index_err

	LDP		X0, X1,  [X14, #-48]
	LDP		X2, XZR, [X14, #-64]	
	B		loop_var_check	


dkloopz: ; special K loop variable

	CBZ		X15, dont_crash_in_interpreter
 	LDR		X1, [SP]
	SUB		X0, X14, X1	  ; local words R depth
	CMP		X0, #96	
	B.lt 	loop_index_err

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
	LDP		X14, XZR, [SP], #16
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

dont_crash_in_interpreter:
	B dinterp_invalid
 
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

;; All our strings are 
;; - guaranteed to be well aligned allowing us to use 16 byte reads.
;; - always unique
;; - stored in the same string literal pool
;; - ASCII
;; - zero terminated
;; - have 256 bytes for capacity.
;; use the larger shared BUFFER$ as a temp

;; The most annoying problems with Strings, is 'where do they live' and for how long.
;; Standard FORTH puts them into the alloted space in the dictionary, for ever.
;; I am placing them in a giant string pool for ever instead.
;; I feel like I need a string stack for temporaries and string operations. 



; store string at BUFFER$ into strings pool.
; APPEND$>

dstfromappendbuffer:

	STP		LR,  XZR, [SP, #-16]!
	STP		X12,  X13, [SP, #-16]!
	STP		X3,  X5, [SP, #-16]!

	ADRP	X0, append_buffer@PAGE		
	ADD		X0, X0, append_buffer@PAGEOFF
	
	save_registers
	BL 		_add_string
	restore_registers


450:
 
	BL		stackit

	LDP		X3, X5, [SP], #16	
	LDP		X12, X13, [SP], #16	
	LDP		LR, XZR, [SP], #16	

	RET

490:
	ADRP	X0, tcomer36@PAGE		
	ADD		X0, X0, tcomer36@PAGEOFF
	BL 		sayit_err	
	LDP		X3, X5, [SP], #16	
	LDP		X12, X13, [SP], #16	
	LDP		LR, XZR, [SP], #16	
	MOV 	X0, #-1
	RET

500:	
	LDP		X3, X5, [SP], #16	
	LDP		X12, X13, [SP], #16	
	LDP		LR, XZR, [SP], #16	
	
	RET


dstrappendbegin:
	; prepare buffer
	ADRP	X1, append_buffer@PAGE		
	ADD		X1, X1, append_buffer@PAGEOFF
    ADRP	X0, append_ptr@PAGE		
	ADD		X0, X0, append_ptr@PAGEOFF
    STR		X1, [X0] ;
	MOV 	X0, #0
	STRB	W0, [X1] 
	RET

; called by (,) X1 has append_ptr
dstrappendcommafromstack:
	LDR		X1, [X16, #-8]
	SUB 	X16, X16, #8
	B		dstrappender

 
dstrappendcomma:

	ADRP	X1, string_buffer@PAGE		
	ADD		X1, X1, string_buffer@PAGEOFF

dstrappender:

	ADRP	X0, append_ptr@PAGE		
	ADD		X0, X0, append_ptr@PAGEOFF
	LDR		X0, [X0]

 
	MOV 	W2, #0
	MOV 	W3, #255
	save_registers

	BL 		_memccpy

	restore_registers
	; X0 has new address for appender

110:
 
	ADRP	X1, append_ptr@PAGE		
	ADD		X1, X1, append_ptr@PAGEOFF
	STR		X0, [X1]
	RET

500:
	ADRP	X0, not_appending_err@PAGE		
	ADD		X0, X0, not_appending_err@PAGEOFF
	B 		sayit_err
	RET


dstrappendend:

	MOV 	X0, #0 ; not appending
	ADRP	X1, append_ptr@PAGE		
	ADD		X1, X1, append_ptr@PAGEOFF
	STR		X0, [X1]

	B 	dstfromappendbuffer
	RET


; dumb as a rock append
dstrappend:

	; prepare buffer
	ADRP	X1, string_buffer@PAGE		
	ADD		X1, X1, string_buffer@PAGEOFF
	MOV 	X2, X1 
	.rept	64
		STP		XZR, XZR, [X1], #16
	.endr
	MOV		X1, X2

	LDP		X2, X3, [X16, #-16]
	SUB		X16, X16, #16

	CBZ		X2, 500f
	CBZ		X3, 500f

100:
	LDRB	W0, [X2],#1
	CBZ		W0, 110f  
	STRB	W0, [X1],#1	
	B  		100b

110:
	LDRB	W0, [X3],#1
	CBZ		W0, 120f 
	STRB	W0, [X1],#1	
	B 		110b
 
120:

500:

	ADRP	X0, string_buffer@PAGE		
	ADD		X0, X0, string_buffer@PAGEOFF
	save_registers
	BL 		_add_string
	restore_registers
 

450:	
	BL		stackit

	LDP		X3, X5, [SP], #16	
	LDP		X12, X13, [SP], #16	
	LDP		LR, XZR, [SP], #16	

	RET



;; a way to fetch string addresses from STRING storage pools

dstringstoragearrayvalz:	; return the value from the string pool index
; X0=data, X1=word
	LDR		X2, [X16, #-8]	; X2 = index
	LDR		X1, [X1, #32]   ; X1 array size 
	CMP		X2, X1
	B.gt	darrayaddz_index_error
	LSL		X2, X2, #8 ; string 256
	ADD		X1, X0, X2 ; data + index 
	STR		X1, [X16, #-8]	; value of data
	RET


_dstrequalz:

	LDP		X12, X13, [X16, #-16]
	SUB		X16, X16, #16

	CBZ		X12, 160f
	CBZ		X13, 160f
 
	ADRP	X1, below_string_space@PAGE		
	ADD		X1, X1, below_string_space@PAGEOFF
	CMP 	X12, X1
	B.lt 	160f
	CMP 	X13, X1
	B.lt 	160f

	
	; compare up to 256 bytes 16 at a time
	.rept 16
		LDP		X0, X1, [X13], #16
		LDP		X2, X3, [X12], #16
		CMP		X0, X2
		B.ne	160f 
		CMP		X1, X3
		B.ne	160f 
		CMP     X0, #0	; end of string
		B.eq	150f
	.endr

	150:
	MVN		X0, XZR ; true
	STR		X0, [X16], #8
	RET

	160:
	MOV 	X0, XZR ; false
	STR		X0, [X16], #8
	RET

; length of string.
 
dstrlen:

	LDR 	X0, [X16, #-8]
	CBZ		X0, 10f
	save_registers
	BL		_strlen
	restore_registers
10:
	STR 	X0, [X16, #-8]
	RET

 


dstrpos:
	LDP		X1, X0, [X16, #-16]
	SUB 	X16, X16, #16
	save_registers
	BL 		 _strchr
	restore_registers	 
	STR		X0, [X16], #8
	RET


; slices a string  
; X3 address. x2 pos, X1 count 
; I feel like the original immutable value ought to be the backing storage for a slice.

dstrslice:

	STP		LR,  XZR, [SP, #-16]!
	STP		X12, X13, [SP, #-16]!
	STP		X3,  X5, [SP, #-16]!


	ADRP	X0, slice_string@PAGE		
	ADD		X0, X0, slice_string@PAGEOFF

	; Clean slice buffer
	ADRP	X12, slice_string@PAGE		
	ADD		X12, X12, slice_string@PAGEOFF
	.rept	64
		STP		XZR, XZR, [X12], #16
	.endr

5:
	LDP		X3, X2, [X16, #-16]
	SUB 	X16, X16, #16
	LDR		X1, [X16, #-8]
	SUB 	X16, X16, #8
 
 
	ADD		X3, X1, X3 	 

	ADRP	X12, below_string_space@PAGE		
	ADD		X12, X12, below_string_space@PAGEOFF
	CMP 	X3, X12
	B.lt 	99f


	ADD		X2, X2, #1
10:
	SUB 	X2, X2, #1
	CBZ		X2, 20f
	LDRB 	W1, [X3], #1
	STRB	W1,	[X0], #1

	CBNZ	W1, 10b  


20:
	MOV 	W1, #0
	STRB	W1, [X0]
 

90:

	; now copy from slice to string buffer
	; later copy from string buffer to string
	ADRP	X12, slice_string@PAGE		
	ADD		X12, X12, slice_string@PAGEOFF
	ADRP	X13, string_buffer@PAGE		
	ADD		X13, X13, string_buffer@PAGEOFF
	.rept 16
		LDP		X0, X1, [X12], #16
		STP		X0, X1, [X13], #16
	.endr

	B intern_string_from_buffer

99: ; 0 in 0 out, 0 all the way.

	LDP		X3, X5, [SP], #16	
	LDP		X12, X13, [SP], #16	
	LDP		LR, XZR, [SP], #16	
	MOV 	X0, #0
	B 		stackit
	RET



dstrcmp:

	; just use c library
	LDP		X0, X1, [X16, #-16]
	ADD  	X16, X16, #16
	MOV 	W2,	 #255
	save_registers
	bl		_strncmp
	restore_registers
	STR		X0, [X16], #8
	RET
 

	; ...  not using C library
	LDP		X12, X13, [X16, #-16]
	SUB		X16, X16, #16
	
	CBZ		X12, 05f
	CBZ		X13, 05f

	CMP		X12, X13 	; structural identity
	B.eq	05f

	; compare up to 256 bytes 16 at a time
	.rept 16
		LDP		X0, X1, [X13], #16
		LDP		X2, X3, [X12], #16
		CMP		X0, X2
		B.ne	160f 
		CMP		X1, X3
		B.ne	160f 
		CMP     X0, #0	; end of string
		B.eq	150f
	.endr

	150:
	MOV		X0, XZR ; true the same = 0
	STR		X0, [X16], #8
	RET

	160:    ; not the same

	SUB 	X12, X12, #16
	SUB		X13, X13, #16

	.rept 	16
	LDRB	W0, [X13],#1
	LDRB	W1, [X12],#1
	CMP 	X1, X0		
	B.lt	10f
	B.gt	20f
	.endr

	05:
	MVN		X0, XZR ; true the same (impossible)
	STR		X0, [X16], #8
	RET
 
	10:
	MVN		X0, XZR ;-1 
	STR		X0, [X16], #8
	RET

	20:
	MOV		X0, #1
 	STR		X0, [X16], #8
	RET		

	; relies on our `no duplicate rule`, a different string
	; also must be a different object.

dstrequalz:
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


dSTRINGz: ; return our address..
	STR		X0, [X16], #8
	RET


; true if X12 contains X13
dstrcontains:

	LDP		X13, X12, [X16, #-16]
	SUB 	X16, X16, #8
	MOV     X3, X13

05:	
	LDRB	W0,[X13]
	CBZ		X0, 200f

10:	
	LDRB    W1,[X12]
	CBZ		X1, 200f
	CMP		W0, W1, uxtb
	B.eq	25f  
	ADD		X12, X12, #1
	B 		10b 
25:
	MOV 	X2, X12
30:
	LDRB	W0, [X12] 
	LDRB	W1, [X13] 
	CBZ		X1, 100f 
	CBZ     X0, 200f
	CMP		W0, W1, uxtb
	B.ne	300f
	ADD		X13, X13, #1
	ADD		X12, X12, #1
	B 		30b 

100:
	MVN		X0, XZR
	STR		X0, [X16],#8
	RET

200:
	MOV		X0, XZR
	STR		X0, [X16],#8
	RET

 
; search X12, for X13 return address found.
dstrfind:

	LDP		X13, X12, [X16, #-16]
	SUB 	X16, X16, #8
	MOV     X3, X13

05:	
	LDRB	W0,[X13]
	CBZ		X0, 200f

10:	
	LDRB    W1,[X12]
	CBZ		X1, 200f
	CMP		X0, X1
	B.eq	25f  
	ADD		X12, X12, #1
	B 		10b 

	; we have a match
	; for a while
 
25:
	MOV 	X2, X12
30:
	LDRB	W0, [X12] 
	LDRB	W1, [X13] 
	CBZ		X1, 100f 
	CBZ     X0, 200f
	CMP 	X0, X1
	B.ne	300f
	ADD		X13, X13, #1
	ADD		X12, X12, #1
	B 		30b 

100:
	MOV		X0, X2
	STR		X0, [X16],#8
	RET

200:
	MOV		X0, XZR
	STR		X0, [X16],#8
	RET

300: ; look at rest of string for sub string
	MOV X13, X3
	B 	05b


; create string 

creatstring:

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
	B.eq	280f		; not found 
	CMP		X1, #-1		; undefined entry in list?
	b.ne	260f

    ; undefined so build the word here

	; this is now the last_word word being built.
	ADRP	X1, last_word@PAGE		
	ADD		X1, X1, last_word@PAGEOFF
	STR		X28, [X1]

	; copy text for name over
	copy_word_name

	; variable code
	ADRP	X1, dSTRINGz@PAGE	; high level word.	
	ADD		X1, X1, dSTRINGz@PAGEOFF
	STR		X1, [X28, #8]

	; ; set value from the string on the stack
	LDR		X0, [X16, #-8]	
	SUB		X16, X16, #8
	CMP		X0,  #256
	B.gt 	150f

	; allotation
	STR		X0, [X28, #32] ; array size 
	save_registers
	MOV 	W1, #1
	BL		_calloc
	restore_registers
	CBZ 	X0, calloc_failed 
	STR		X0, [X28]
 
	B 		300f


150: ; we had a string literal
	STR		X0, [X28]	; data pointer
	MOV 	X0, #255
	STR		X0, [X28, #32]
	B		300f

260:	; try next word in dictionary
	SUB		X28, X28, #64
	B		100b


280:	; error dictionary FULL

300:

	restore_registers_not_stack
	RET

; run time .'  for interpreter only

dstrdotz:

	STP		LR,  XZR, [SP, #-16]!
	STP		X12,  X13, [SP, #-16]!
	STP		X3,  X5, [SP, #-16]!

	ADRP	X12, string_buffer@PAGE		
	ADD		X12, X12, string_buffer@PAGEOFF
	MOV 	X2, X12 
	.rept	64
		STP		XZR, XZR, [X12], #16
	.endr
	MOV    X12, X2
	

	; copy bytes from input to string_buffer
	MOV 	X2, #255
100:
	LDRB	W0, [X23], #1
	CMP		W0, #39 ; ' 
	B.eq	120f 
	STRB	W0, [X12], #1
	SUB 	X2, X2, #1
	CBZ  	X2, 120f

	CMP		W0, #10 ; ' 
	B.eq	500f 
	CMP		W0, #13 ; ' 
	B.eq	500f 
	CBZ  	W0, 500f

	B 		100b

120:

	MOV 	W0, #0
	STRB	W0, [X12]


	ADRP	X0, string_buffer@PAGE		
	ADD		X0, X0, string_buffer@PAGEOFF
	save_registers
	BL 		_add_string
	restore_registers
	BL		sayit

	LDP		X3, X5, [SP], #16	
	LDP		X12, X13, [SP], #16	
	LDP		LR, X15, [SP], #16	

	RET


 
dstrstksz: ; runtime S" .. " stash and return address

	STP		LR,  XZR, [SP, #-16]!
	STP		X12,  X13, [SP, #-16]!
	STP		X3,  X5, [SP, #-16]!

	ADRP	X12, string_buffer@PAGE		
	ADD		X12, X12, string_buffer@PAGEOFF
	MOV 	X2, X12 
	.rept	64
		STP		XZR, XZR, [X12], #16
	.endr
	MOV    X12, X2
	

	; copy bytes from input to string_buffer
	MOV 	X2, #255
 
100:
	LDRB	W0, [X23], #1
	CMP		W0, #39 ; ' 
	B.eq	120f 
	STRB	W0, [X12], #1
	SUB 	X2, X2, #1
	CBZ  	X2, 120f

	CMP		W0, #10 ; ' 
	B.eq	500f 
	CMP		W0, #13 ; ' 
	B.eq	500f 
	CBZ  	W0, 500f

	B 		100b


120:

	MOV 	W0, #0
	STRB	W0, [X12]

intern_string_from_buffer:

	; we have to intern if we are compiling.
	CBNZ	X15, 128f
	; exit if appending do not store
	ADRP	X1, append_ptr@PAGE		
	ADD		X1, X1, append_ptr@PAGEOFF
	LDR		X1, [X1]
	CBNZ 	X1, 500f

128:
	ADRP	X0, string_buffer@PAGE		
	ADD		X0, X0, string_buffer@PAGEOFF
	save_registers
	BL 		_add_string
	restore_registers
 

450:	
	BL		stackit

	LDP		X3, X5, [SP], #16	
	LDP		X12, X13, [SP], #16	
	LDP		LR, XZR, [SP], #16	

	RET



dstrdotc:

	STP		LR,  XZR, [SP, #-16]!
	STP		X12,  X13, [SP, #-16]!
	STP		X3,  X5, [SP, #-16]!
	 

	ADRP	X12, string_buffer@PAGE		
	ADD		X12, X12, string_buffer@PAGEOFF
	MOV 	X2, X12 
	.rept	64
		STP		XZR, XZR, [X12], #16
	.endr
	MOV    X12, X2
	

	; copy bytes from input to string_buffer
	MOV 	X2, #255
100:
	LDRB	W0, [X23], #1
	CMP		W0, #39 ; ' 
	B.eq	120f 
	STRB	W0, [X12], #1
	SUB 	X2, X2, #1
	CBZ  	X2, 120f

	CMP		W0, #10 ; ' 
	B.eq	500f 
	CMP		W0, #13 ; ' 
	B.eq	500f 
	CBZ  	W0, 500f

	B 		100b


120:

	MOV 	W0, #0
	STRB	W0, [X12]

	ADRP	X0, string_buffer@PAGE		
	ADD		X0, X0, string_buffer@PAGEOFF

 
	save_registers
	BL 		_add_string
	restore_registers
 

	BL 		longlitit 
 
	ADD		X15, X15, #2
	MOV		W0, #52 ; (.S)
	STRH	W0, [X15] 
 

	LDP		X3, X5, [SP], #16	
	LDP		X12, X13, [SP], #16	
	LDP		LR, XZR, [SP], #16	

	RET

490:
	ADRP	X0, tcomer36@PAGE		
	ADD		X0, X0, tcomer36@PAGEOFF
	BL 		sayit_err	

	LDP		X3, X5, [SP], #16	
	LDP		X12, X13, [SP], #16	
	LDP		LR, XZR, [SP], #16	
	
	MOV 	X0, #-1
	RET

500:	

	LDP		X3, X5, [SP], #16	
	LDP		X12, X13, [SP], #16	
	LDP		LR, XZR, [SP], #16	
	
	
	RET



dstrstksc: ; compile literal that returns its address.


	STP		LR,  XZR, [SP, #-16]!
	STP		X12,  X13, [SP, #-16]!
	STP		X3,  X5, [SP, #-16]!
 

	ADRP	X12, string_buffer@PAGE		
	ADD		X12, X12, string_buffer@PAGEOFF
	MOV 	X2, X12 
	.rept	64
		STP		XZR, XZR, [X12], #16
	.endr
	MOV    X12, X2
	

	; copy bytes from input to string_buffer
	MOV 	X2, #255
100:
	LDRB	W0, [X23], #1
	CMP		W0, #39 ; ' 
	B.eq	120f 
	STRB	W0, [X12], #1
	SUB 	X2, X2, #1
	CBZ  	X2, 120f

	CMP		W0, #10 ; ' 
	B.eq	500f 
	CMP		W0, #13 ; ' 
	B.eq	500f 
	CBZ  	W0, 500f

	B 		100b


120:

	MOV 	W0, #0
	STRB	W0, [X12]

	ADRP	X0, string_buffer@PAGE		
	ADD		X0, X0, string_buffer@PAGEOFF
	save_registers
	BL 		_add_string
	restore_registers
	
	BL		longlitit
 
 
	LDP		X3, X5, [SP], #16	
	LDP		X12, X13, [SP], #16	
	LDP		LR, XZR, [SP], #16		

	RET

490:
	ADRP	X0, tcomer36@PAGE		
	ADD		X0, X0, tcomer36@PAGEOFF
	BL 		sayit_err	
	LDP		X3, X5, [SP], #16	
	LDP		X12, X13, [SP], #16	
	LDP		LR, XZR, [SP], #16	
	MOV 	X0, #-1
	RET

500:	

	LDP		X3, X5, [SP], #16	
	LDP		X12, X13, [SP], #16	
	LDP		LR, XZR, [SP], #16	
	
	RET


; print a literal string, lit on stack
dslitSzdot: 
 
   
	B 		ztypez
	
 
	RET

; fetch address of a short literal string, inline literal
dslitSz:
	 

 
	RET


; fetch address of long literal string, inline literal
dslitLz:
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

; ALLOT extra BYTES of memory to a variable
; 0 VARIABLE test  200 ALLOT> test
; 
allotoz: 
	RET
 

allot_memory_full: ; display err


	; undo allot
	ADRP	X8, allot_last@PAGE	
	ADD		X8, X8, allot_last@PAGEOFF
	LDR		X1, [X8]
	ADRP	X8, allot_ptr@PAGE	
	ADD		X8, X8, allot_ptr@PAGEOFF
	STR		X1, [X8]

	ADRP	X0, tcomer31@PAGE	
	ADD		X0, X0, tcomer31@PAGEOFF
	B		sayit
	
	 
// creation words are invalid in a compiled word
dcreat_invalid:

	ADRP	X0, create_error@PAGE		
	ADD		X0, X0, create_error@PAGEOFF
	B 		sayit_err

 
// creation words are invalid in a compiled word
dinterp_invalid:

	ADRP	X0, inter_error@PAGE		
	ADD		X0, X0, inter_error@PAGEOFF
	B 		sayit_err
 
 // compile time words are not valid in interpreter
dip_invalid:
	ADRP	X0, ip_error@PAGE		
	ADD		X0, X0, ip_error@PAGEOFF
	B 		sayit_err
 

dallotablez: ; Can we allot to this word type

	LDR		X2, [X16, #-8]
	LDR     X2, [X2,#8 ]

	ADRP	X1, dvaluez@PAGE	
	ADD		X1, X1, dvaluez@PAGEOFF
	CMP 	X2, X1
	B.eq	150f

	ADRP	X1, dvaraddz@PAGE	
	ADD		X1, X1, dvaraddz@PAGEOFF
	CMP 	X2, X1
	B.eq	150f


	MOV     X2, #0
	STR		X2, [X16, #-8]
	RET

150:
	MOV 	X2, #-1
	STR		X2, [X16, #-8]
	RET


; 10 RND - 0..9 number
; Thanks to Kjell Post (kjepo)
; https://github.com/kjepo/XOR-LFSR

drandomz:  
	LDR	   	X1, [X16, #-8] 
	ADRP   	X8, random_seed@PAGE	
	ADD	   	X8, X8, random_seed@PAGEOFF
	LDR    	X0, [X8]
	EOR    	X0, X0, X0, LSL #13  
	EOR    	X0, X0, X0, LSR #7   
	EOR    	X0, X0, X0, LSL #17  
	STR		X0, [X8]
 	UDIV	X2, X0, X1
	MSUB	X3, X2, X1, X0 
	STR		X3, [X16, #-8]
	RET

; called from init to seed the generator
randomize: 
	save_registers
	ADRP   X0, random_seed@PAGE	
	ADD	   X0, X0, random_seed@PAGEOFF
	MOV    X1, #8
	BL     _getentropy
	restore_registers
	RET

 dcopyc:
	LDP 	X0, X1, [X16, #-16]
	LDRB	W2, [X0]
	STRB	W2, [X1]
	ADD		X0, X0, #1
	ADD		X1, X1, #1
	STP 	X0, X1, [X16, #-16]
	RET

 dcopy2c:
	LDP 	X0, X1, [X16, #-16]
	LDRB	W2, [X0]
	STRB	W2, [X1]
	ADD		X0, X0, #1
	ADD		X1, X1, #1
	LDRB	W2, [X0]
	STRB	W2, [X1]
	ADD		X0, X0, #1
	ADD		X1, X1, #1
	STP 	X0, X1, [X16, #-16]
	RET

 dcopy3c:
	LDP 	X0, X1, [X16, #-16]
	LDRB	W2, [X0]
	STRB	W2, [X1]
	ADD		X0, X0, #1
	ADD		X1, X1, #1
	LDRB	W2, [X0]
	STRB	W2, [X1]
	ADD		X0, X0, #1
	ADD		X1, X1, #1
	LDRB	W2, [X0]
	STRB	W2, [X1]
	ADD		X0, X0, #1
	ADD		X1, X1, #1
	STP 	X0, X1, [X16, #-16]
	RET


 
 dcopy:
	LDP 	X0, X1, [X16, #-16]
	LDR		X2, [X0]
	STR		X2, [X1]
	ADD		X0, X0, #8
	ADD		X1, X1, #8
	STP 	X0, X1, [X16, #-16]
	RET

 d2copy:
	LDP 	X0, X1, [X16, #-16]
	LDR		X2, [X0]
	STR		X2, [X1]
	ADD		X0, X0, #8
	ADD		X1, X1, #8
	LDR		X2, [X0]
	STR		X2, [X1]
	ADD		X0, X0, #8
	ADD		X1, X1, #8
	STP 	X0, X1, [X16, #-16]
	RET


dparamchkz:
	CBZ     X15, dip_invalid
	LDR		X0, [X16, #-8]
	SUB 	X16, X16, #8
	ADRP	X8, dsp@PAGE		
	ADD		X8, X8, dsp@PAGEOFF
	LDR		X1, [X8]
	SUB		X1, X16, X1
	LSR		X1, X1, #3
	CMP		X0, X1 
	B.gt 	100f 
	RET

; copy n params to LOCALS

dparamsz:
	CBZ     X15, dip_invalid
	LDR		X0, [X16, #-8]
	SUB 	X16, X16, #8

	MOV		X1, #8
	CMP		X0, X1
	B.gt 	101f 
	

	ADRP	X8, dsp@PAGE		
	ADD		X8, X8, dsp@PAGEOFF
	LDR		X1, [X8]
	SUB		X1, X16, X1
	LSR		X1, X1, #3
	CMP		X0, X1
	B.gt 	100f 

	; copy parameters to locals
	MOV 	X2, X26
10:
	LDR		X1, [X16, #-8]
	STR		X1, [X26, #-8]
	SUB		X16, X16, #8
	SUB		X26, X26, #8
	SUB 	X0, X0, #1
	CBNZ	X0,	10b 
90:
	MOV 	X26, X2 
	RET


	; stack too shallow , quit
100:
	BL		saycr
	BL		saylb
	LDR		X0, [X26, #-72]	 ; self
	ADD		X0, X0, #48
	BL 		sayit
	BL		sayrb
	ADRP	X0, tcomer48@PAGE
	ADD		X0, X0, tcomer48@PAGEOFF 
	B 		110f 

	; only room for 8 parameters
101:
	ADRP	X0, tcomer49@PAGE
	ADD		X0, X0, tcomer49@PAGEOFF 
	B 		110f 
 

110:
	BL		sayit_err
	LDP		X14, X26, [SP], #16
	LDP		LR, X15, [SP], #16	
	RET 

dparamsc:
	RET



findalias2: ; deep alias resoloution
	save_registers
	ADRP	X12, alias_table@PAGE
	ADD		X12, X12, alias_table@PAGEOFF
	BL		advancespaces
	BL		collectwordnoalias
 	BL		get_word
	BL		empty_wordQ
	B.eq	190f
	BL 		find_alias
	restore_registers


	CBZ 	X0, 10f

30:	
	MOV 	X5, X0 
	ADRP	X22, zword@PAGE		
	ADD		X22, X22, zword@PAGEOFF
	ADD		X4, X0, #16
	LDP		X0, X1, [X4]
	STP 	X0, X1, [X22]
	save_registers
	BL 		find_alias
	restore_registers
	CBZ 	X0, 20f
	B 		30b

20:
	MOV 	X0, X5
10:
	STR 	X0, [X16], #8 ; thing we found
	RET

findalias:
	save_registers
	ADRP	X12, alias_table@PAGE
	ADD		X12, X12, alias_table@PAGEOFF
	BL		advancespaces
	BL		collectwordnoalias
 	BL		get_word
	BL		empty_wordQ
	B.eq	190f
	BL 		find_alias
	restore_registers
	STR 	X0, [X16], #8 ; thing we found
	RET

find_alias:
	save_registers
	ADRP	X1, alias_table@PAGE
	ADD		X1, X1, alias_table@PAGEOFF
	MOV		W2, #256
	MOV		W3, #32
	ADRP	X4, aliassort@PAGE
	add		X4, X4, aliassort@PAGEOFF
	ADRP	X0, zword@PAGE		
	ADD		X0, X0, zword@PAGEOFF
	BL		_bsearch
	restore_registers
	RET

clralias:
	; X1 = fill; X2=count; X0=address
	STP		LR,  X12, [SP, #-16]!
	STP		X2,  X13, [SP, #-16]!
	ADRP	X12, alias_table@PAGE
	ADD		X12, X12, alias_table@PAGEOFF
	ADRP	X13, alias_limit@PAGE
	ADD		X13, X13, alias_limit@PAGEOFF
	SUB 	X2, X13, X12
	MOV 	X0, X12
	MOV 	X1, #0
	BL 		fill_mem
	LDP		X2, X13, [SP], #16
	LDP		LR, X12, [SP], #16	
	RET

; UNALIAS word - reMOVe an alias

unalias:

	save_registers
	
	ADRP	X12, alias_table@PAGE
	ADD		X12, X12, alias_table@PAGEOFF
	ADRP	X13, alias_limit@PAGE
	ADD		X13, X13, alias_limit@PAGEOFF

	BL		advancespaces
	BL		collectwordnoalias
 	BL		get_word
	BL		empty_wordQ
	B.eq	190f

	save_registers
	ADRP	X1, alias_table@PAGE
	ADD		X1, X1, alias_table@PAGEOFF
	MOV		W2, #256
	MOV		W3, #32
	ADRP	X4, aliassort@PAGE
	add		X4, X4, aliassort@PAGEOFF
	ADRP	X0, zword@PAGE		
	ADD		X0, X0, zword@PAGEOFF

	BL		_bsearch
	restore_registers
  	CBZ		X0, 150f 
	MOV 	X12, X0 

130: 
	MOV 	X0, X12	; dest
	ADD		X1, X12, #32 ; source

	ADRP	X12, alias_table@PAGE
	ADD		X12, X12, alias_table@PAGEOFF
	SUB 	X3, X0, X12
	MOV     X2, #8192
	SUB  	X2, X2, X3
	BL		_memcpy

150:
	restore_registers

	RET


; sort the alias list
aliassort:
.cfi_startproc
	STP	X29, X30, [sp, #-16]!           
	MOV	X29, sp
	.cfi_def_cfa W29, 16
	.cfi_offset W30, -8
	.cfi_offset W29, -16
	MOV	W2, #16
	BL	_strncmp
	LDP	X29, X30, [sp], #16           
	ret
	.cfi_endproc

sortalias:
	save_registers
 	ADRP	X0, alias_table@PAGE
	add		X0, X0, alias_table@PAGEOFF
	ADRP	X3, aliassort@PAGE
	add		X3, X3, aliassort@PAGEOFF
	MOV		W1, #256
	MOV		W2, #32
	bl		_qsort
	restore_registers
	RET

; add an alias (text substitution) to the alias table

creatalias:

	save_registers
	
	ADRP	X12, alias_table@PAGE
	ADD		X12, X12, alias_table@PAGEOFF
	ADRP	X13, alias_limit@PAGE
	ADD		X13, X13, alias_limit@PAGEOFF


	; find free alias slot
10:	LDRB	W0, [X12]	
	CBZ		X0, 30f 
	ADD		X12, X12, #32
	CMP		X12, X13
	B.gt	210f
	B 		10b

30:
	; get first word
	BL		advancespaces
	BL		collectwordnoalias
 	BL		get_word
	BL		empty_wordQ
	B.eq	190f

	ADRP	X22, zword@PAGE		
	ADD		X22, X22, zword@PAGEOFF
	 
	; copy word name to alias
	LDP		X0, X1, [X22]
	STP 	X0, X1, [X12], #16

	; Second word
	BL		advancespaces
	BL		collectwordnoalias
    BL		get_word
	BL		empty_wordQ
	B.eq	200f

	ADRP	X22, zword@PAGE		
	ADD		X22, X22, zword@PAGEOFF
 
	; copy word name to alias
	LDP		X0, X1, [X22]
	STP 	X0, X1, [X12]
	BL 		sortalias
	restore_registers

	RET

190:
	restore_registers
	ADRP	X0, tcomer45@PAGE
	ADD		X0, X0, tcomer45@PAGEOFF
	B		sayit_err
 

200:
	restore_registers
	ADRP	X0, tcomer46@PAGE
	ADD		X0, X0, tcomer46@PAGEOFF
	B		sayit_err



210:
	restore_registers
	ADRP	X0, tcomer47@PAGE
	ADD		X0, X0, tcomer47@PAGEOFF
	B		sayit_err	



; ALLOT X0 cells
; cell size is LSL X3
; X3 = 0, 1, 2, 3
; n ALLOT

dallot:

	LDR		X0, [X16, #-8]
	SUB 	X16, X16, #8

   	ADRP	X8, last_word@PAGE		
	ADD		X8, X8, last_word@PAGEOFF
	LDR 	X8, [X8]
	LDR		X2, [X8, #8]

	ADRP	X1, dvaluez@PAGE	
	ADD		X1, X1, dvaluez@PAGEOFF
	CMP 	X2, X1
	MOV 	W3, #8
	B.eq	150f

	ADRP	X1, dvaraddz@PAGE	
	ADD		X1, X1, dvaraddz@PAGEOFF
	CMP 	X2, X1
	MOV 	W3, #8
	B.eq	150f

	STP		LR,  XZR, [SP, #-16]!

  	
	BL		saycr
	BL		saylb

	ADRP	X8, last_word@PAGE		
	ADD		X8, X8, last_word@PAGEOFF
	LDR		X8, [X8]
	ADD 	X0, X8, #48
	BL 		sayit
	BL		sayrb

	ADRP	X0, tcomer41@PAGE		
	ADD		X0, X0, tcomer41@PAGEOFF
	BL 		sayit
	LDP		LR, X15, [SP], #16	
	RET

150:


   	ADRP	X8, last_word@PAGE		
	ADD		X8, X8, last_word@PAGEOFF
	LDR		X1, [X8]
	STR		X0, [X1, #32]

	save_registers
	MOV 	W1, W3
	BL		_calloc
	restore_registers
	CBZ 	X0, calloc_failed 

	ADRP	X8, last_word@PAGE		
	ADD		X8, X8, last_word@PAGEOFF
	LDR		X1, [X8]
	STR		X0, [X1]


	RET


dliststrings:
	save_registers
	BL _list_strings
	restore_registers
	RET


;;;; DATA ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.data 

alias_table:    
	.rept 256
	.quad 0
	.quad 0
	.quad 0
	.quad 0
	.endr
alias_limit:   
	.quad 0
	.quad 0
 	.quad 0
	.quad 0

	.quad -1
	.quad -1
 	.quad -1
	.quad -1

; floats	

.align 8
fc1:		.double 	1.0

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

.zero 	4096
 prot4:

ivars:

.text

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
fdec:	.ascii "%.2f"
	.zero 16


.align	8
thex:	.ascii "%X"
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
thalfpr:	.ascii ": [%12ld] "
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
tcomer31: .ascii "\nError: ALLOT MEMORY FULL "
	.zero 16


.align	8
tcomer32: .ascii "\nError: ARRAY index invalid."
	.zero 16

.align	8
tcomer33: .ascii "\nError: TO can not update."
	.zero 16

 .align	8
tcomer34: .ascii "\nError in x FILLARRAY nnnnnn  - Needs a fillable Values, Array or LOCALS word."
	.zero 16

  .align	8
tcomer35: .ascii "\nError in x FILLARRAY nnnnn  - the nnnnn word not found."
	.zero 16

   .align	8
tcomer36: .ascii "\nError out of string space."
	.zero 16

 
   .align	8
tcomer37: .ascii "\nError FLAT expects name."
	.zero 16

  
   .align	8
tcomer38: .ascii "\nError FLAT expects a high level word."
	.zero 16

   .align	8
tcomer39: .ascii "\nError ; - while not compiling."
	.zero 16
 
   .align	8
tcomer40: .ascii "\nError TO expected a VALUE word to follow."
	.zero 16


   .align	8
tcomer41: .ascii " error ALLOT can only allot memory to variables."
	.zero 16

   .align	8
tcomer42: .ascii "\nError n ALLOT, expected the last word to be a variable or value word."
	.zero 16


   .align	8
tcomer43: .ascii "\nError TIMEIT expects a single words name."
	.zero 16

   .align	8
tcomer44: .ascii "\nError TIMEIT only works in the interpreter, not in compiled words."
	.zero 16


   .align	8
tcomer45: .ascii "\nError ALIAS is followed by the name"
	.zero 16

   .align	8
tcomer46: .ascii "\nError ALIAS name is followed by the old name."
	.zero 16

   .align	8
tcomer47: .ascii "\nError ALIAS table full."
	.zero 16

   .align	8
tcomer48: .ascii ": Error Not enough parameters (stack underflow)"
	.zero 16

   .align	8
tcomer49: .ascii "\nError only room for 8 parameters "
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
word_desc13: .ascii "Error: invalid memory access attempt"
	.zero 16


.align	8
word_desc14: .ascii "\t\t1 DIMENSION ARRAY OF 8 BYTE CELLS"
	.zero 16


.align	8
word_desc15: .ascii "\t\t1 DIMENSION ARRAY OF 4 BYTE CELLS"
	.zero 16

.align	8
word_desc16: .ascii "\t\t1 DIMENSION ARRAY OF 2 BYTE CELLS"
	.zero 16


.align	8
word_desc17: .ascii "\t\t1 DIMENSION ARRAY OF BYTES"
	.zero 16


.align	8
create_error: .ascii "\nError: use of CREATION words (VALUE, STRING etc) not allowed in compiled words."
	.zero 16

.align	8
inter_error: .ascii "\nError: use of some words not allowed outside of definitions."
	.zero 16

.align	8
ip_error: .ascii "\nError: IP (instruction pointer) invalid."
	.zero 16


.align	4
not_appending_err:
.align	8
.ascii "\nError: Not appending."
	.zero 16

.align 8
clear_screen:
	.byte 27,'[','2','J',27,'[','H',0
 
 .align 8
 screen_at:
	.asciz "\X1b[%d;%df"

.align 8
screen_textcolour:
	.asciz "\X1b[%dm"
 
 
.align	8
spaces:	.ascii "										"
	.zero 16

.align	8
 calloc_error: .ascii "\nCALLOC failed. Out of memory. Bye."
 	.zero 16

.data

; UNIX TERMINAL IO control
; long is 8 bytes
.align 8
saved_termios:
saved_c_iflag:		.quad 0		;0
saved_c_oflag:		.quad 0		;8
saved_c_cflag:		.quad 0		;16
saved_c_lflag:		.quad 0		;24
saved_cc_t:			.zero 20 	; 32
saved_c_ispeed:  	.quad 0	; 52
saved_c_ospeed:  	.quad 0	; 
.zero 64

.align 8
current_termios:
current_c_iflag:	.quad 0		;0
current_c_oflag:	.quad 0		;4
current_c_cflag:	.quad 0		;8
current_c_lflag:	.quad 0		;12
current_cc_t:	 	.zero 20 
current_c_ispeed:  	.quad 0
current_c_ospeed:  	.quad 0
.zero 64

.align 8
getchar_buf:		.quad 0
.zero 64

.align 8			
bytes_waiting:		.quad 0


read_fd:
	.zero 128

time_value:
	.zero 128

; this is the tokens pool
; code for token compiled words is compiled into here
; 
;  
.align 8

lasthere_ptr:	
	.quad	0
here_ptr:
	.quad	0
 	.zero  96


; this is the locals stack

.align  8
lsp:	.quad 	0
 		.zero  96


; The ALLOTMENT for random data


.align 	8

 				.zero  96
allot_last:		.quad	0
allot_ptr:		.quad	0	
allot_space:	.quad 	0			
allot_limit:	.quad 	0 
 				.zero  96
				 

.data

;
; this is the data stack

.align 16
	.zero	4096
prot1:
	.zero	4096


.align  8

spu:	
	.quad base

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

sp1:  
	.quad base+128

base:
	.zero 2048*8

sovfl:

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

spo:	.quad sovfl
sp0:	.zero 8*8
dsp:	.quad sp1

ssize:	.zero 32
.rept	1024
		.quad  0
		.endr

sbase:
		.rept	1024
		.quad  0
		.endr

.rept	1024
		.quad  0
		.endr


.align 16
	.zero	4096
prot2:
	.zero	4096


; this is the return stack
; used for loop constructs and local variables.

.data

.align  8
rps:	.zero 8*8	
rpu:	.zero 8
rp1:	.zero 1024*8  
rpo:	.zero 8
rp0:	.zero 8*8
rsp:	.quad rp1



.align 16
	 .rept  512
	 .quad -123456
	 .endr
 
prot3:
	 .rept 512
	 .quad -123456
	 .endr


.data
; global, single letter, integer variables
.align 16


     .data

random_seed:    
	.quad 0;            	 


dev_random:
  .asciz "/dev/urandom"

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

	.rept  16384	; <-- increase if literal pool full error arises.
	.quad -1
	.endr
	.quad  -2 ; end of literal pool. 
	.quad  -2 



; STRINGS ASCII
; string lits ASCII counted strings


; any string activity below here is an insane bug, probably
.align 16
below_string_space:



.align 16
string_buffer:
.asciz "Strings"
.zero 4096
 

.align 16
slice_string:
	.zero 4096

.align 16
rmargin: 	.quad 80



; used for line input
.align 16
zpad:	.ascii "ZPAD STARTS HERE"
	.zero 4096



.align 16
append_buffer:
	.asciz "Append Buffer"
	.zero 4096
.align 16
append_ptr:
	.quad 0		; 0 = not appending


; most likely an error to read a string above here
above_string_space:



; the word being processed
.align 8
zword: .zero 64


.align 8

startup_file:	
	.asciz "forth.forth"


mode_read:	
	.asciz "r"


.align 	8
input_file:			
				.quad	0
				.quad	0

.align 	8
accepted:			
				.quad	0
				.quad	0
 

.align 	8

acceptptr: 		.quad string_buffer

acceptcap:		.quad  2048

.align 	8
acceptlen:			
				.quad	0
				.quad	0


.align 	8
bequiet:	
				.quad 	0


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
	

		; words that can take *inline* literals as arguments
		makeword "(EXIT)", dexitz, 0,  0					; 0 - never runs
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
		makeword "(?DOER)", 	stckqdoargsz, 	0,  0	; 26
		makeword "(27)", 		0, 	0,  0				; 27
		makeword "(28)", 		0, 	0,  0				; 28
		makeword "(29)", 		0, 	0,  0				; 29
		makeword "(@)", 		datz, 	0,  0			; 30
		makeword "(TO)", 		dtocz, 	0,  0			; 31

		; compiled array words
		makeword "(A1FILLARRAY)", 		dA1FILLAz, 	 0,  0 ; 32
		makeword "(W1FILLARRAY)", 		dW1FILLAz,   0,  0 ; 33
		makeword "(HW1FILLARRAY)", 		dHW1FILLAz,  0,  0 ; 34
		makeword "(C1FILLARRAY)", 		dC1FILLAz,  0,  0;  35
		makeword "(A2FILLARRAY)", 		0, 	0,  0			; 36
		makeword "(W2FILLARRAY)", 		0, 	0,  0			; 37
		makeword "(HW2FILLARRAY)", 		0, 	0,  0			; 38
		makeword "(C2FILLARRAY)", 		0, 	0,  0			; 39
		makeword "(ALFILLARRAY)", 		dALFILLAz, 	0,  0	; 40
		makeword "(WALFILLARRAY)", 		dWALFILLAz, 0,  0	; 41
		makeword "(STRING)", 			dSTRINGz, 0,  0		; 42
		makeword "(,)",	 			    dcomacz, 0,  0		; 43

		makeword "(WTO)", 				dwtocz, 	0,  0	; 44
		makeword "(CTO)", 				dctocz, 	0,  0	; 45
		makeword "(LTO)", 				dltocz, 	0,  0	; 46
		makeword "(TIMESDO)", 			dtimescz, 	0,  0	; 47
		makeword "(INCR)", 				dincrcz, 	0,  0	; 48
		makeword "(DECR)", 				ddecrcz, 	0,  0	; 49
		makeword "(ONRESET)", 			0,  	0,   0		; 50
		makeword "(FORTH)", 			0, 0, 0				; 51
		makeword "(.')", 				dslitSzdot, 0,  0	; 52

		; just regular words starting with (
		makeword "(", 			dlrbz, dlrbc, 	0		; ( comment


		makeemptywords 256

		makeword "#DSTACK", create_dstack, dcreat_invalid, 0	
		makeword "#RSTACK", create_rstack, dcreat_invalid, 0	


hashdict:	

		; end of inline compiled words, relax

		makeemptywords 256

		makeword "ADDS", creatadder, dcreat_invalid, 0	
		makeword "ALIAS", creatalias, dcreat_invalid, 0	
		makeword "ASORT", sortalias, dcreat_invalid, 0	
		makeword "ALIAS^", dvaraddz, 0, alias_table
		makeword "APPEND$", dvaraddz, 0,  append_buffer
		makeword "APPEND^", dvaluez, 0,  append_ptr
 
		makeword "ALIGN8", dalign8 , 0, 0 
		makeword "ALIGN16", dalign16 , 0, 0 
 
 		makeword  "ALLOT",  dallot,  0, 0 
		makeword "ALLOT?", dallotablez , 0, 0
		makeword "ARRAY", dcreatarray ,dcreat_invalid , 0 
		makeword "ADDR" , daddrz, daddrc, 0
		makeword "ACCEPT", dacceptz, 0,  0
		makeword "AGAIN" , dagainz, dagainc, 0
		makeword "ABS" , dabsz, dabsc, 0
		makeword "AND" , dandz, 0, 0
		makeword "a" , dlocaz, 0, 0
		makeword "a!" , dlocasz, 0, 0
		makeword "a++" , dlocasppz, 0, 0
		makeword "AT" , datxyz, 0, 0
		
	
adict:

		makeemptywords 256

		makeword "BEGIN" , dbeginz, dbeginc, 0
		makeword "BUFFER$", dvaraddz, 0,  string_buffer
		makeword "BREAK",  dbreakz, dbreakc, 0
		makeword "b" , dlocbz, 0, 0
		makeword "b!" , dlocbsz, 0, 0
		makeword "b++" , dlocbsppz, 0, 0
		
bdict:
		makeemptywords 256
		makeword "CHAR", 	dcharz, dcharc, 0
		makeword "CARRAY", dCcreatarray , dcreat_invalid, 0 
		makeword "CLRALIAS", clralias, 0, 0	
		makeword "CVALUES", dCcreatvalues , dcreat_invalid, 0 
		makeword "C@", 		catz, 0, 0
		makeword "C!", 		cstorz, 0, 0
		makeword "CONSTANT", dcreatevalz , dcreat_invalid, 0
		makeword "CREATE", 	dcreatz, dcreatc, 0
		makeword "CR", 		saycr, 0, 0
		makeword "c" , dloccz, 0, 0
		makeword "c!" , dloccsz, 0, 0
		makeword "c++" , dloccsppz, 0, 0
		makeword "CODE^" , dlocjz, 0, 0
		makeword "CPY" ,  dcopy, 0, 0
		makeword "CCPY" ,  d2copy, 0, 0
		makeword "CPYC" ,  dcopyc, 0, 0
		makeword "CCPYC" ,  dcopy2c, 0, 0
		makeword "CCCPYC" ,  dcopy3c, 0, 0
		
cdict:
		makeemptywords 256
 
		makeword "DO", dinvalintz , doerc, 0 
		makeword "DOWNDO", 0 , ddownerc, 0 
		makeword "DUP", ddupz , 0, 0 
		makeword "DDUP", d2dupz , 0, 0 
 		makeword "DROP", ddropz , 0, 0 
		makeword "DDROP", ddrop2z , 0, 0 
		makeword "DEPTH", ddepthz , 0, 0 
		makeword "d" , dlocdz, 0, 0
		makeword "d!" , dlocdsz, 0, 0
		makeword "d++" , dlocdsppz, 0, 0

		
ddict:

 		makeemptywords 256 
		makeword "EXEC", dcallz, dcallc, 0
		makeword "ELSE", 0 , delsec, 0 
		makeword "ENDIF", dendifz , dendifc, 0 
		makeword "EMIT", emitz , 0, 0 
		makeword "EXIT", dexitz, 	0,  0	
		makeword "e" , dlocez, 0, 0
		makeword "e!" , dlocesz, 0, 0	

	 
		
edict:


		makeemptywords 256
		makeword "f<>", fneqz, 0,  0 
		makeword "f=", feqz, 0,  0 
		makeword "f>=0", fgtzz, 0,  0 
		makeword "f<0", fltezz, 0,  0 
		makeword "f<=", fltez, 0,  0 
		makeword "f>=", fgtez, 0,  0 	 
		makeword "f<", fltz, 0,  0 
		makeword "f>", fgtz, 0,  0
		makeword "f.", fdotz, 0,  0
		makeword "f+", fplusz, 0,  0
		makeword "f-", fminusz, 0,  0
		makeword "f*", fmulz, 0,  0
		makeword "f/", fdivz, 0,  0
		makeword "fsqrt", fsqrt, 0,  0
		makeword "fneg", fnegz, 0,  0
		makeword "fabs", fabsz, 0,  0
		makeword "s>f", fstofz, 0,  0 
		makeword "f>s", ftosz, 0,  0 
		makeword "FFIB", dtstfib, 0,  0
		makeword "FASTER", duntracable, 0, 0
		makeword "FLAT", dflat, 0, 0
		makeword "FLAT.TRACE", dflattrace, 0, 0
		makeword "FALSE", dfalsez, 0,  0
		makeword "FORGET", clean_last_word , 0, 0 
		makeword "FINAL^", dvaraddz, 0,  startdict
		makeword "FINDLIT", dfindlitz, dfindlitc,  0
		makeword "FINDALIAS", findalias2, 0,  0
		makeword "FILLVALUES", dfillarrayz, dfillarrayc, 0
		makeword "FILLARRAY", dfillarrayz, dfillarrayc, 0
		makeword "FILL", dfillz, 0, 0
		makeword "FLUSH", dflushz, 0, 0
		
		makeword "f" , dlocfz, 0, 0
		makeword "f!" , dlocfsz, 0, 0	
		makeword "FCOL", datcolr, 0, 0
	

fdict:	
		makeemptywords 256
		makeword "g" , dlocgz, 0, 0
		makeword "g!" , dlocgsz, 0, 0	
 
gdict:
		makeemptywords 256
		makeword "HWARRAY", dHWcreatarray , dcreat_invalid, 0 
		makeword "HWVALUES", dHWcreatvalues , dcreat_invalid, 0 
		makeword "HW!", dhstorez, dhstorec,  0
		makeword "HW@", dhatz, dhatc, 0
		makeword "HW@IP", dhatipz, 0, 0
		makeword "h" , dlochz, 0, 0
		makeword "h!" , dlochsz, 0, 0	
		makeword "HEX.", dhexprintz, 0, 0
		makeword "HEAPSIZE", heapsize , 0, 0
		makeword "HEAP^", dvaluez , 0, heap_ptr
 		makeword "HLAST^", dvaluez , 0, lasthere_ptr
 		makeword "HERE^", dvaluez , 0, here_ptr
	 
hdict:
	
		makeemptywords 256
 
		makeword "IP@", dipatz, dipatz,  0
		makeword "IP!", dipstrz, 0,  0
		makeword "IP2+", dip2plusz, 0,  0
		makeword "IP+", dipplusz, 0,  0
		makeword "IN", dvaluez, 0,  input_file
		makeword "I", diloopz, diloopc,  0
		makeword "IF", difz, difc,  0
		makeword "INVERT", dinvertz, 0,  0
		makeword "IVARS", dvaraddz, 0, ivars
 
idict:
		makeemptywords 256
 
		makeword "J", djloopz, djloopc,  0

jdict:
		makeemptywords 256
	 	makeword "KEY?", dkeyqz, 0,  0
	 	makeword "KEY", dkeyz, 0,  0
		makeword "K", dkloopz, dkloopc,  0
	
kdict:
		makeemptywords 256
		
	
 
		makeword "LSP^", dvaluez , 0, heap_ptr
	
		makeword "LOCALS", dlocalsvalz, 0,  0, 0, 7
		makeword "LEAVE",  dinvalintz, dleavec, 0 
		makeword "LOOP", dinvalintz , dloopc, 0 
		makeword "LIMIT", dlimited , 0, 0 
		makeword "LISTSTRINGS", dliststrings , 0, 0 
		makeword "LAST", get_last_word, 0,  0
		makeword "LITERALS", darrayvalz, 0,  quadlits, 0, 1024


ldict:
		makeemptywords 256
		makeword "MOD", dmodz, dmodc, 0	
		makeword "MS", dsleepz , 0, 0 
	
 
mdict:
		makeemptywords 256

	
		makeword "NTH", dnthz, 0, 0	
		makeword "NIP", dnipz, 0, 0	
		makeword "NOECHO", noecho, 0, 0	
	 

ndict:	
		makeemptywords 256

		makeword "OR", dorz, 0, 0
		makeword "OVER", doverz, 0, 0
		makeword "OVERSWAP", doverswap, 0, 0
		
 
	
odict:
		makeemptywords 256
		makeword "PCHK", dparamchkz, 0, 0
		makeword "PARAMS", dparamsz, 0, 0
		makeword "PAGE", dpagez, 0, 0
		makeword "PICK", dpickz, dpickc, 0

pdict:


		makeemptywords 256
 

qdict:
		makeemptywords 256
 	
	 	makeword "RMARGIN", dvaluez, 0,  rmargin	
		makeword "REPEAT", drepeatz , drepeatc, 0 
	 	makeword "RDEPTH", ddepthrz , 0, 0 
		makeword "ROT", drotz , drotc, 0 
		makeword "R>", dfromrz , dfromrc, 0 
		makeword "R@", dratz , 0, 0 
		makeword "RP@", fetchrpz , 0, 0 
		makeword "RESET", dresetz , 0, 0 
		makeword "RETERM", reterm, 0, 0	
	 	makeword "RND", drandomz, 0, 0	

rdict:

		makeemptywords 256
 
		makeword "SUBS", creatsubber, dcreat_invalid, 0	
		makeword "STACK", dcreatstack , dcreat_invalid, 0 
		makeword "STEPOUT", stepoutz , 0, 0 
	 	makeword "STEP", step_in_runz , 0, 0 
		makevarword "STEPPING", step_limit
		makevarword "STEPS", step_skip

		makeword "STRING", creatstring , dcreat_invalid, 0 
		makeword "STRINGS", dcreatstringvalues , dcreat_invalid, 0 
 
		makeword "SWAP", dswapz , 0, 0 
		makeword "SHIFTSL", dcreatnmulz, dcreat_invalid,0
		makeword "SHIFTSR", dcreatndivz, dcreat_invalid,0
		makeword "SPACES", spacesz , spacesc, 0 
		makeword "SPACE", emitchz , emitchc, 32
	 	makeword "SP@", fetchspz , 0, 0 
		makeword "SEE", dseez , 0, 0 
		makeword "SELF^" , dlociz, 0, 0
		makeword "SELECTIT" , dselectit, 0, 0

 

sdict:
		makeemptywords 256

 	 
		makeword "TO", dtoz, dtoc, 0
		makeword "TIMEIT", dtimeitz, dtimeitc, 0
		makeword "TRACE", dtracable, 0, 0
		makeword "TRUE", dtruez, 0,  0
		makeword "TRACING?", dtraqz, 0, 0
		makeword "TICKS", dtickerz, 0, 0
		makeword "TIMESDO", dtimesdoz, dtimesdoc, 0
		makeword "TPMS", dconstz, dconstz, 24000
		makeword "TPS",  dconstz, dconstz, 24000000
		makeword "TRON", dtronz, 0, 0
		makeword "TROFF", dtroffz, 0, 0
		makeword "THEN", dendifz , dendifc, 0 
	 	makeword "TUCK", dtuckz , 0, 0 
 

tdict:

		makeemptywords 256
		makeword "UNTIL", duntilz, duntilc, 0	
		makeword "UNALIAS", unalias, dcreat_invalid, 0	
 
	
udict:

		makeemptywords 256

		makeword "VALUE", dcreatevalz , dcreat_invalid, 0
		makeword "VALUES", dcreatvalues , dcreat_invalid, 0 
		makeword "VARIABLE", dcreatvz , dcreat_invalid, 0
	

	 
vdict:

		makeemptywords 256
		makeword "WARRAY", dWcreatarray , dcreat_invalid, 0 
		makeword "WVALUES", dWcreatvalues , dcreat_invalid, 0 
		makeword "WLOCALS", dlocalsWvalz, 0,  0, 0, 15
		makeword "WHILE", 0 , dwhilec, 0 
		makeword "W!", dwstorz , 0, 0 
		makeword "W@", dwatz , 0, 0 

		
wdict:

		makeemptywords 256
		
	 
xdict:
		makeemptywords 256
		
  
	
ydict:
		makeemptywords 256

	
zdict:

		makeemptywords 256

		makeword "${", dstrappendbegin , 0, 0 
		makeword "$.", ztypez, 0, 0	
 		makeword "$}", dstrappendend , 0, 0 
 		makeword "$=", dstrequalz, 0,  0
		makeword "$==", _dstrequalz, 0,  0
		makeword "$compare", dstrcmp, 0,  0
		makeword "$len", dstrlen, 0,  0
		makeword "$pos", dstrpos, 0,  0
		makeword "$find", dstrfind, 0,  0
		makeword "$contains", dstrcontains, 0,  0
		makeword "$slice", dstrslice, 0,  0
		makeword "$''", 	stackit, 	stackit, 	0
		makeword "$intern", 	intern, 	intern, 	0
	 
dollardict:
	 	
		makeemptywords 256
		
		makeword "}$", dstrappendend , 0, 0 
		makeword "{$", dstrappendbegin , 0, 0 

		makeword "*/", dstarslshz, 0,  10
		makeword "*/MOD", dstarslshzmod, 0,  10
		 
		makeword "10*", tentimez , 0, 0
		makeword "10/", tendivz , 0, 0

		makeword "0=", dequalzz, 0 , 0
		makeword "0<", dltzz, 0 , 0
		makeword "0>", dgtzz, 0 , 0
		makeword "1>", dgt1z, 0 , 0
		makeword "/MOD", dsmodz , dsmodc, 0

		makeword "//", dlcmntz , dlcmntc, 0

		makeword ".VERSION", announce , 0, 0

		makeword "?DUP", dqdupz, dqdupc, 0
		makeword ">R", dtorz , dtorc, 0 
		makeword "+LOOP", dinvalintz , dploopc, 0
		makeword "-LOOP", dinvalintz , dmloopc, 0
		makeword ".R", ddotrz, 0 , 0
		makeword ".S", ddotsz, 0 , 0
		makeword ".'", dstrdotz, dstrdotc , 0
		makeword "<>", dnoteqz, 0 , 0
		makeword "+!", plustorz, 0 , 0
		makeword "``", 0, dtickc , 0
		makeword "2DUP", ddup2z , 0, 0 
		makeword "2DROP", ddrop2z , 0, 0 
		makeword "?DO", dinvalintz , dqoerc, 0 
		;makeword "2VARIABLE", dcreat2vz , 0, 0


zbytewords:
		makeemptywords 33
		makebword 33, 	dstorez, 	dstorec, 	0
		makebword 34, 	dquotz, 	dquotc, 		0
		makebword 35, 	dhashz, 	dhashc, 		0
		makebword 36, 	ddollarz, 	0, 	0
		makebword 37, 	dmodz, 		dmodc, 		0
		makebword 38, 	dandz, 		0, 		0
		makebword 39, 	dstrstksz, 	dstrstksc, 		0
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
		makebword 96, 	dtickz, 0, 		0
	

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


.align 8
heap_ptr:	.quad 0




