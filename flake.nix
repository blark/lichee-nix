{
  description = "NixOS SD-card image for the Sipeed LicheeRV Nano (SG2002/C906)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    fiptool = {
      url = "github:sophgo/fiptool";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      fiptool,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      # Native RISC-V builds currently lack the GHC bootstrap used by NixOS tools.
      # Both supported hosts cross-compile to RISC-V.
      hosts = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forHosts = lib.genAttrs hosts;
      boardModule = {
        imports = [ ./nixos/licheerv-nano.nix ];
        _module.args.fiptool = fiptool;
      };
      displayModule = {
        hardware.licheervNano.display = {
          enable = true;
          initialization = ./display/ili9881c-waveshare-experimental.txt;
        };
      };
      systems = forHosts (
        buildSystem:
        let
          base = lib.nixosSystem {
            modules = [
              boardModule
              ./configuration.nix
              {
                nixpkgs.buildPlatform = buildSystem;
                nixpkgs.hostPlatform = "riscv64-linux";
                # Git exports record their revision; path checkouts may have none.
                system.configurationRevision = self.rev or (self.dirtyRev or null);
              }
            ];
          };
          display = base.extendModules { modules = [ displayModule ]; };
        in
        {
          inherit base display;
          nativePkgs = nixpkgs.legacyPackages.${buildSystem};
        }
      );
    in
    {
      nixosModules = {
        default = boardModule;
        licheerv-nano = boardModule;
      };
      nixosConfigurations.licheerv-nano = systems.x86_64-linux.base;
      packages = forHosts (
        host:
        let
          inherit (systems.${host}) base display;
        in
        {
          default = base.config.system.build.sdImage;
          sd-image = base.config.system.build.sdImage;
          display-sd-image = display.config.system.build.sdImage;
          firmware = base.config.system.build.licheervNanoFirmware;
          box64 = import ./pkgs/box64.nix { pkgs = base.pkgs; };
          dosbox = import ./pkgs/dosbox.nix { pkgs = base.pkgs; };
          fastfetch = import ./pkgs/fastfetch.nix { pkgs = base.pkgs; };
          git = import ./pkgs/git.nix { pkgs = base.pkgs; };
          inherit (base.pkgs)
            strace
            x11vnc
            xdpyinfo
            xorg-server
            ;
          display-kernel = display.config.boot.kernelPackages.kernel;
          display-driver = display.config.system.build.nanoDisplayDriver;
        }
      );
      checks = forHosts (
        host:
        let
          inherit (systems.${host}) base display nativePkgs;
        in
        {
          board-options = import ./nixos/options-check.nix {
            pkgs = nativePkgs;
            inherit base;
            exported = lib.nixosSystem {
              modules = [
                boardModule
                {
                  nixpkgs.buildPlatform = host;
                  nixpkgs.hostPlatform = "riscv64-linux";
                  system.stateVersion = "26.05";
                }
              ];
            };
          };
          sd-image = base.config.system.build.sdImage;
          display-sd-image = display.config.system.build.sdImage;
          board-config = import ./nixos/board-check.nix {
            pkgs = nativePkgs;
            config = base.config;
          };
          display-config = import ./nixos/display-check.nix {
            pkgs = nativePkgs;
            config = display.config;
          };
        }
        // lib.optionalAttrs (host == "x86_64-linux") {
          # i386 output could be cross-built anywhere, but RUNNING it needs an
          # x86 builder. Dropping the whole check elsewhere sacrifices its
          # compile-gate half: fixture compile rot can land from an aarch64
          # builder unnoticed. Accepted rather than plumbing a second
          # pkgsCross.gnu32 derivation through eight build.sh scripts that all
          # assume `cc -m32`, because x86_64 is the builder in practice.
          #
          # The fixture tree is passed without the files the build never opens:
          # fixtures-check.nix itself (its own definition inside its own input
          # closure), the READMEs, and weak-order's check.sh, which is a
          # board-side runner comparing two Box64 binaries over the built
          # fixture directory. Otherwise editing any
          # comment or README rebuilds all eight fixtures.
          box32-fixtures = import ./tests/fixtures-check.nix {
            pkgs = nativePkgs;
            tests = lib.fileset.toSource {
              root = ./tests;
              fileset = lib.fileset.difference ./tests (
                lib.fileset.unions [
                  ./tests/fixtures-check.nix
                  ./tests/box32-weak-order/check.sh
                  (lib.fileset.fileFilter (file: file.hasExt "md") ./tests)
                ]
              );
            };
          };
        }
      );
      formatter = forHosts (host: systems.${host}.nativePkgs.nixfmt);
      devShells = forHosts (
        host:
        let
          pkgs = systems.${host}.nativePkgs;
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.dosfstools
              pkgs.mtools
              pkgs.parted
              pkgs.picocom
              pkgs.util-linux
              pkgs.zstd
            ];
          };
        }
      );
    };
}
