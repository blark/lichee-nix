.text
.global _start
_start:
 mov %esp,saved_sp
 mov $32,%edi
install:
 mov $174,%eax
 mov %edi,%ebx
 mov $action,%ecx
 xor %edx,%edx
 mov $8,%esi
 int $0x80
 test %eax,%eax
 jnz failed
 # Kernel oldact is exactly20 bytes, not libc's128-byte mask layout.
 mov $174,%eax
 mov %edi,%ebx
 xor %ecx,%ecx
 mov $queried_action,%edx
 mov $8,%esi
 int $0x80
 test %eax,%eax
 jnz failed
 cmpl $handler,queried_action
 jne failed
 cmpl $0x04000000,queried_action+4
 jne failed
 cmpl $restorer,queried_action+8
 jne failed
 cmpl $0x12345678,queried_action+20
 jne failed
 inc %edi
 cmp $35,%edi
 jne install
 mov $174,%eax
 mov $32,%ebx
 xor %ecx,%ecx
 xor %edx,%edx
 mov $4,%esi
 int $0x80
 cmp $-22,%eax
 jne failed
 mov $174,%eax
 mov $1,%ecx
 mov $8,%esi
 int $0x80
 cmp $-14,%eax
 jne failed
 mov $179,%eax
 mov $1,%ebx
 mov $8,%ecx
 int $0x80
 cmp $-14,%eax
 jne failed
 # sigfillset produces all64 bits. A full mask must not cause EINVAL.
 mov $175,%eax
 mov $2,%ebx
 mov $full_mask,%ecx
 xor %edx,%edx
 mov $8,%esi
 int $0x80
 test %eax,%eax
 jnz failed
 # An all-bits sa_mask and an all-bits saved-frame edit must also work.
 mov $174,%eax
 mov $35,%ebx
 mov $full_action,%ecx
 xor %edx,%edx
 mov $8,%esi
 int $0x80
 test %eax,%eax
 jnz failed
 mov $20,%eax
 int $0x80
 mov %eax,%ebx
 mov $37,%eax
 mov $35,%ecx
 int $0x80
 test %eax,%eax
 jnz failed
 mov $179,%eax
 mov $empty,%ebx
 mov $8,%ecx
 int $0x80
 cmp $-4,%eax
 jne failed
 cmpl $1,full_seen
 jne failed
 mov $175,%eax
 mov $2,%ebx
 xor %ecx,%ecx
 mov $queried,%edx
 mov $8,%esi
 int $0x80
 test %eax,%eax
 jnz failed
 cmpl $0xfffbfeff,queried
 jne failed
 mov queried+4,%eax
 and $0x3fffffff,%eax
 cmp $0x3fffffff,%eax
 jne failed
 mov $175,%eax
 mov $2,%ebx
 mov $blocked,%ecx
 xor %edx,%edx
 mov $8,%esi
 int $0x80
 test %eax,%eax
 jnz failed
 mov $20,%eax
 int $0x80
 mov %eax,parent_pid
 movl $32,next_signal
