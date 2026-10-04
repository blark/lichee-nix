{ ... }:
{
  # CV1800B's MAC uses the generic DesignWare driver. The Sophgo-specific
  # dwmac_sophgo module is for SG2042/SG2044, not this board.
  boot.kernelModules = [
    "dwmac_generic"
    "mdio_mux_mmioreg"
  ];

  hardware.deviceTree.overlays = [
    {
      name = "licheerv-nano-ethernet";
      filter = "sophgo/sg2002-licheerv-nano-b.dtb";
      dtsText = ''
        /dts-v1/;
        /plugin/;
        / {
          compatible = "sipeed,licheerv-nano-b";
          fragment@0 {
            target-path = "/soc/ethernet@4070000";
            __overlay__ { status = "okay"; };
          };
          fragment@1 {
            target-path = "/soc/mdio-mux@3009800";
            __overlay__ { status = "okay"; };
          };
          fragment@2 {
            target-path = "/aliases";
            __overlay__ { ethernet0 = "/soc/ethernet@4070000"; };
          };
        };
      '';
    }
  ];
}
