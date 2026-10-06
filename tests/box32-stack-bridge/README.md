This game-free ELF32 instrument models a descending fixed LinuxThreads stack
below the initial stack, then calls a shared object's `answer()` through its
first lazy binding. The DSO returns42; the executable exits0 only if the mapping
and call both succeed. No guest libraries or libc are linked.

```sh
CC=cc bash tests/box32-stack-bridge/build.sh /tmp/stack-bridge
```

Run natively using an i386 dynamic loader, or copy both output files together
and run `./probe` from that directory under an explicit Box32 binary. Keep a
short timeout and disable core dumps. Use a fresh translator process: the probe
intentionally replaces a mapping below its own initial stack.

The native reference exits0. Before the stack-placement correction, the board
run overwrites the translator's low PLT resolver bridge, traps SIGSEGV and must
be killed by the timeout (137). The mapping succeeds; success of the mapping
alone is not success of the test. Record the after-fix result in AUDIT.md.
