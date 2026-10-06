This is a native-reference instrument for the unfinished raw-i386 signal path.
It installs signals32–34 through rt_sigaction174, with SA_SIGINFO clear and
SA_RESTORER set. Its restorer pops the signal number then invokes sigreturn119.
No libc, game libraries or proprietary files are used.

Build and check on an x86 Linux host that supports i386 execution:

```sh
CC=cc bash tests/box32-signals/build.sh /tmp/box32-signals
bash tests/box32-signals/check-native.sh /tmp/box32-signals
```

The positive native run exits0 and prints PASS. Two deliberately broken
controls must fail: masking nested33 gives exit1, omitting the restorer pop
gives SIGSEGV/exit139. The harness bounds every run and disables core dumps.
The native syscall trace was also checked: installation174, masks175,
suspend179, legacy return119 and clone120; no RT frame/return173 is required.

The positive probe checks:

- Pending signals remain blocked until rt_sigsuspend atomically unmasks them.
- Each initial signal runs exactly once and returns EINTR; the mask is restored.
- Carry, integer registers, x87 value and XMM state survive handler clobbering.
- Signal33 actually enters at depth2 inside32, using the outer handler's saved
  stack and a mask containing automatically blocked32. Outer integer/FP state
  is checked immediately after nested return, and final depth must be zero.
- Editing the outer frame's saved EAX/EBP changes the resumed registers.
- A child created with VM|FS|FILES|SIGHAND, without CLONE_THREAD or an exit
  signal, uses kill(parent_pid,32). Its parent PID and __WCLONE wait are checked.

Copy the positive executable to the board and invoke an explicit Box32 binary
under timeout. Current Box32 fails with ENOSYS at174, exit1. This is fail-before
evidence; no patched signal implementation or pass-after exists yet.
A future implementation must pass this entire instrument, not just174.
Preservation of the translator's native reserved32/33 needs a separate host-side
check: this fixture measures the guest-visible signal contract only.

Legacy frame offsets from handler-entry ESP, measured against the native kernel:

| Field | Offset |
| --- | ---: |
| Return/trampoline address | 0 |
| Signal argument | 4 |
| sigcontext_32 | 8 |
| Saved EBP | 32 |
| Saved ESP | 36 |
| Saved EAX | 52 |
| Saved flags | 72 |
| FP state pointer | 84 |
| Low signal-mask word | 88 |
| Sole extra/high mask word | 720 |

The unused legacy FP area occupies624 bytes; actual FP state is accessed via
the saved pointer. After ret and pop, syscall119 sees ESP=frame+8 and locates
the frame at ESP-8. Selecting a frame depends on SA_SIGINFO, not on whether
installation used rt_sigaction. See upstream Linux
[signal_32.c](https://github.com/torvalds/linux/blob/master/arch/x86/kernel/signal_32.c)
and [sigframe.h](https://github.com/torvalds/linux/blob/master/arch/x86/include/asm/sigframe.h).

The first three simple park/unpark cycles have one kill, one suspend and one
return each. The deliberate nested case adds a handler without another suspend;
matching counts are a program-specific native reference, not a universal rule
for every signalling workload.
