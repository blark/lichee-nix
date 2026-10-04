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
assert !withoutKeys.services.licheervNano.dropbear.enable;
assert withKeys.services.licheervNano.dropbear.enable;
# Instantiating the consumer's system validates that the exported module
# supplies fiptool itself, without the flake's own specialArgs or configuration.
assert exported.config.system.build.toplevel.drvPath != "";
pkgs.runCommand "licheerv-nano-option-check" { } ''
  echo 'USB toggle, module composition, SSH configuration and exported module passed' > "$out"
''
