Static i386 fixture for getppid64, pipe42 and _newselect142 (register arguments).
It tests empty/readable pipe fdsets, four-byte bitmap guards, a real50ms wait,
timeval guards, EFAULT and EINVAL.

```sh
CC=cc bash tests/box32-select/build.sh /tmp/box32-select
```

This builds /tmp/box32-select and a -select-only variant that skips getppid.
Both use -nostdlib and need no i386 libc. Run them natively, then copy both to
the board and invoke the explicit Box32 binary. The old build fails the full
probe at syscall64 and the select-only probe at142; the current patched build
passes both. Exit0 plus PASS is success; exit1 means a failed assertion.
The implementation currently limits nfds to FD_SETSIZE and does not serialize
concurrent unmaps during guest-pointer validation.
