.text
.global _start
_start:
 # Model a descending 2MiB LinuxThreads stack below the initial stack.
 mov %esp,%ebx
 and $0xffe00000,%ebx
 sub $0x800000,%ebx
 mov $192,%eax
 mov $0x200000,%ecx
 mov $7,%edx
 mov $0x32,%esi
 mov $-1,%edi
 xor %ebp,%ebp
 int $0x80
 cmp %ebx,%eax
 jne failed
 # First lazy binding after the mapping must still have a live resolver.
 call answer@PLT
 cmp $42,%eax
 jne failed
 mov $1,%eax
 xor %ebx,%ebx
 int $0x80
failed:
 mov $1,%eax
 mov $1,%ebx
 int $0x80
.section .note.GNU-stack,"",@progbits
