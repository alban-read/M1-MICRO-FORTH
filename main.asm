;; X18 reserved
;; X29 frame ptr
;; X30 LR

.global _start		 

.align 8			 


.text

_start: mov	X0,     #1	                // 1 = StdOut
        ADRP	X1,     announce@PAGE	 
	add	X1,     X1, announce@PAGEOFF 
        mov	X2,     #8	                // len 
        mov	X16,    #4	                // write
        svc	#0x80		                // Call kernel




_end:   mov     X0,     #0          // return 0
        mov     X16,    #1          // 1 terminates this program
        svc     #0x80		    // Call kernel 




.data

announce:       .ascii  "Forth64\n"
sp1:            .zero 256*16
sp0:            .zero 8*16



