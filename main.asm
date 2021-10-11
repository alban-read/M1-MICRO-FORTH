;; X18 reserved
;; X29 frame ptr
;; X30 LR


.macro  printReg    reg
	push	    {r0-r4, lr} @ save regs
	mov	    r2, R\reg	@ for the %d
	mov	    r3, R\reg	@ for the %x
	mov	    r1, #\reg	
	add	    r1, #'0'	@ for %c
	ldr  	    r0, =ptfstr @ printf format str
	str	    r1, [sp, #-32]
	str	    r2, [sp, #8]
	str	    r3, [sp, #16]
	bl	    _printf	@ call printf
	add	    sp, sp, #32
	pop	    {r0-r4, lr} @ restore regs
.endm


.global main 

.align 4			 

main:	
	stp	X19, X20, [SP, #-16]!
	str	LR, [SP, #-16]!

        mov	X0,     #1	                 
        ADRP	X1,     announce@PAGE	 
	add	X1,     X1, announce@PAGEOFF 

        printReg 1

        mov	X2,     #8	                 
        mov	X16,    #4	                 
        svc	#0x80		             

        mov	X0, #0		// return code
	ldr	LR, [SP], #16
	ldp	X19, X20, [SP], #16
	ret


.data

announce:       .ascii  "Forth64\n"
sp1:            .zero 256*16
sp0:            .zero 8*16



ptfstr: .asciz	"R%c = %16d, 0x%08x\n"