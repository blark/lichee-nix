{ pkgs, kernel }:
pkgs.stdenv.mkDerivation {
  pname = "licheerv-nano-display";
  version = "0.1";
  src = ../vendor/nano-display;
  nativeBuildInputs = kernel.moduleBuildDependencies;
  buildPhase = ''
    runHook preBuild
    make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
      M=$PWD ARCH=riscv CROSS_COMPILE=${pkgs.stdenv.cc.targetPrefix} -j$NIX_BUILD_CORES modules
    $CC -O2 -Wall -Wextra -Werror -Iinclude/chip/mars/uapi \
      ${../display/nano-panel.c} -o nano-panel
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/modules/${kernel.modDirVersion}/extra
    cp nano_mipi.ko $out/lib/modules/${kernel.modDirVersion}/extra/
    mkdir -p $out/bin
    cp nano-panel $out/bin/
    mkdir -p $out/share/nano-display
    cp ${../display/ili9881c-waveshare-experimental.txt} $out/share/nano-display/ili9881c-waveshare-experimental.txt
    cp ${../display/LICENSE.waveshare} $out/share/nano-display/LICENSE.waveshare
    runHook postInstall
  '';
  # The kernel module is relocatable ELF; patchelf must only touch userspace binaries.
  dontPatchELF = true;
  meta = {
    description = "Experimental SG2002 MIPI DSI and single-buffer framebuffer driver";
    license = [
      pkgs.lib.licenses.gpl2Only
      pkgs.lib.licenses.asl20
    ];
    mainProgram = "nano-panel";
    platforms = [ "riscv64-linux" ];
  };
}
