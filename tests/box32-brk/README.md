This static i386 fixture uses raw int80 brk(45), without a libc wrapper. It
checks repeated queries, byte-accurate break returns, writable growth, shrink,
zero-filled regrowth of a released page, rejected addresses, and an anonymous
mapping that growth must not overwrite. It assumes 4096-byte pages.

```sh
CC=cc bash tests/box32-brk/build.sh /tmp/brk-probe
/path/to/box64 /tmp/brk-probe
```

A native x86 Linux run prints the PASS message and exits 0. The previous
Box32 build returns ENOSYS on the first query and exits 1. An implementation
that only pretends to grow or that clobbers an existing mapping fails.
This does not test simultaneous calls, asynchronous signal reentry, the
wrapped syscall() entry point, or RLIMIT_DATA accounting.
