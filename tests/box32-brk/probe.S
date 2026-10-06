.text
.global _start
_start:
 # Query twice; Linux raw brk returns an address, never -errno.
 mov $45,%eax
 xor %ebx,%ebx
 int $0x80
 cmp $-4095,%eax
 jae failed
 test %eax,%eax
 jz failed
 mov %eax,%esi
 mov $45,%eax
 int $0x80
 cmp %esi,%eax
 jne failed
 # Grow a page plus one byte; verify writable memory at both ends.
 lea 4097(%esi),%ebx
 mov $45,%eax
 int $0x80
 cmp %ebx,%eax
 jne failed
 movb $0x45,(%esi)
 movb $0x67,-1(%ebx)
 # Shrink to one byte, then regrow. Entire released page must be zero-filled.
 lea 1(%esi),%ebx
 mov $45,%eax
 int $0x80
 cmp %ebx,%eax
 jne failed
 cmpb $0x45,(%esi)
 jne failed
 lea 4097(%esi),%ebx
 mov $45,%eax
 int $0x80
 cmp %ebx,%eax
 jne failed
 cmpb $0,-1(%ebx)
 jne failed
 # Out-of-range and below-initial requests must return the unchanged break.
 mov %eax,%edi
 mov $0xffffffff,%ebx
 mov $45,%eax
 int $0x80
 cmp %edi,%eax
 jne failed
 mov $1,%ebx
 mov $45,%eax
 int $0x80
 cmp %edi,%eax
 jne failed
 # Release all newly mapped pages and ensure the query reports the new break.
 mov %esi,%ebx
 mov $45,%eax
 int $0x80
 cmp %esi,%eax
 jne failed
 xor %ebx,%ebx
 mov $45,%eax
 int $0x80
 cmp %esi,%eax
 jne failed
 # Place a mapping two pages above the aligned break. Growth must fail
 # without replacing it; its marker must survive.
 lea 4095(%esi),%ebx
 and $-4096,%ebx
 add $8192,%ebx
 mov %ebx,%ebp
 mov $4096,%ecx
 mov $3,%edx
 mov $0x100022,%esi
 mov $-1,%edi
 push %ebp
 xor %ebp,%ebp
 mov $192,%eax
 int $0x80
 pop %ebp
 cmp %ebp,%eax
 jne failed
 movb $0x72,(%ebp)
 lea 4096(%ebp),%ebx
 mov $45,%eax
 int $0x80
 cmp %ebx,%eax
 je failed
 cmpb $0x72,(%ebp)
 jne failed
 # Success message.
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
message: .ascii "PASS brk query/grow/shrink/regrow/failure/collision\n"
message_end:
.section .note.GNU-stack,"",@progbits
