{ pkgs, tests }:
# The box32-* fixtures are the regression tests for the Box32 patch stack.
# Until this check existed nothing ran them, so a fixture could stop compiling
# and no build would notice. It is substantially a COMPILE gate - it builds all
# eight and runs five - which is worth knowing when reading the x86-only gate in
# flake.nix, where the rationale for that gate lives.
#
# WHAT IS ASSERTED, per fixture, and nothing more:
#   brk, ordinary, select, signals, startup   built AND run
#   getdents, stack-bridge, weak-order        built, and every documented
#                                             output asserted to be ELF32 i386
#
# Running those five is meaningful because each of their READMEs documents a
# native i386 reference result, which is what the patches are measured against.
# signals ships its own runner, check-native.sh, asserting three exit codes
# including two deliberately broken controls; this calls it rather than
# re-implementing a third of it. select builds a second -select-only binary
# that skips getppid so a _newselect failure becomes reachable, and that is run
# too; it depends on the preceding full-select call having built it.
#
# IT DOES NOT EXERCISE BOX64. The translator this flake builds targets riscv64
# and cannot run on the builder, so running the fixtures under the patched
# Box64 stays a board job.
#
# THREE ARE NOT RUN, each for its own reason:
#
#   getdents      Its README states in capitals that the probe only
#                 discriminates on a directory that actually returns 64-bit
#                 cookies; here it would scan the build directory and pass on a
#                 handful of entries with no overflow, which is the vacuous
#                 PASS that README warns against.
#   stack-bridge  Dynamically linked, and this binutils-wrapper has no
#                 nix-support/dynamic-linker-m32, so its 32-bit branch never
#                 fires and a 64-bit -dynamic-linker is injected into the i386
#                 link. The binary cannot reach any exit code, and there is no
#                 i386 loader in this stdenv's closure.
#   weak-order    Links with -Wl,--dynamic-linker,/lib/ld-linux.so.2 on
#                 purpose. nixpkgs' ld-wrapper rejects that as an impure path -
#                 the sandbox is not involved, ld never opens the string - and
#                 the double-dash spelling misses the wrapper's skip branch, so
#                 the path hits its generic impure-path rejection. The build
#                 therefore sets NIX_ENFORCE_PURITY=0, which is an UNDOCUMENTED
#                 wrapper variable with no stability contract, not a supported
#                 escape hatch. Both the bintools wrapper and the cc wrapper
#                 read it, so it disarms impure-path filtering for every
#                 COMPILE as well as every link in that build.sh - all five
#                 links, not just the three that need it. If it ever breaks, link without the flag and set
#                 PT_INTERP afterwards with patchelf --set-interpreter.
#
# hardeningDisable: the fixtures are -nostdlib with no libc, and the default
# hardening set is injected into code they control deliberately. Several
# already pass -fno-stack-protector/-no-pie to undo it; turning it off matches
# the plain `cc -m32` the fixtures document.
#
# runCommandCC, not runCommand: runCommand uses stdenvNoCC and would need a
# compiler bolted on. Every build.sh defaults to "${CC:-cc}", which the CC
# wrapper provides - as does readelf, via the propagated bintools wrapper.
pkgs.runCommandCC "box32-fixtures-check"
  {
    hardeningDisable = [ "all" ];
  }
  ''
    # Fixtures run in their own directory. box32-ordinary's README asks for a
    # fresh one; what its probe actually requires is that no probe.dir exists
    # yet, since it mkdirs that and tolerates a stale probe.dat.
    # Every binary this file touches gets its ABI asserted, run or not. Without
    # it the run path is a vacuous gate: box32-startup and box32-select build
    # cleanly as x86-64 and still print PASS, so a fixture that lost -m32 would
    # sail through a check whose stated job is catching exactly that.
    assert_i386() {
      local f="$1"
      test -f "$f"
      readelf -h "$f" | grep -q 'Class: *ELF32'
      readelf -h "$f" | grep -q 'Machine: *Intel 80386'
      # e_type too, or a stray relocatable object satisfies the other two. The
      # five run fixtures would fail at exec anyway; the three that are only
      # asserted have nothing downstream to notice.
      readelf -h "$f" | grep -qE 'Type: *(EXEC|DYN) '
      echo "    $(basename "$f"): ELF32 Intel 80386"
    }

    run_fixture() {
      local name="$1"
      local binary=""
      if [ "$#" -gt 1 ]; then
        binary="$2"
      fi
      local d="$NIX_BUILD_TOP/run-$name"
      mkdir -p "$d"
      ( cd "$d"
        if [ -z "$binary" ]; then
          echo "=== $name: build and run ==="
          bash "${tests}/$name/build.sh" "$d/$name"
          binary="$d/$name"
        else
          echo "=== $name: run $binary ==="
          binary="$d/$binary"
        fi
        assert_i386 "$binary"
        ulimit -c 0
        timeout -k 2 60 "$binary" | tee "$d/out-$(basename "$binary")"
        grep -q '^PASS' "$d/out-$(basename "$binary")" )
    }

    # Every listed output must exist and be ELF32 i386. Naming them is the
    # point: a glob with a >0 count passes on one correct file among wrong ones.
    build_i386() {
      local name="$1" kind="$2" purity="$3"
      shift 3
      echo "=== $name: build, assert $# output(s) are ELF32 i386 ==="
      local d="$NIX_BUILD_TOP/build-$name"
      mkdir -p "$d"
      ( cd "$d"
        if [ "$purity" = impure-link ]; then
          export NIX_ENFORCE_PURITY=0
        fi
        if [ "$kind" = file ]; then
          bash "${tests}/$name/build.sh" "$d/$name"
        else
          bash "${tests}/$name/build.sh" "$d"
        fi
        local f
        test "$#" -gt 0          # naming no outputs would assert nothing
        for f in "$@"; do
          assert_i386 "$d/$f"
        done )
    }

    run_fixture box32-brk
    run_fixture box32-ordinary
    run_fixture box32-startup
    run_fixture box32-select
    run_fixture box32-select box32-select-select-only

    # signals ships its own runner, which sets its own ulimit and timeouts and
    # asserts exits 0, 1 and 139.
    echo "=== box32-signals: its own check-native.sh ==="
    ( d="$NIX_BUILD_TOP/run-box32-signals"
      mkdir -p "$d"; cd "$d"
      bash "${tests}/box32-signals/build.sh" "$d/box32-signals"
      assert_i386 "$d/box32-signals"
      assert_i386 "$d/box32-signals-bad-restorer"
      assert_i386 "$d/box32-signals-no-nesting"
      bash "${tests}/box32-signals/check-native.sh" "$d/box32-signals" )

    build_i386 box32-getdents     file      pure         box32-getdents
    build_i386 box32-stack-bridge directory pure         libanswer.so probe
    build_i386 box32-weak-order   directory impure-link \
        libfirst.so libsecond.so first-wins reverse-wins weak-reference

    touch "$out"
  ''
