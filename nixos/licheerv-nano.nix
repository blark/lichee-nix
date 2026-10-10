{
  config,
  lib,
  pkgs,
  modulesPath,
  fiptool,
  ...
}:
let
  inherit (lib.kernel) yes;
  firmware = import ./firmware.nix { inherit pkgs fiptool; };
  boardModules = pkgs.makeModulesClosure {
    kernel =
      if config.hardware.licheervNano.display.enable then
        config.system.build.nanoDisplayModules
      else
        config.boot.kernelPackages.kernel.modules;
    firmware = pkgs.runCommand "nano-no-firmware" { } "mkdir -p $out/lib/firmware";
    rootModules = config.boot.kernelModules ++ [
      "mmc_block"
      "zram"
      "lz4"
      "lzo"
      "lzo-rle"
      "usb_f_acm"
      "usb_f_serial"
      "u_serial"
      "configfs"
      "fuse"
      "overlay"
      "dm_mod"
      "af_packet"
      "ipv6"
      "nf_tables"
      "nft_compat"
      "nft_ct"
      "nft_fib_inet"
      "nft_reject_inet"
      "nft_log"
      "xt_tcpudp"
      "xt_conntrack"
      "xt_state"
      "xt_limit"
      "xt_LOG"
      "xt_pkttype"
      "xt_addrtype"
      "ipt_rpfilter"
      "ip6t_rpfilter"
      "ipt_REJECT"
      "ip6t_REJECT"
    ];
    allowMissing = false;
  };
