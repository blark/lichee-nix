.text
.global _start
_start:
 mov $20,%eax
 int $0x80
 test %eax,%eax
 jle failed
 mov $122,%eax
 mov $uts,%ebx
 int $0x80
 test %eax,%eax
 jnz failed
 cmpl $0x756e694c,uts
 jne failed
 mov $122,%eax
 xor %ebx,%ebx
 int $0x80
 cmp $-14,%eax
 jne failed
 mov $13,%eax
 mov $seconds,%ebx
 int $0x80
 test %eax,%eax
 jle failed
 cmp seconds,%eax
 jne failed
 cmpl $0x12345678,seconds+4
 jne failed
 mov $191,%eax
 mov $3,%ebx
 mov $limits,%ecx
 int $0x80
 test %eax,%eax
 jnz failed
 cmpl $0x12345678,limits+8
 jne failed
 mov $75,%eax
 mov $3,%ebx
 mov $limits,%ecx
 int $0x80
 test %eax,%eax
 jnz failed
 movl $0x87654321,limits
 mov $13,%eax
 mov $1,%ebx
 int $0x80
 cmp $-14,%eax
 jne failed
 mov $191,%eax
 mov $3,%ebx
 mov $1,%ecx
 int $0x80
 cmp $-14,%eax
 jne failed
 mov $13,%eax
 mov $unaligned+1,%ebx
 int $0x80
 cmp unaligned+1,%eax
 jne failed
 cmpb $0x21,unaligned
 jne failed
 cmpb $0x43,unaligned+5
 jne failed
 mov $191,%eax
 mov $-1,%ebx
 mov $limits,%ecx
 int $0x80
 cmp $-22,%eax
 jne failed
 cmpl $0x87654321,limits
 jne failed
 mov $4,%eax
 mov $1,%ebx
 mov $message,%ecx
 mov $message_end-message,%edx
 int $0x80
 xor %ebx,%ebx
 jmp exit
failed:
 mov $1,%ebx
exit:
 mov $1,%eax
 int $0x80
.section .rodata
message: .ascii "PASS getpid/uname/time/ugetrlimit/setrlimit\n"
message_end:
.data
unaligned: .byte 0x21,0,0,0,0,0x43
.align 4
seconds: .long 0,0x12345678
limits: .long 0,0,0x12345678
.bss
.align 4
uts: .skip 390
.section .note.GNU-stack,"",@progbits
