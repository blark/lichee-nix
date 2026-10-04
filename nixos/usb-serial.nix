{ config, lib, ... }:
let
  inherit (lib.kernel) yes module;
in
{
  options.hardware.licheervNano.usbSerial.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Expose a USB CDC ACM login console on the Nano's USB-C port";
  };

  config = lib.mkIf config.hardware.licheervNano.usbSerial.enable {
    boot.kernelPatches = [
      {
        name = "licheerv-nano-usb-serial";
        patch = null;
        structuredExtraConfig = {
          USB = yes;
          USB_GADGET = yes;
          USB_DWC2 = yes;
          USB_DWC2_DUAL_ROLE = yes;
          PHY_SOPHGO_CV1800_USB2 = yes;
          USB_G_SERIAL = module;
        };
      }
    ];
    boot.kernelModules.g_serial = true;
    boot.extraModprobeConfig = ''
      options g_serial use_acm=1
    '';

    hardware.deviceTree.overlays = [
      {
        name = "licheerv-nano-usb-peripheral";
        filter = "sophgo/sg2002-licheerv-nano-b.dtb";
        dtsText = ''
          /dts-v1/;
          /plugin/;
          / {
            compatible = "sipeed,licheerv-nano-b";
            fragment@0 {
              target-path = "/soc/usb@4340000";
              __overlay__ {
                dr_mode = "peripheral";
                status = "okay";
              };
            };
          };
        '';
      }
    ];

    # Extend the upstream serial-getty template for the gadget's ttyGS0.
    systemd.services."serial-getty@ttyGS0" = {
      overrideStrategy = "asDropin";
      wantedBy = [ "getty.target" ];
      after = [ "systemd-modules-load.service" ];
    };
  };
}
