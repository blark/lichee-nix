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
  exportedWithKey = (
    exported.extendModules {
      # Evaluation-only key: proves the default does not key off its presence.
      modules = [ { users.users.root.openssh.authorizedKeys.keys = [ "evaluation-only" ]; } ];
    }
  );
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
# Dropbear must come up WITHOUT declared keys too: this is a public repo that
# carries none, and gating enablement on them produced a board reachable only
# over serial. Public-key-only with no keys accepts nobody, so this is safe.
assert withoutKeys.services.licheervNano.dropbear.enable;
assert withKeys.services.licheervNano.dropbear.enable;
assert builtins.elem 22 withoutKeys.networking.firewall.allowedTCPPorts;
# The exported module must NOT enable it: importing board support should never
# open a port on a consumer's machine.
assert !exported.config.services.licheervNano.dropbear.enable;
# ...and with a key present but no explicit enable, so ONLY the option default
# decides. Reverting the default to `keys != []` flips this and nothing else
# catches it: base sets enable = true outright, so the other assertions pass
# either way.
assert !exportedWithKey.config.services.licheervNano.dropbear.enable;
# preStart must install the key file only when keys are declared. Without this
# pair, reverting that conditional passes every check in the flake - and the
# unconditional version overwrites the device's working authorized_keys with an
# empty file, which is how a rebuild locks you out.
assert !(pkgs.lib.hasInfix "authorized_keys" withoutKeys.systemd.services.dropbear.preStart);
assert pkgs.lib.hasInfix "authorized_keys" withKeys.systemd.services.dropbear.preStart;
# Instantiating the consumer's system validates that the exported module
# supplies fiptool itself, without the flake's own specialArgs or configuration.
assert exported.config.system.build.toplevel.drvPath != "";
pkgs.runCommand "licheerv-nano-option-check" { } ''
  echo 'USB toggle, module composition, SSH configuration and exported module passed' > "$out"
''
