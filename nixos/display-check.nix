{ pkgs, config }:
let
  driver = config.system.build.nanoDisplayDriver;
  kernel = config.boot.kernelPackages.kernel;
  modules = config.system.modulesTree;
in
pkgs.runCommand "nano-display-build-check"
  {
    nativeBuildInputs = [
      pkgs.dtc
      pkgs.kmod
      pkgs.stdenv.cc
    ];
  }
  ''
    cc -O2 -Wall -Wextra -Werror -I${../vendor/nano-display/include/chip/mars/uapi} \
      ${../display/nano-panel.c} -o nano-panel-check
    ./nano-panel-check --validate ${../display/ili9881c-waveshare-experimental.txt}
    test -n '${config.systemd.services.nano-panel.serviceConfig.ExecStart}'
    dtb=${config.hardware.deviceTree.package}/sophgo/sg2002-licheerv-nano-b.dtb
    test "$(fdtget "$dtb" /soc/mipi-tx@a080000 width)" = 800
    test "$(fdtget "$dtb" /soc/mipi-tx@a080000 height)" = 1280
    test "$(fdtget "$dtb" /soc/mipi-tx@a080000 status)" = okay
    test "$(fdtget -t x "$dtb" /soc/mipi-tx@a080000 reg)" = "a080000 10000 a0d1000 100 a0c8000 a0"
    test -f ${modules}/lib/modules/${kernel.modDirVersion}/extra/nano_mipi.ko
    test "$(modinfo -F vermagic ${driver}/lib/modules/${kernel.modDirVersion}/extra/nano_mipi.ko | cut -d' ' -f1)" = ${kernel.modDirVersion}
    grep -q '^CONFIG_FB_DMAMEM_HELPERS=y$' ${kernel.configfile}
    grep -q '^CONFIG_CMA_SIZE_MBYTES=8$' ${kernel.configfile}
    mkdir -p $out
    echo 'Display DT, kernel configuration, module ABI and trimmed closure passed' > $out/result
  ''
