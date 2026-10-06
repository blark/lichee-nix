The libc-free instrument calls all 15 originally missing raw i386 file/time/
descriptor syscalls. It checks the 64-byte kernel stat and 96-byte stat64 ABI,
unaligned timeval output, buffer canaries, failure without output changes,
32/64-bit fcntl locks, polling/FIONREAD, and sparse seeks beyond 4 GiB.
Additional stages check IDs, nanosleep, writev, socketcall, SysV shared memory
and EFAULT after detachment; the protection tracker must forget detached pages.
Invalid _llseek output must still move the file position; an invalid descriptor
must take precedence over an invalid result pointer.

Build with an i386-capable C compiler:

```sh
CC=cc bash tests/box32-ordinary/build.sh /tmp/box32-ordinary
```

Run in a **new empty temporary directory**, natively or using an explicit Box32
store binary. It creates `probe.dat` (a sparse file) and `probe.dir`; remove these
and the temporary directory afterwards. Exit 0 prints PASS. A failure exits
with the numbered test stage (1–9). The pre-patch board build fails at stage 1;
the current seven-patch board build passes all nine stages. Use timeout and disable core
dumps when running translator experiments.

The kernel stat converter is intentionally distinct from libc's version-3 stat.
The lseek32 overflow check models a 32-bit Linux kernel; an x86_64 kernel's
compat path instead truncates some large lseek return values. The `_llseek`
instrument avoids that architecture-dependent behavior and verifies the full
64-bit offset directly. Generic ioctl handling reuses Box32's existing wrapper;
it does not add a comprehensive conversion of every architecture-specific ioctl.
