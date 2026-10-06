.text
.global _start
.type _start,@function
_start:
 call foo@PLT
 cmp $EXPECTED,%eax
 jne failed
 xor %ebx,%ebx
 jmp done
failed:
 mov $1,%ebx
 done:
 mov $1,%eax
 int $0x80
.size _start,.-_start
.section .note.GNU-stack,"",@progbits
