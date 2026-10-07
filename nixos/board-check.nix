{ pkgs, config }:
let
  kernel = config.boot.kernelPackages.kernel;
  dtbs = config.hardware.deviceTree.package;
  initrd = config.system.build.initialRamdisk;
  system = config.system.build.toplevel;
in
pkgs.runCommand "licheerv-nano-board-check"
  {
    nativeBuildInputs = [
      pkgs.cpio
      pkgs.dtc
      pkgs.python3
      pkgs.zstd
    ];
  }
  ''
    dtb=${dtbs}/sophgo/sg2002-licheerv-nano-b.dtb
    test "$(fdtget "$dtb" /soc/ethernet@4070000 status)" = okay
    test "$(fdtget "$dtb" /soc/mdio-mux@3009800 status)" = okay
    test "$(fdtget "$dtb" /soc/ethernet@4070000 phy-mode)" = internal
    test "$(fdtget "$dtb" /aliases ethernet0)" = /soc/ethernet@4070000
    test "$(fdtget "$dtb" /soc/usb@4340000 dr_mode)" = peripheral
    test "$(fdtget "$dtb" /soc/usb@4340000 status)" = okay
    test "$(fdtget "$dtb" /soc/mmc@4310000 status)" = okay
    test "$(fdtget "$dtb" /soc/serial@4140000 status)" = okay
    test -L ${system}/etc/systemd/system/getty.target.wants/serial-getty@ttyGS0.service
    test -L ${system}/etc/systemd/system/multi-user.target.wants/dhcpcd.service
    ${pkgs.lib.optionalString config.services.licheervNano.dropbear.enable ''
      test -L ${system}/etc/systemd/system/multi-user.target.wants/dropbear.service
      grep -q 'dropbear -F -E -s -r /var/lib/dropbear/host_key -p 22' ${system}/etc/systemd/system/dropbear.service
      startup=$(sed -n 's/^ExecStartPre=//p' ${system}/etc/systemd/system/dropbear.service)
      grep -q '/bin/dropbearkey -t ed25519' "$startup"
      if grep -Eq '^[[:space:]]*dropbearkey ' "$startup"; then
        echo 'Dropbear startup uses an unqualified dropbearkey command' >&2
        exit 1
      fi
    ''}
    test ! -L ${system}/etc/systemd/system/multi-user.target.wants/sshd.service
    for program in bat box64 dosbox fastfetch git htop lsd strace vis Xvfb x11vnc xdpyinfo; do
      test -x ${system}/sw/bin/$program
    done
    grep -q 'snps,dwmac-3.70a.*dwmac_generic' ${config.system.modulesTree}/lib/modules/${kernel.modDirVersion}/modules.alias
    grep -q 'mdio-mux-mmioreg.*mdio_mux_mmioreg' ${config.system.modulesTree}/lib/modules/${kernel.modDirVersion}/modules.alias
    for driver in usb_f_acm usb_f_serial zram lz4 lzo lzo-rle overlay; do
      find ${config.system.modulesTree}/lib/modules -name "$driver.ko*" | grep -q .
    done
    test ! -L ${system}/etc/systemd/system/multi-user.target.wants/nscd.service
    test ! -L ${system}/etc/systemd/system/multi-user.target.wants/systemd-oomd.service
    test ! -L ${system}/etc/systemd/system/multi-user.target.wants/systemd-logind.service
    test ! -L ${system}/etc/systemd/system/multi-user.target.wants/linger-users.service
    for service in login systemd-user; do
      if grep -q 'pam_systemd.so' ${system}/etc/pam.d/$service; then
        echo "Unexpected pam_systemd session in $service" >&2
        exit 1
      fi
    done
    grep -q 'pam_unix.so' ${system}/etc/pam.d/login
    test -L ${system}/etc/systemd/system/multi-user.target.wants/systemd-user-sessions.service
    grep -q '/swapfile'  ${system}/etc/fstab
    # Inspect the archive itself: a controller driver alone cannot expose
    # the card's block device, and a Nix option assertion would miss that.
    # A root= on the cmdline makes the kernel pick ramfs over tmpfs for rootfs
    # (init_rootfs, init/do_mounts.c:513-521), which pins every retained
    # initramfs page on the unevictable LRU - 70,256kB of 251,108kB measured on
    # this board. The systemd initrd adds root=fstab via nixpkgs
    # systemd/initrd.nix:522; nothing should bring it back.
    # Not "! grep -q": bash exempts a !-inverted command from set -e, so that
    # spelling can never fail the build.
    if grep -qE '(^| )root=' ${system}/kernel-params; then
      echo "root= on the kernel cmdline: rootfs becomes ramfs and the retained" >&2
      echo "initramfs is pinned unevictable. See licheerv-nano.nix." >&2
      exit 1
    fi
    zstd -dc ${initrd}/initrd | cpio -it > initrd-files
    grep -E '(^|/)mmc_block\.ko(\.(xz|zst|gz))?$' initrd-files
    python3 - <<'PY'
    from pathlib import Path
    kernel_config = Path('${kernel.configfile}').read_text()
    required = [
        'BINFMT_ELF', 'BINFMT_SCRIPT', 'DEVTMPFS', 'CGROUPS', 'INOTIFY_USER',
        'SIGNALFD', 'TIMERFD', 'EPOLL', 'NET', 'SYSFS', 'PROC_FS', 'FHANDLE',
        'CRYPTO_USER_API_HASH', 'CRYPTO_HMAC', 'CRYPTO_SHA256', 'AUTOFS_FS',
        'TMPFS_POSIX_ACL', 'TMPFS_XATTR', 'SECCOMP', 'SECCOMP_FILTER', 'SWAP',
        'EXT4_FS', 'BLK_DEV_WRITE_MOUNTED', 'MMC_SDHCI_OF_DWCMSHC', 'SERIAL_8250_CONSOLE',
        'RISCV_DMA_NONCOHERENT', 'ERRATA_THEAD_CMO', 'ERRATA_THEAD_MAE',
        'USB_DWC2', 'PHY_SOPHGO_CV1800_USB2', 'ZRAM_BACKEND_LZ4',
    ]
    for symbol in required:
        assert f'CONFIG_{symbol}=y\n' in kernel_config, symbol
    for symbol in ['SMP', 'MEM_ALLOC_PROFILING', 'PCI', 'DRM', 'SOUND']:
        assert f'CONFIG_{symbol}=y\n' not in kernel_config, symbol
    assert Path('${kernel}/Image').stat().st_size < 16 * 1024 * 1024
    assert Path('${kernel}/Image').stat().st_size < 0x85000000 - 0x80200000
    assert Path('${initrd}/initrd').stat().st_size < 0x8f000000 - 0x86000000
    PY
    touch "$out"
  ''
