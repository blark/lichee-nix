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
    # handlers and unwind it in sigreturn(119). See
    # /var/tmp/megatouch/handover/notes/sigframe-implementation-plan.md
    ./box64-elf32-legacy-sigframe.patch
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
