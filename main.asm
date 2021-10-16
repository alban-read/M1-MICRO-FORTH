;; X18 reserved
;; X29 frame ptr
;; X30 LR



.global main 

.align 4			 

main:	STP	X19, X20, [SP, #-16]!
	STR	LR, [SP, #-16]!


        ADRP	X0, ver@PAGE	 
	ADD	X0, X0, ver@PAGEOFF
        LDR     X1, [X0]

	ADRP	X0, ps1@PAGE	 
	ADD	X0, X0, ps1@PAGEOFF

        STP	X1, X0, [SP, #-16]!
	BL	_printf		 
	ADD	SP, SP, #16



finish: MOV	X0, #0
	LDR	LR, [SP], #16
	LDP	X19, X20, [SP], #16
	RET


.data
ver:    .double 0.10 
ps1:    .ascii  "ARM64Shennigans %2.2f\n"
sp1:    .zero 256*16
sp0:    .zero 8*16



 