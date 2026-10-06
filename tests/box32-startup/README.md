Static i386 syscall regression fixture for getpid20, uname122, time13,
ugetrlimit191 and setrlimit75. It checks successful outputs, guard bytes,
unaligned time output, EFAULT pointers and unchanged output on EINVAL.

Build on the host:

```sh
CC=cc bash tests/box32-startup/build.sh /tmp/box32-startup
```

The fixture uses -nostdlib and needs no i386 libc. Run natively on a Linux
host supporting i386, then copy to the target and invoke the explicit patched
Box32 binary with that fixture path. Exit0 with PASS is success; exit1 is a
failed assertion. It resets RLIMIT_STACK to its existing values rather than
changing them. A pass does not establish complete syscall compatibility.
