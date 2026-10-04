# Vendor source provenance

These 39 source/header files were copied from Sipeed's public SDK:
https://github.com/sipeed/LicheeRV-Nano-Build/tree/d4003f15b35d43ad4842f427050ab2bba0114fa5/osdrv/interdrv/v2

Original paths are preserved. The module declares GPL licensing; original
copyright and licensing notices remain in the copied files.

Local changes:
- vo/chip/mars/vo_mipi_tx.c: descriptor GPIOs, managed clocks/MMIO resources,
  standalone register-base setup, framebuffer registration, backlight control,
  and current platform remove API; remove integer GPIO module parameter.
- vo/chip/mars/proc/vo_mipi_tx_proc.c: current pde_data API and build label.
- nano_fb.c: new single-buffer RGB888 framebuffer implementation.
- Makefile: build only MIPI, scaler register, DPHY, VIP register, and fbdev code.

See ../../display/README.md for integration status and limits.
- Guard uninitialized DPHY clock readback against division by zero; constrain
  transmitter configuration to this board's two-lane 800x1280 RGB888 mode.
- Use /proc/nano_mipi for diagnostics without the vendor /proc/cvitek parent.

Display-only controller initialization initializes its shadow-register lock and
FIFO threshold, forces its clock on and leaves unhandled interrupts disabled.
