

; TO e.g. 10 TO MyVALUE

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

	; found word, update it
 	restore_registers
	


	; check variable 

	LDR		X2,	 [X28, #8] 


	ADRP	X1, dvaraddz@PAGE	; high level word.	
	ADD		X1, X1, dvaraddz@PAGEOFF
	CMP 	X2, X1
	B.eq	160f 
	
	ADRP	X1, dvaluez@PAGE	; high level word.	
	ADD		X1, X1, dvaluez@PAGEOFF
	CMP 	X2, X1
	B.eq	150f 
	
		
	ADRP	X1, darrayaddz@PAGE	; high level word.	
	ADD		X1, X1, darrayaddz@PAGEOFF
	CMP 	X2, X1
	B.eq	150f 
	
	
	B  		170f  ; not a word we can update 


150:

	; get value to change
	LDR		X1, [X16, #-8] 
	SUB		X16, X16, #8
	STR		X1, [X28, #32]



	RET

160:
	; get value to change
	LDR		X1, [X16, #-8] 
	SUB		X16, X16, #8
	LDR		X0, [X28] ; var or val address
	STR		X1, [X0]  ; store 
	RET

170:

 	LDP		X0, X2, [X16, #-16]	; X0 value, X2 = index
	SUB		X16, X16, #16
	LDR		X1, [X28, #32]   ; X1 array size 
	CMP		X2, X1
	B.gt	darrayaddz_index_error
	LDR		X1, [X28]  ; data
	LSL		X2, X2, #3 ; full word 8 bytes
	ADD		X1, X0, X2 ; data + index 
	STR		X0, [X1]
	RET


170:	; next word in dictionary
	SUB		X28, X28, #64
	B		120b

190:	; error out 
	MOV		X0, #0
 
 

	RET

