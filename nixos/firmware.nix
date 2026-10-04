{ pkgs, fiptool }:
let
  # Mainline U-Boot uses distro boot to read /boot/extlinux/extlinux.conf.
  uboot =
    (pkgs.buildUBoot {
      defconfig = "sipeed_licheerv_nano_defconfig";
      filesToInstall = [
        "u-boot.bin"
        "u-boot.dtb"
      ];
      # Upstream's tiny-kernel defaults omit ramdisk_addr_r and place the
      # FDT only 16 MiB above the kernel. Give NixOS's kernel/initrd room.
      extraConfig = ''
        CONFIG_BOARD_INIT=y
        CONFIG_BOOTCOMMAND="if mmc dev 0 && mmc rescan; then sysboot mmc 0:2 any 0x80c00000 /boot/extlinux/extlinux.conf; fi"
        CONFIG_USE_PREBOOT=y
        CONFIG_PREBOOT="setenv kernel_addr_r 0x80200000; setenv fdt_addr_r 0x85000000; setenv ramdisk_addr_r 0x86000000"
      '';
      extraMeta.platforms = [ "riscv64-linux" ];
    }).overrideAttrs
      (old: {
        # Keep nixpkgs' script interpreter fixes when adding PHY initialization.
        # The generic Linux PHY driver needs power and a nonzero PHY ID.
        postPatch = old.postPatch + ''
          cp board/sophgo/milkv_duo/board.c board/sophgo/licheerv_nano/board.c
          cp board/sophgo/milkv_duo/ethernet.{c,h} board/sophgo/licheerv_nano/
          echo 'obj-$(CONFIG_NET) += ethernet.o' >> board/sophgo/licheerv_nano/Makefile
        '';
      });
  opensbi =
    (pkgs.opensbi.override {
      withPlatform = "generic";
      withFDT = "${uboot}/u-boot.dtb";
    }).overrideAttrs
      (old: {
        makeFlags = old.makeFlags ++ [
          "CROSS_COMPILE=${pkgs.stdenv.cc.targetPrefix}"
        ];
      });
in
pkgs.buildPackages.runCommand "licheerv-nano-fip"
  {
    nativeBuildInputs = [ pkgs.buildPackages.python3 ];
    passthru = { inherit uboot opensbi; };
    meta = {
      description = "SG2002 boot firmware combining vendor FSBL, OpenSBI and U-Boot";
      homepage = "https://github.com/sophgo/fiptool";
      # fiptool is BSD-2-Clause, OpenSBI BSD-2-Clause and U-Boot GPL-2.0+.
      # The binary FSBL has no separate license grant in the pinned source.
      # Classify the combined artifact conservatively instead of claiming GPL.
      license = [
        pkgs.lib.licenses.bsd2
        pkgs.lib.licenses.gpl2Plus
        pkgs.lib.licenses.unfree
      ];
      sourceProvenance = [ pkgs.lib.sourceTypes.binaryFirmware ];
      platforms = [ pkgs.stdenv.buildPlatform.system ];
    };
  }
  ''
    mkdir -p "$out"
    # SG2002 has 256 MiB RAM and uses the CV181x FSBL, not CV180x.
    # No secondary-core RTOS is included in this NixOS image.
    touch empty-rtos.bin
    python3 ${fiptool}/fiptool \
      --fsbl ${fiptool}/data/fsbl/cv181x.bin \
      --ddr_param ${fiptool}/data/ddr_param.bin \
      --opensbi ${opensbi}/share/opensbi/lp64/generic/firmware/fw_dynamic.bin \
      --uboot ${uboot}/u-boot.bin \
      --rtos empty-rtos.bin \
      "$out/fip.bin"
    test -s "$out/fip.bin"
    mkdir -p "$out/share/licenses"
    cp ${fiptool}/LICENSE "$out/share/licenses/fiptool-LICENSE"
  ''
