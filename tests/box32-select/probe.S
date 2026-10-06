.text
.global _start
_start:
#ifndef SKIP_PPID
 mov $64,%eax
 int $0x80
 test %eax,%eax
 jle failed
#endif
 mov $42,%eax
 mov $pipes,%ebx
 int $0x80
 test %eax,%eax
 jnz failed
 mov pipes,%ecx
 mov $1,%eax
 shl %cl,%eax
 mov %eax,readset
 # Empty pipe: a zero timeval must timeout and clear the 4-byte bitmap.
 mov $142,%eax
 mov pipes,%ebx
 inc %ebx
 mov $readset,%ecx
 xor %edx,%edx
 xor %esi,%esi
 mov $tv,%edi
 int $0x80
 test %eax,%eax
 jnz failed
 cmpl $0,readset
 jne failed
 cmpl $0x12345678,readset+4
 jne failed
 # Write one byte to the pipe; select must report exactly that read bit.
 mov $4,%eax
 mov pipes+4,%ebx
 mov $byte,%ecx
 mov $1,%edx
 int $0x80
 cmp $1,%eax
 jne failed
 mov pipes,%ecx
 mov $1,%eax
 shl %cl,%eax
 mov %eax,readset
 mov %eax,%ebp
 mov $142,%eax
 mov pipes,%ebx
 inc %ebx
 mov $readset,%ecx
 xor %edx,%edx
 xor %esi,%esi
 mov $tv,%edi
 int $0x80
 cmp $1,%eax
 jne failed
 cmp %ebp,readset
 jne failed
 cmpl $0x12345678,readset+4
 jne failed
 cmpl $0x87654321,tv+8
 jne failed
 # A real timed wait must consume the timeout and return no ready fds.
 movl $50000,tv+4
 mov $142,%eax
 xor %ebx,%ebx
 xor %ecx,%ecx
 xor %edx,%edx
 xor %esi,%esi
 mov $tv,%edi
 int $0x80
 test %eax,%eax
 jnz failed
 cmpl $0,tv
 jne failed
 cmpl $0,tv+4
 jne failed
 # Bad pointers must return EFAULT, invalid nfds EINVAL.
 mov $142,%eax
 mov $1,%ebx
 mov $1,%ecx
 xor %edx,%edx
 xor %esi,%esi
 mov $tv,%edi
 int $0x80
 cmp $-14,%eax
 jne failed
 mov $142,%eax
 mov $-1,%ebx
 xor %ecx,%ecx
 int $0x80
 cmp $-22,%eax
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
message: .ascii "PASS getppid/pipe/_newselect timeout/readiness/guards/errors\n"
message_end:
byte: .ascii "x"
.data
pipes: .long 0,0
readset: .long 0,0x12345678
tv: .long 0,0,0x87654321
.section .note.GNU-stack,"",@progbits
