{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.licheervNano.display;
  kernel = config.boot.kernelPackages.kernel;
  driver = import ../pkgs/nano-display.nix { inherit pkgs kernel; };
in
{
  options.hardware.licheervNano.display = {
    enable = lib.mkEnableOption "experimental SG2002 two-lane MIPI framebuffer";
    initialization = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Panel DCS initialization file; null leaves panel startup manual.";
    };
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ driver ];
    system.build.nanoDisplayDriver = driver;
    system.build.nanoDisplayModules =
      pkgs.buildPackages.runCommand "nano-display-modules"
        {
          nativeBuildInputs = [ pkgs.buildPackages.kmod ];
        }
        ''
          cp -a ${kernel.modules}/. "$out/"
          chmod -R u+w "$out"
          cp -a ${driver}/lib/modules/${kernel.modDirVersion}/extra "$out/lib/modules/${kernel.modDirVersion}/"
          depmod -b "$out" ${kernel.modDirVersion}
        '';
    hardware.deviceTree.overlays = [
      {
        name = "licheerv-nano-experimental-display";
        filter = "sophgo/sg2002-licheerv-nano-b.dtb";
        dtsText = ''
          /dts-v1/;
          /plugin/;
          #include <dt-bindings/clock/sophgo,cv1800.h>
          #include <dt-bindings/gpio/gpio.h>
          / {
            compatible = "sipeed,licheerv-nano-b";
            fragment@0 {
              target-path = "/soc";
              __overlay__ {
                #address-cells = <1>;
                #size-cells = <1>;
                gpio@5021000 {
                  compatible = "snps,dw-apb-gpio";
                  reg = <0x05021000 0x1000>;
                  #address-cells = <1>;
                  #size-cells = <0>;
                  nano_porte: gpio-controller@0 {
                    compatible = "snps,dw-apb-gpio-port";
                    gpio-controller;
                    #gpio-cells = <2>;
                    ngpios = <32>;
                    reg = <0>;
                  };
                };
                mipi-tx@a080000 {
                  compatible = "cvitek,mipi_tx";
                  reg = <0x0a080000 0x10000>, <0x0a0d1000 0x100>, <0x0a0c8000 0xa0>;
                  reg-names = "scaler", "dphy", "vip-sys";
                  clocks = <&clk CLK_DISP_VIP>, <&clk CLK_DSI_MAC_VIP>,
                           <&clk CLK_SC_TOP_VIP>, <&clk CLK_AXI_VIP>, <&clk CLK_CFG_REG_VIP>;
                  clock-names = "clk_disp", "clk_dsi", "clk_sc", "clk_axi", "clk_cfg";
                  reset-gpios = <&nano_porte 0 GPIO_ACTIVE_LOW>;
                  pwm-gpios = <&nano_porte 2 GPIO_ACTIVE_HIGH>;
                  width = <800>;
                  height = <1280>;
                  status = "okay";
                };
              };
            };
          };
        '';
      }
    ];
    systemd.services.nano-panel = lib.mkIf (cfg.initialization != null) {
      description = "Initialize the Nano's two-lane ILI9881C panel";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-modules-load.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${driver}/bin/nano-panel --init ${cfg.initialization}";
      };
    };
  };
}
