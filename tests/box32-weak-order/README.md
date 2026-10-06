This regression test builds two i386 shared objects exporting the same weak
`foo@@FOO_1.0`, returning 11 and 22. Two executables reverse their DT_NEEDED
order and require the first provider's value. A third uses a weak undefined
reference to exercise Box32's separate weak lookup helper. Exit 1 means the
wrong provider won; exit 0 means the expected provider won.

Build on the host with a compiler supporting i386 assembly and linking:

```sh
CC=cc bash tests/box32-weak-order/build.sh /tmp/box32-weak-order
```

These fixtures use `-nostdlib`, so they do not require i386 libc or libgcc.
Copy the output directory to the target, preserving the two shared libraries
beside the executables. Run both builds on the target:

```sh
bash check.sh /path/to/original/box64 /path/to/patched/box64 /path/to/fixtures
```

The check requires the original build to fail with the specific wrong-answer
exit code and the patched build to pass in both orders. Both builds must
include the separate ELF32 version-definition fix; otherwise a loader failure
would not isolate weak lookup. The test covers the ordinary and weak-reference
global lookup paths. It does not exercise RTLD_NEXT/NoSelf, strong-versus-weak
precedence, or every possible loader placement in a dependency graph.
