{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.bat
    (import ../pkgs/box64.nix { inherit pkgs; })
    (import ../pkgs/dosbox.nix { inherit pkgs; })
    (import ../pkgs/fastfetch.nix { inherit pkgs; })
    (import ../pkgs/git.nix { inherit pkgs; })
    pkgs.htop
    pkgs.lsd
    pkgs.strace
    pkgs.vis
    pkgs.x11vnc
    pkgs.xdpyinfo
    pkgs.xorg-server
  ];
}
