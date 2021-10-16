;; X18 reserved
;; X29 frame ptr
;; X30 LR




.global main 

.align 4			 




.data

announce:       .ascii  "ARM64Shennigans\n"
sp1:            .zero 256*16
sp0:            .zero 8*16



ptfstr: .asciz	"R%c = %16d, 0x%08x\n"