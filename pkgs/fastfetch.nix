{ pkgs }:
pkgs.fastfetch.override {
  audioSupport = false;
  brightnessSupport = false;
  codecSupport = false;
  dbusSupport = false;
  enlightenmentSupport = false;
  gnomeSupport = false;
  imageSupport = false;
  openclSupport = false;
  openglSupport = false;
  sqliteSupport = false;
  terminalSupport = false;
  vulkanSupport = false;
  waylandSupport = false;
  x11Support = false;
  xfceSupport = false;
  zfsSupport = false;
}
