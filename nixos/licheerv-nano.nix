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
    ];
    loader.grub.enable = false;
    loader.generic-extlinux-compatible.enable = true;
    loader.generic-extlinux-compatible.configurationLimit = 3;
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
