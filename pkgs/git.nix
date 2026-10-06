{ pkgs }:
pkgs.gitMinimal.override {
  # Cross builds cannot execute Git's install tests; verify it on the Nano.
  doInstallCheck = pkgs.stdenv.buildPlatform.canExecute pkgs.stdenv.hostPlatform;
}