cycle:
 mov $37,%eax
 mov parent_pid,%ebx
 mov next_signal,%ecx
 int $0x80
 test %eax,%eax
 jnz failed
 # Every RT signal remains pending until the atomic suspend unblocks it.
 fninit
 fldt extended_value
 fld1
 pcmpeqd %xmm0,%xmm0
 mov $179,%eax
 mov $empty,%ebx
 mov $8,%ecx
 mov $0x12345678,%edx
 mov $0x23456789,%esi
 mov $0x3456789a,%edi
 mov $0x456789ab,%ebp
 stc
 int $0x80
 jnc failed
 cmp $-4,%eax
 jne failed
 cmp $0x12345678,%edx
 jne failed
 cmp $0x23456789,%esi
 jne failed
 cmp $0x3456789a,%edi
 jne failed
 cmp $0x456789ab,%ebp
 jne failed
 pmovmskb %xmm0,%eax
 cmp $65535,%eax
 jne failed
 fstpl fp_result
 cmpl $0,fp_result
 jne failed
 cmpl $0x3ff00000,fp_result+4
 jne failed
 fstpt extended_result
 cmpl $1,extended_result
 jne failed
 cmpl $0x80000000,extended_result+4
 jne failed
 cmpw $0x3fff,extended_result+8
 jne failed
 # sigreturn must restore the blocked mask, including its high word.
 mov $175,%eax
 mov $2,%ebx
 xor %ecx,%ecx
 mov $queried,%edx
 mov $8,%esi
 int $0x80
 test %eax,%eax
 jnz failed
 cmpl $0x80000000,queried
 jne failed
 cmpl $3,queried+4
 jne failed
 incl next_signal
 cmpl $35,next_signal
 jne cycle
 cmpl $1,count32
 jne failed
 cmpl $1,count33
 jne failed
 cmpl $1,count34
 jne failed
 cmpl $0,frame_error
 jne failed
 # Nested33 during32, plus deliberate edits of the outer sigcontext.
 movl $1,edit_context
 mov $37,%eax
 mov parent_pid,%ebx
 mov $32,%ecx
 int $0x80
 test %eax,%eax
 jnz failed
 mov $179,%eax
 mov $empty,%ebx
 mov $8,%ecx
 int $0x80
 cmp $0x13579bdf,%eax
 jne failed
 cmp $0x2468ace0,%ebp
 jne failed
 cmpl $2,count32
 jne failed
 cmpl $2,count33
 jne failed
 cmpl $1,nested_seen
 jne failed
 cmpl $0,handler_depth
 jne failed
 cmpl $0,frame_error
 jne failed
 mov $175,%eax
 mov $2,%ebx
 xor %ecx,%ecx
 mov $queried,%edx
 mov $8,%esi
 int $0x80
 test %eax,%eax
 jnz failed
 cmpl $0x80000000,queried
 jne failed
 cmpl $3,queried+4
 jne failed
 # Separate-PID delivery with the exact pre-NPTL shared-process clone shape.
 mov $120,%eax
 mov $0x0f00,%ebx
 mov $child_stack_end,%ecx
 xor %edx,%edx
 xor %esi,%esi
 xor %edi,%edi
 int $0x80
 test %eax,%eax
 js failed
 jz child
 mov %eax,child_pid
 mov $179,%eax
 mov $empty,%ebx
 mov $8,%ecx
 int $0x80
 cmp $-4,%eax
 jne failed
 mov $7,%eax
 mov child_pid,%ebx
 mov $child_status,%ecx
 mov $0x80000000,%edx  # __WCLONE: clone has no exit signal.
 int $0x80
 cmp child_pid,%eax
 jne failed
 cmpl $0,child_status
 jne failed
 mov parent_pid,%eax
 cmp child_parent,%eax
 jne failed
 cmpl $3,count32
 jne failed
 cmpl $2,count33
 jne failed
 cmpl $1,count34
 jne failed
 cmpl $0,handler_depth
 jne failed
 cmpl $0,frame_error
 jne failed
 mov $4,%eax
 mov $1,%ebx
 mov $message,%ecx
 mov $message_end-message,%edx
 int $0x80
 xor %ebx,%ebx
 jmp exit
child:
 mov $64,%eax
 int $0x80
 mov %eax,child_parent
 mov $37,%eax
 mov parent_pid,%ebx
 mov $32,%ecx
 int $0x80
 test %eax,%eax
 jnz failed
 xor %ebx,%ebx
 jmp exit
failed:
 mov $1,%ebx
exit:
 mov $1,%eax
 int $0x80
 ud2

