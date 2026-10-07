{
  pkgs,
  base,
  exported,
}:
let
  withoutUsb =
    (base.extendModules {
      modules = [ { hardware.licheervNano.usbSerial.enable = false; } ];
    }).config;
  withoutKeys =
    (base.extendModules {
      modules = [ { users.users.root.openssh.authorizedKeys.keys = pkgs.lib.mkForce [ ]; } ];
    }).config;
  withKeys =
    (base.extendModules {
      # This string checks option composition only; no image uses this fixture.
      modules = [ { users.users.root.openssh.authorizedKeys.keys = [ "evaluation-only" ]; } ];
    }).config;
  extraModule =
    (base.extendModules {
      modules = [ { boot.kernelModules = [ "extra-test-module" ]; } ];
    }).config;
in
assert !(builtins.elem "g_serial" withoutUsb.boot.kernelModules);
assert
  !(builtins.elem "licheerv-nano-usb-peripheral" (
    map (overlay: overlay.name) withoutUsb.hardware.deviceTree.overlays
  ));
assert !(builtins.elem "atkbd" base.config.boot.kernelModules);
assert builtins.elem "g_serial" base.config.boot.kernelModules;
assert builtins.elem "extra-test-module" extraModule.boot.kernelModules;
# A systemd initrd costs this 245MB board 39MB of permanently-held initramfs,
# measured; licheerv-nano.nix carries the figures. Scripted stage-1 is
# deprecated upstream with removal targeted at 26.11 and this flake tracks
# nixos-unstable, so assert the setting rather than let a silent revert to the
# 64,988kB initrd pass every check in the repo.
assert !base.config.boot.initrd.systemd.enable;
assert !withoutKeys.services.licheervNano.dropbear.enable;
assert withKeys.services.licheervNano.dropbear.enable;
# Instantiating the consumer's system validates that the exported module
# supplies fiptool itself, without the flake's own specialArgs or configuration.
assert exported.config.system.build.toplevel.drvPath != "";
pkgs.runCommand "licheerv-nano-option-check" { } ''
  echo 'USB toggle, module composition, SSH configuration and exported module passed' > "$out"
''