in
{
  imports = [
    "${modulesPath}/installer/sd-card/sd-image.nix"
    "${modulesPath}/profiles/minimal.nix"
    ./usb-serial.nix
    ./ethernet.nix
    ./dropbear.nix
    ./display.nix
    ./programs.nix
  ];

  boot = {
    # USB controller/PHY support for SG2002 is present in Linux 7.0.
    kernelPackages = pkgs.linuxPackagesFor (
      import ./kernel.nix {
        inherit pkgs lib;
        display = config.hardware.licheervNano.display.enable;
      }
    );
    kernelModules = {
      # Override only the upstream PC keyboard entry, preserving other modules.
      atkbd = lib.mkForce false;
      nano_mipi = lib.mkIf config.hardware.licheervNano.display.enable true;
    };
    kernelPatches = [
      {
        name = "licheerv-nano-boot-drivers";
        patch = null;
        structuredExtraConfig = {
          ARCH_SOPHGO = yes;
          ERRATA_THEAD = yes;
          PINCTRL = yes;
          CLK_SOPHGO_CV1800 = yes;
          PINCTRL_SOPHGO_CV1800B = yes;
          PINCTRL_SOPHGO_SG2002 = yes;
          MMC = yes;
          MMC_SDHCI = yes;
          MMC_SDHCI_PLTFM = yes;
          MMC_SDHCI_OF_DWCMSHC = yes;
          SERIAL_8250 = yes;
          SERIAL_8250_CONSOLE = yes;
          SERIAL_8250_DW = yes;
        };
      }
    ];
    kernelParams = [
      "console=ttyS0,115200n8"
      "earlycon"
      # Reboot through the RTC's WARM reset request, as Sipeed's vendor kernel
      # does (cvi-reboot.c); RISC-V otherwise defaults to REBOOT_COLD, which
      # takes the RTC driver's power-cycle path.
      "reboot=warm"
    ];
    loader.grub.enable = false;
    loader.generic-extlinux-compatible.enable = true;
    loader.generic-extlinux-compatible.configurationLimit = 3;
    # MEASURED, by building both initrds and unpacking them from the store:
    #
    #   systemd initrd   25,131kB compressed   64,988kB unpacked
    #   scripted initrd   9,928kB compressed   24,770kB unpacked
    #
    # So this saves 40,218kB (39MB) of initramfs. It does NOT save 63.5MB and
    # it does not stop the retention described below: roughly 24MB of unpacked
    # initramfs is still written into the same rootfs.
    #
    # WHY THAT MATTERS: on the running board, 70,256kB of 251,108kB MemTotal
    # sits on the unevictable LRU and never comes back. A /proc/kpageflags scan
    # over all 65,536 DRAM pages found 17,564 unevictable pages, every one
    # file-backed (zero anonymous), all UPTODATE|DIRTY|LRU, with the count
    # unchanged to the byte across 'echo 3 > drop_caches' (while Cached fell
    # 133,316 -> 83,784kB) and across swapoff/swapon, and nr_mlock 0 throughout.
    # Dirty file pages that can never be written back is the ramfs signature,
    # and 70,256kB matches the systemd initrd's 70,056kB unpacked by du.
    #
    # Why those pages are unevictable rather than merely retained, and why
    # this setting fixes that too - the part worth understanding before anyone
    # reverts it. The kernel unpacks the initramfs into rootfs, and
    # init_rootfs() in init/do_mounts.c:513-521 (linux 7.0.12) makes rootfs
    # ramfs unless CONFIG_TMPFS is on AND either no root= was given or
    # rootfstype names tmpfs:
    #
    #   if (!saved_root_name[0] && !root_fs_names)                is_tmpfs = true;
    #   else if (root_fs_names && strstr(root_fs_names, "tmpfs"))  is_tmpfs = true;
    #
    # A SYSTEMD initrd puts root= on the cmdline - nixpkgs
    # nixos/modules/system/boot/systemd/initrd.nix:522,
    # `lib.optional (config.boot.initrd.systemd.root != null) "root=..."`, whose
    # default is "fstab". __setup("root=", root_dev_setup) copies that into
    # saved_root_name, the first branch cannot fire, and rootfs is ramfs. Ramfs
    # pages can never be written back (fs/ramfs/inode.c calls
    # mapping_set_unevictable on every inode), so whatever of the initramfs is
    # never deleted is pinned for the life of the boot. Verified on the running
    # board: /proc/cmdline, the device tree's /chosen/bootargs and the SD card's
    # extlinux APPEND line all carry `root=fstab`, and that generation's own
    # kernel-params in the store reads
    # "console=ttyS0,115200n8 earlycon root=fstab loglevel=4 lsm=...".
    #
    # Turning the systemd initrd off removes root= with it. The built toplevel's
    # kernel-params for this configuration is
    # "console=ttyS0,115200n8 earlycon loglevel=4 lsm=landlock,yama,bpf" - no
    # root= - so the first branch fires and rootfs becomes tmpfs, whose pages
    # are swap-backed and evictable (tmpfs marks a mapping unevictable only for
    # `noswap`, which rootfs never sets). The board has 634MB of swap.
    #
    # So this setting is expected to do two things: cut the initramfs by 39MB,
    # and make whatever is still retained reclaimable instead of pinned. An
    # explicit "rootfstype=tmpfs" kernel parameter would be redundant and was
    # removed after review - with no root= present the first branch already
    # fires.
    #
    # MEASURED on the board after booting this generation, and it beat the
    # prediction: Unevictable went to 0 and MemAvailable to 208,152kB, from
    # 70,256kB unevictable and ~127MB available before. So nothing at all is
    # retained, not the ~24MB residual predicted from the initrd's unpacked
    # size - with rootfs as tmpfs the pages are either freed by switch_root or
    # swappable, and either way they stop being pinned.
    #
    # That also settles the mechanism: the retention was never inherent to
    # initramfs. nixpkgs' stage-1-init.sh says "switch_root deletes all files
    # in the ramfs on the current root", and dropping root= let that stand.
    #
    # What the scripted initrd does NOT drop: scripted stage-1 copies udevadm
    # and systemd-sysctl into extra-utils, so 8.4MB of systemd 260 survives
    # (libsystemd-shared 5,411,496B + libsystemd.so.0 1,935,936B +
    # libudev.so.1 1,445,856B). The 13MB of systemd in the systemd initrd
    # becomes 8.4MB, a ~4MB delta, not 13. It also hardcodes lvm and dmsetup
    # (stage-1.nix copy_bin_and_libs ${getBin pkgs.lvm2}/bin/lvm) and their
    # libcrypto, so extra-utils keeps patchelf'ed copies totalling 7.2MB that
    # NO option removes. services.lvm.enable = false leaves the initrd
    # byte-identical - it changes only the stage-2 closure - so it is not set
    # here. The saving comes from dropping PID 1, the unit tree, bash,
    # coreutils, curl, krb5, tpm2-tss and libxml2.
    #
    # DEPRECATED ON ARRIVAL: this is the configuration's only warnings entry -
    # "Scripted initrd is deprecated and scheduled for removal in 26.11", and
    # the pin IS 26.11 while flake.nix tracks the moving nixos-unstable branch.
    # When the facility goes, either eval breaks or the board silently reverts
    # to the 63.5MB systemd initrd. options-check.nix asserts this stays false
    # so that revert cannot pass the checks unnoticed.
    #
    # mkDefault, not a bare literal: this module is exported, and a consumer
    # wanting LUKS, TPM unlock or repart needs a systemd initrd back.
    initrd.systemd.enable = lib.mkDefault false;
    # Upstream SD image defaults assume a PC; this board needs only mmc_block.
    initrd.availableKernelModules = lib.mkForce [ ];
    # The host controller is built in, but Nixpkgs builds its block-device
    # layer as a module. Include and load it before looking for NIXOS_SD.
    initrd.kernelModules = [ "mmc_block" ];
    # Override upstream filesystem defaults to avoid unavailable kernel modules.
    supportedFilesystems = lib.mkForce [
      "ext4"
      "vfat"
    ];
  };

  hardware = {
    # sd-image.nix enables every device by default; override it for this small board.
    enableAllHardware = lib.mkForce false;
    enableRedistributableFirmware = lib.mkDefault false;
    deviceTree = {
      enable = true;
      name = "sophgo/sg2002-licheerv-nano-b.dtb";
    };
  };

  # The vendor FSBL is the only unfree artifact admitted by this board module.
  nixpkgs.config.allowUnfreePredicate = package: lib.getName package == "licheerv-nano-fip";
  system.build.licheervNanoFirmware = firmware;
  sdImage = {
    compressImage = false;
    firmwareSize = 32;
    firmwarePartitionName = "FIRMWARE";
    populateFirmwareCommands = ''
      cp ${firmware}/fip.bin firmware/fip.bin
    '';
    populateRootCommands = ''
      # Include swap before first boot, when the root partition is still small.
      # Nonzero contents prevent mkfs.ext4 -d from turning this into holes.
      head -c 536870912 /dev/zero | tr '\000' '\001' > ./files/swapfile
      chmod 600 ./files/swapfile
      ${pkgs.buildPackages.util-linux}/bin/mkswap -U 9d3b8614-5729-4ca8-80ed-30c5b01fe8bd ./files/swapfile
      ${config.boot.loader.generic-extlinux-compatible.populateCmd} \
        -c ${config.system.build.toplevel} -d ./files/boot
    '';
  };

  # Package only the board's modular drivers and their dependencies. The
  # kernel itself is reused; unrelated PC/device modules stay off the SD.
  system.modulesTree = lib.mkForce [
    (pkgs.runCommand "nano-kernel-modules" { } ''
      cp -a ${boardModules}/. "$out/"
      chmod -R u+w "$out"
      for hints in modules.order modules.builtin modules.builtin.modinfo; do
        cp ${config.boot.kernelPackages.kernel.modules}/lib/modules/*/$hints "$out/lib/modules/"*/
      done
    '')
  ];

  # Default to minimal services for 256 MiB RAM; consumers can opt back in.
  documentation.enable = lib.mkDefault false;
  documentation.nixos.enable = lib.mkDefault false;
  services.udisks2.enable = lib.mkDefault false;
  services.nscd.enable = lib.mkDefault false;
  # Serial and SSH shells do not need a systemd user manager on this board.
  services.logind.enable = lib.mkDefault false;
  users.manageLingering = lib.mkDefault false;
  security.pam.services = {
    login.startSession = lib.mkForce false;
    sshd.startSession = lib.mkForce false;
    systemd-user.startSession = lib.mkForce false;
  };
  systemd.services."systemd-logind".enable = lib.mkDefault false;
  systemd.services."user@".enable = lib.mkDefault false;
  # Keep the boot service that removes /run/nologin and permits logins.
  systemd.additionalUpstreamSystemUnits = [ "systemd-user-sessions.service" ];
  # The fixed files/DNS databases below do not use NSS plugin libraries.
  system.nssModules = lib.mkForce [ ];
  # Override systemd/NSS defaults consistently with disabled session management.
  system.nssDatabases = {
    passwd = lib.mkForce [ "files" ];
    group = lib.mkForce [ "files" ];
    hosts = lib.mkForce [
      "files"
      "dns"
    ];
  };
  systemd.oomd.enable = lib.mkDefault false;
  services.journald.extraConfig = ''
    Storage=volatile
    RuntimeMaxUse=8M
    RuntimeMaxFileSize=2M
  '';
  swapDevices = [
    {
      device = "/swapfile";
      size = 512;
      priority = 10;
    }
  ];
  zramSwap = {
    enable = true;
    memoryPercent = 50;
    algorithm = "lz4";
    priority = 100;
  };
  # Ensure swap is usable before the first-boot Nix database import.
  systemd.services.register-nix-paths.after = [ "swap.target" ];
  nix.settings = {
    max-jobs = 1;
    cores = 1;
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };
}
