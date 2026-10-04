{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.bat
    (import ../pkgs/dosbox.nix { inherit pkgs; })
    (import ../pkgs/fastfetch.nix { inherit pkgs; })
    pkgs.htop
    pkgs.lsd
    pkgs.vis
  ];
}
