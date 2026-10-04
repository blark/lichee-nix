# Experimental Nano display port

This work is separate from the default SD image. No display driver has been
loaded on the board and no screen has been tested.

The vendor transmitter source now uses Linux 7 GPIO descriptors, mandatory
MMIO resources, managed clocks, and the current platform remove/procfs APIs.
The standalone module includes register code from the vendor VPSS/base drivers
without their multimedia scheduling or ION buffer management. A new fbdev
implementation allocates one RGB888 DMA buffer (about 3 MiB at 800x1280).
The experimental kernel reserves 8 MiB for CMA and includes fbdev DMA helpers.

Build with `nix build .#display-driver --out-link result-display-driver`.
This module must be paired with `.#display-kernel`; it is not intended for the
currently running kernel, which lacks framebuffer support.

`nano-panel --describe` prints the two-lane transmitter reference mode.
`nano-panel --validate init.txt` checks command-file syntax and requires the
ILI9881C page-1 B7=03 lane selection. `--init init.txt` configures the hardware
and sends the commands. Do not use the lane-only reference as full panel init.
Lines contain hexadecimal DCS bytes; `delay 120` waits 120 milliseconds.

The experimental mode uses LCKFB's documented 10.1-inch timings: 800x1280,
58.96 Hz, HSA/HBP/HFP 12/18/18, VSA/VBP/VFP 4/12/24, 66000 kHz pixel clock,
RGB888 burst mode (792 Mbps per lane before protocol overhead).
Physical TX lanes are data0, clock, data1, disabled, disabled. The experimental initialization copies Waveshare's default ILI9881C table
and startup commands, including page-1 B7=03 for two lanes. The user authorized
this candidate based on the matching controller and resolution; it has not
been tested on the LCKFB panel. Commands retain the upstream delays.
Waveshare's driver selects command page 1 then writes B7=03 for two lanes;
it does not write register 00 for this operation.

Still required before a hardware boot:
- Review the experimental MMIO/clock/reset device tree and verify pinmux on hardware.
- Test the experimental Waveshare sequence with the LCKFB timings.
- Map the 31-pin pitch adapter and six-pin touch crossover.
- Boot the built experimental SD image on a spare card (module closure checks pass).
- Test output and DMA coherency; add GT9271 support and test touch.

Sources:
- https://github.com/sipeed/LicheeRV-Nano-Build/blob/d4003f15b35d43ad4842f427050ab2bba0114fa5/middleware/v2/component/panel/sg200x/dsi_zct2133v1.h
- https://github.com/sipeed/LicheeRV-Nano-Build/blob/d4003f15b35d43ad4842f427050ab2bba0114fa5/middleware/v2/component/panel/sg200x/dsi_ili9881c.h
- https://github.com/waveshareteam/Waveshare-ESP32-components/blob/master/display/lcd/esp_lcd_ili9881c/esp_lcd_ili9881c.c

The NixOS module provides `hardware.licheervNano.display.enable = true` and an
optional `hardware.licheervNano.display.initialization = ./panel-init.txt`.
The default is disabled. Enabling it selects the experimental kernel, adds
`nano_mipi` to the trimmed module closure, exposes `nano-panel`, and applies
the vendor MMIO resources and Nano GPIOE0 reset / GPIOE2 backlight mapping.
The GPIOE controller at 0x05021000 is added from the vendor device tree.
An initialization file enables an automatic oneshot service; without one,
startup is manual. Pin multiplexing and physical wiring remain unverified.

## Experimental panel image

`nix build .#display-sd-image --out-link result-display-image` includes the
framebuffer kernel, transmitter module, and an automatic panel initialization
service using `ili9881c-waveshare-experimental.txt`. The default `sd-image`
continues to leave display disabled. No card has been flashed with this profile.

The command table is derived from Espressif's Apache-2.0 licensed code in the
Waveshare component; its copyright, license identifier, source URL and source
SHA256 are recorded in the profile. This candidate is not a confirmed LCKFB
vendor initialization.

LCKFB timings source:
https://wiki.lckfb.com/zh-hans/tspi-rk3566/system-usage/android-system-usage.html

The supplied eight-page LCKFB panel specification was inspected.
Pages 3 and 4 provide touch and DSI wiring; page 4 lists 1.8 V reset/VDDIO
with a separate 3.3 V variant note. Page 7 points to screen firmware/code,
but does not contain a register initialization table.

The experimental image and updated driver build successfully; `result-display-image`
points to the image. The profile parser and device-tree/module closure checks pass.
No display hardware has been exercised.

## Saved CanMV alternative

See [CANMV-COMPARISON.md](CANMV-COMPARISON.md) for the pinned upstream source,
register differences, corrected timings and fallback instructions.
`ili9881c-canmv-two-lane.experimental.txt` preserves the CanMV command table
and delays with page-1 B7=03 added; it passes the initialization parser.
The current Waveshare profile remains selected.
