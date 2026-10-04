{ pkgs }:
let
  # Software rendering through X11; omit desktop services, OpenGL, and codecs.
  sdl3 = pkgs.sdl3.override {
    alsaSupport = false;
    dbusSupport = false;
    drmSupport = false;
    ibusSupport = false;
    jackSupport = false;
    libdecorSupport = false;
    libudevSupport = false;
    libusbSupport = false;
    openglSupport = false;
    pipewireSupport = false;
    pulseaudioSupport = false;
    sndioSupport = false;
    traySupport = false;
    vulkanSupport = false;
    waylandSupport = false;
    x11Support = true;
  };
  sdl2 = pkgs.sdl2-compat.override { inherit sdl3; };
  sdl1 = pkgs.sdl12-compat.override {
    sdl2-compat = sdl2;
    openglSupport = false;
  };
  networking = pkgs.SDL_net.override {
    SDL = sdl1;
    enableSdltest = false;
  };
in
(pkgs.dosbox.override {
  SDL = sdl1;
  SDL_net = networking;
  SDL_sound = null;
  libGL = null;
  libGLU = null;
}).overrideAttrs
  (old: {
    # Icon conversion is unnecessary and adds an unrelated graphics toolchain.
    nativeBuildInputs = builtins.filter (
      dependency: dependency != pkgs.buildPackages.graphicsmagick
    ) old.nativeBuildInputs;
    postInstall = "";
    configureFlags = (old.configureFlags or [ ]) ++ [
      "--disable-sdltest"
      "--disable-opengl"
    ];
  })
