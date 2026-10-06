{ pkgs }:
pkgs.box64.overrideAttrs (old: {
  # Pin the current stable release independently of the image's older Nixpkgs.
  version = "0.4.4";
  src = pkgs.fetchFromGitHub {
    owner = "ptitSeb";
    repo = "box64";
    tag = "v0.4.4";
    hash = "sha256-vcF3zYONE1P3DcXoo9PEETMDTA08QQi042SHt+hAT+Q=";
  };
  # Old ld-linux has version definitions without a version-needs table.
  # Resolve those definitions instead of passing a null name to strcmp.
  # ORDER IS LOAD-BEARING: brk, startup-syscalls, legacy-sigframe,
  # ordinary-syscalls and clone-tls all edit src/emu/x86syscall_32.c.
  # Each patch was generated with its predecessors applied. Append at the end.
  # Verified in this order: zero fuzz and zero offset for every hunk.
  # Flake evaluation alone does not run patchPhase; a real build does.
  patches = (old.patches or [ ]) ++ [
    ./box64-elf32-version-definitions.patch
    # Keep the first matching weak provider: old libc and ld-linux both
    # export malloc, and choosing the loader's bootstrap allocator fails.
    ./box64-elf32-weak-order.patch
    # Emulated libc needs a guest heap, separate from the translator's brk.
    ./box64-elf32-brk.patch
    # Raw i386 syscalls used when guest libc is emulated rather than wrapped.
    ./box64-elf32-startup-syscalls.patch
    # i386 legacy signal frame: build a real frame for non-SA_SIGINFO
    # handlers and unwind it in sigreturn(119). Runtime status is in AUDIT.md.
    ./box64-elf32-legacy-sigframe.patch
    # File, time and descriptor syscalls with the i386 kernel ABI.
    ./box64-elf32-ordinary-syscalls.patch
    # Separate-PID CLONE_VM children need independent initialized host TLS.
    ./box64-elf32-clone-tls.patch
    # Descending fixed thread stacks must stay away from low PLT bridges.
    ./box64-elf32-initial-stack.patch
    # Raw read/write/close returned a libc-style -1, which in the raw syscall
    # convention IS -EPERM, so a non-blocking socket's EAGAIN reached the guest
    # as EPERM and Xlib killed the X connection as fatal.
    ./box64-elf32-raw-errno.patch
  ];
  # RV64 libc has no x86 port-permission calls. Match Box64's existing
  # 64-bit iopl wrapper instead of leaving BOX32's weak imports unresolved.
  postPatch = (old.postPatch or "") + ''
    substituteInPlace src/wrapped32/wrappedlibc_private.h \
      --replace-fail 'GOW(iopl, iEi)' 'GOM(iopl, iFEi)' \
      --replace-fail 'GOW(ioperm, iELLi)' 'GOM(ioperm, iFEuui)'
    cat >> src/wrapped32/wrappedlibc.c <<'EOF'

    EXPORT int my32_iopl(x64emu_t* emu, int level)
    {
        (void)emu;
        (void)level;
        errno = ENOSYS;
        return -1;
    }

    EXPORT int my32_ioperm(x64emu_t* emu, unsigned int from, unsigned int num, int turn_on)
    {
        (void)emu;
        (void)from;
        (void)num;
        (void)turn_on;
        errno = ENOSYS;
        return -1;
    }
    EOF
  '';
  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.buildPackages.patchelf ];
  # Wrapped graphics libraries are dlopened by soname. Nix has no /usr/lib
  # search path, including inside ruby-chroot's read-only store bind.
  postFixup = (old.postFixup or "") + ''
    patchelf --add-rpath "$graphicsLibraries" "$out/bin/box64"
  '';
  graphicsLibraries = pkgs.lib.makeLibraryPath [
    pkgs.freetype
    pkgs.libX11
    pkgs.libXext
    pkgs.libXrandr
    pkgs.libXrender
  ];
  cmakeFlags = (old.cmakeFlags or [ ]) ++ [
    (pkgs.lib.cmakeBool "BOX32" true)
    # RV64's indirect lookup lacks SAVE_MEM's extra jump-table level in 0.4.4.
    # Enabling it jumps into data when dynamically linked programs call libc.
    (pkgs.lib.cmakeBool "SAVE_MEM" false)
  ];
  meta = old.meta // {
    changelog = "https://github.com/ptitSeb/box64/releases/tag/v0.4.4";
    description = "x86-64 and x86 Linux userspace emulator with RISC-V dynarec";
  };
})
