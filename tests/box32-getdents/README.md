This static i386 fixture reads a directory with raw `getdents64(220)` through
`int $0x80`, with no libc, and checks every returned record against the range
limits glibc's 32-bit `readdir()` applies when it converts `linux_dirent64`
into a 32-bit `struct dirent`. glibc range-checks BOTH `d_ino` and `d_off`,
and a single value that does not fit fails the WHOLE call with `EOVERFLOW`,
so the guest sees an empty directory rather than a short one.

```sh
CC=cc bash tests/box32-getdents/build.sh /tmp/getdents-probe
/path/to/box64 /tmp/getdents-probe /some/directory
```

It takes the directory as its argument and defaults to `.`. It exits 0 when
every entry would survive the conversion and 1 when any would not, printing
the entry count and the two overflow counts either way.

A native x86 Linux run prints PASS and exits 0: a real i386 kernel narrows the
cookie for 32-bit tasks, because ext4 tests `is_32bit_api()`. A Box32 build
without the `getdents64-cookie` patch passes the full 64-bit cookie through to
a guest that cannot represent it. Measured on one ext4 directory of 45 files:

```
before the patch   entries=0x2d ino_over32=0x0 off_over32=0x2d   exit 1
after the patch    entries=0x2d ino_over32=0x0 off_over32=0x0    exit 0
```

THE INSTRUMENT ONLY DISCRIMINATES ON A DIRECTORY THAT ACTUALLY RETURNS 64-BIT
COOKIES. ext4 produces them for hash-indexed directories; on a small or
unindexed one, and on tmpfs, the offsets are small byte positions and an
unpatched build passes too — proving nothing. Before trusting a PASS, confirm
the directory can produce a FAIL by running the same probe there under a build
that lacks the patch. Pointing it at a large directory such as a Nix store is
the easy way to get a hash-indexed one.

This does not test `telldir`/`seekdir` round-tripping, which the narrowing
deliberately sacrifices, nor the syscall-141 path, which upstream already
converts.