# On entry ESP points at pretcode; Linux sc begins eight bytes later.
# sc.sp=36, sc.ax=52, sc.bp=32, sc.fpstate=84, sc.oldmask=88;
# the 624-byte unused FP area ends at720, where the sole extramask word lies.
handler:
 mov 4(%esp),%eax
 cmp $32,%eax
 jl bad_frame
 cmp $34,%eax
 jg bad_frame
 incl handler_depth
 incl count32-128(,%eax,4)
 cmpl $0,84(%esp)
 je bad_frame
 # Nested delivery saves the live handler stack/mask instead of main's.
 cmpl $1,handler_depth
 jne nested_frame
 mov saved_sp,%edx
 cmp %edx,36(%esp)
 jne bad_frame
 cmpl $0x80000000,88(%esp)
 jne bad_frame
 cmpl $3,720(%esp)
 jne bad_frame
 jmp frame_checked
nested_frame:
 cmpl $2,handler_depth
 jne bad_frame
 cmp $33,%eax
 jne bad_frame
 mov nested_sp,%edx
 cmp %edx,36(%esp)
 jne bad_frame
 cmpl $0x80000000,88(%esp)
 jne bad_frame
 cmpl $0,720(%esp)
 jne bad_frame
 movl $1,nested_seen
frame_checked:
 cmpl $1,edit_context
 jne handler_done
 cmp $32,%eax
 jne handler_done
 movl $0,edit_context
 movl $0x13579bdf,52(%esp)
 movl $0x2468ace0,32(%esp)
 mov %esp,nested_sp
 fninit
 fld1
 pcmpeqd %xmm0,%xmm0
 mov $37,%eax
 mov parent_pid,%ebx
 mov $33,%ecx
 mov $0x12345678,%edx
 mov $0x23456789,%esi
 mov $0x3456789a,%edi
 mov $0x456789ab,%ebp
 stc
 int $0x80
 jnc bad_frame
 test %eax,%eax
 jnz bad_frame
 cmp $0x12345678,%edx
 jne bad_frame
 cmp $0x23456789,%esi
 jne bad_frame
 cmp $0x3456789a,%edi
 jne bad_frame
 cmp $0x456789ab,%ebp
 jne bad_frame
 pmovmskb %xmm0,%eax
 cmp $65535,%eax
 jne bad_frame
 fstpl nested_fp
 cmpl $0,nested_fp
 jne bad_frame
 cmpl $0x3ff00000,nested_fp+4
 jne bad_frame
handler_done:
 # Clobber FP, SSE, flags and caller registers; sigreturn restores them.
 fninit
 pxor %xmm0,%xmm0
 xor %edx,%edx
 xor %esi,%esi
 xor %edi,%edi
 xor %ebp,%ebp
 decl handler_depth
 clc
 ret
bad_frame:
 movl $1,frame_error
 jmp handler_done
full_handler:
 movl $1,full_seen
 movl $-1,88(%esp)
 movl $-1,720(%esp)
 ret
restorer:
#ifndef OMIT_RESTORER_POP
 pop %eax
#endif
 mov $119,%eax
 int $0x80
 ud2
.section .rodata
message: .ascii "PASS RT32-34 suspend/masks/frames/nesting/registers/FP/separate-PID clone\n"
message_end:
.data
.align 4
#ifdef BLOCK_NESTED
action: .long handler,0x04000000,restorer,0,1
#else
action: .long handler,0x04000000,restorer,0,0
#endif
blocked: .long 0x80000000,3
full_mask: .long -1,-1
full_action: .long full_handler,0x04000000,restorer,-1,-1
full_seen: .long 0
empty: .long 0,0
queried: .long 0,0
count32: .long 0
count33: .long 0
count34: .long 0
next_signal: .long 0
saved_sp: .long 0
frame_error: .long 0
edit_context: .long 0
handler_depth: .long 0
nested_seen: .long 0
nested_sp: .long 0
nested_fp: .long 0,0
parent_pid: .long 0
child_pid: .long 0
child_parent: .long 0
child_status: .long 0
fp_result: .long 0,0
.bss
.align 16
child_stack: .skip 65536
child_stack_end:
.section .note.GNU-stack,"",@progbits

.section .rodata
extended_value: .quad 0x8000000000000001
 .word 0x3fff
.bss
extended_result: .skip 10

.data
queried_action: .long 0,0,0,0,0,0x12345678
