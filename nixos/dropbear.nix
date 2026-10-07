{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.licheervNano.dropbear;
  rootKeys = pkgs.writeText "dropbear-root-authorized-keys" (
    lib.concatStringsSep "\n" config.users.users.root.openssh.authorizedKeys.keys + "\n"
  );
in
{
  options.services.licheervNano.dropbear.enable = lib.mkOption {
    type = lib.types.bool;
    # Off by default, because this module is exported (flake.nix sets it as
    # nixosModules.default) and importing a board-support module must not stand
    # up a network listener or open a firewall port for a third party. That is
    # nixpkgs' own convention - lib.mkEnableOption hardcodes default = false.
    #
    # configuration.nix turns it ON. That file is part of `base` but not of
    # boardModule, so a clean checkout of this repo still builds a board with
    # SSH while consumers of the exported module get nothing they did not ask
    # for. This matters: enablement used to default to `keys != []`, and since
    # no key may be committed to this PUBLIC repo, deploying a build from a
    # clean checkout produced a board reachable only over serial.
    default = false;
    description = "Run the public-key-only Dropbear server (opens TCP 22)";
  };
  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      networking.firewall.allowedTCPPorts = [ 22 ];
      warnings = lib.optional (config.users.users.root.openssh.authorizedKeys.keys == [ ]) ''
        services.licheervNano.dropbear is enabled with no declared root keys.
        Access then depends entirely on /root/.ssh/authorized_keys already
        existing on the device: this build will not create it, and on a freshly
        flashed card it does not exist, so there is NO ssh access at all.
        Paste a public key into configuration.nix to change that.
      '';
      systemd.services.dropbear = {
        description = "Dropbear SSH server";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        # Override the service path so interactive SSH shells can find system
        # commands. This is mkForce rather than systemd.services.<n>.path
        # because that option is implemented BY setting environment.PATH, so
        # the two cannot coexist: a mkForce here discards the list entirely.
        # preStart and ExecStart use absolute store paths, so nothing in the
        # unit depends on PATH.
        environment.PATH = lib.mkForce "/run/wrappers/bin:/root/.nix-profile/bin:/run/current-system/sw/bin";
        preStart = ''
          ${pkgs.coreutils}/bin/install -d -m 0700 /root/.ssh /var/lib/dropbear
          ${
            # Declared keys are authoritative. With none declared, leave whatever
            # is on the device alone - overwriting it with an empty file is how a
            # rebuild locks you out.
            lib.optionalString (config.users.users.root.openssh.authorizedKeys.keys != [ ]) ''
              ${pkgs.coreutils}/bin/install -m 0600 ${rootKeys} /root/.ssh/authorized_keys
            ''
          }
          if [ ! -s /var/lib/dropbear/host_key ]; then
            ${pkgs.dropbear}/bin/dropbearkey -t ed25519 -f /var/lib/dropbear/host_key
          fi
        '';
        serviceConfig = {
          Type = "simple";
          # Foreground, journal logging, no passwords, and one persistent Ed25519 key.
          ExecStart = "${pkgs.dropbear}/bin/dropbear -F -E -s -r /var/lib/dropbear/host_key -p 22";
          Restart = "on-failure";
          RestartSec = 2;
          UMask = "0077";
        };
      };
    })
  ];
}
