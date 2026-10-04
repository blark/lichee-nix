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
    default = config.users.users.root.openssh.authorizedKeys.keys != [ ];
    description = "Run the public-key-only Dropbear server; defaults on when root has authorized keys";
  };
  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      networking.firewall.allowedTCPPorts = [ 22 ];
      assertions = [
        {
          assertion = config.users.users.root.openssh.authorizedKeys.keys != [ ];
          message = "Dropbear root access requires an authorized public key.";
        }
      ];
      systemd.services.dropbear = {
        description = "Dropbear SSH server";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        path = [
          pkgs.coreutils
          pkgs.dropbear
        ];
        # Override the service path so interactive SSH shells can find system commands.
        environment.PATH = lib.mkForce "/run/wrappers/bin:/root/.nix-profile/bin:/run/current-system/sw/bin";
        preStart = ''
          ${pkgs.coreutils}/bin/install -d -m 0700 /root/.ssh /var/lib/dropbear
          ${pkgs.coreutils}/bin/install -m 0600 ${rootKeys} /root/.ssh/authorized_keys
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
