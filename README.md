# NixOS for LicheeRV Nano

A Nix flake that cross-compiles an SD-card image for the **Sipeed LicheeRV
Nano E**, using the Sophgo SG2002's C906 RISC-V core and 256 MiB RAM.
This project targets the Nano, rather than the Allwinner D1 LicheeRV.

The image combines a board-specific mainline Linux 7.0.12 kernel, U-Boot,
OpenSBI, Sophgo's binary first-stage bootloader, and a minimal NixOS system.

## Status

| Feature | Status |
| --- | --- |
| SD boot and serial login | Tested on Nano E hardware |
| Ethernet DHCP | Tested |
| Dropbear public-key SSH | Tested; SFTP is not included |
| Root partition expansion | Tested after correcting kernel configuration |
| Swap | LZ4 zram plus a 512 MiB SD swap file; tested |
| Box64 / BOX32 | 32-bit and 64-bit ELF smoke tests passed with RISC-V dynarec |
| Xvfb / x11vnc | Headless 800×1280 display and VNC connection tested |
| Experimental MIPI framebuffer | Driver and image build; hardware untested |
| GT9271 touch | Not implemented yet |
| Wi-Fi, camera, TPU, auxiliary-core firmware | Not configured |

The system uses NixOS's minimal profile and a reduced kernel/module closure.
It disables logind and systemd user sessions, the NSS cache, and the systemd
OOM daemon, and limits volatile journal storage to 8 MiB. Serial and SSH
shells work, but `systemctl --user` and automatic user runtime directories
are unavailable. About 130 MiB of RAM was available in observed idle tests;
actual usage depends on the image and workload.

## Configure access

A fresh checkout builds without credentials and provides serial login.
To enable SSH, edit `configuration.nix` and add **your public SSH key** to
`users.users.root.openssh.authorizedKeys.keys`. Dropbear defaults to disabled
when the list is empty; explicitly enabling it without a key is rejected.
No personal SSH keys are supplied. Never add a private key.

The initial serial login is `root` with password `nixos`. Change it with
`passwd` on first boot. Dropbear accepts public-key authentication only and
creates a persistent Ed25519 host key on the board.

The default hostname is `licheerv-nano`, timezone is UTC, and Ethernet uses
DHCP. Find its address in your router's lease list, then connect with:

```sh
ssh root@BOARD_ADDRESS
```

## Build

Use a Linux host with Nix and the `nix-command` and `flakes` features enabled.
The checked-in lock file pins inputs; retain it for reproducible builds.
`nix flake update nixpkgs` advances the branch input when an update is wanted.

```sh
nix build .#sd-image -L
ls -lh result/sd-image/*.img
nix build .#checks.x86_64-linux.board-config
```

Build hosts are `x86_64-linux` and `aarch64-linux`; the target is always
`riscv64-linux`. Native RISC-V builds are not supported by the pinned Nixpkgs
GHC bootstrap required by some build tools. The builds performed during
development used an x86_64 Linux host and cross-compilation, without a VM or
RISC-V emulation. Other build hosts have not been tested. Allow tens of GB
of free disk space and time for the initial kernel/userspace build.

If a configured binary cache fails:

```sh
nix build .#sd-image -L --option substituters https://cache.nixos.org
```

For the boot firmware alone, run `nix build .#firmware -L`.

## Flash and boot

Identify the whole SD-card device and unmount its partitions. An 8 GB or
larger card is a practical starting point. The following command **overwrites
the selected card**; replace `/dev/sdX` with its whole-device path.

```sh
lsblk -o NAME,SIZE,MODEL,MOUNTPOINTS
sudo dd if=result/sd-image/*.img of=/dev/sdX bs=4M conv=fsync status=progress
sync
```

The image has an MBR, a FAT firmware partition containing `fip.bin`, and an
ext4 NixOS root partition. U-Boot loads `/boot/extlinux/extlinux.conf`.
The boot chain is ROM → vendor FSBL → OpenSBI → U-Boot → Linux → NixOS.
The root partition and filesystem expand on first boot.

UART0 runs at **115200 baud, 8N1**. Use a 3.3 V USB-to-TTL adapter and the
board schematic to connect TX, RX, and ground. UART0 also appears on USB-C
SBU pins when accessed through a suitable breakout; a normal USB cable
cannot expose that raw UART. Linux can provide a separate USB CDC ACM login
interface after the gadget driver loads.

```sh
nix develop
picocom -b 115200 /dev/ttyUSB0
# Or use the enumerated /dev/ttyACM* device for Linux USB serial.
```

USB serial does not expose early boot logs. Set
`hardware.licheervNano.usbSerial.enable = false` to restore USB host mode.

## Experimental display

The optional display stack ports Sipeed's MIPI transmitter/register code to
mainline Linux and adds a single 800×1280 RGB888 framebuffer (~3 MiB), with
8 MiB reserved for contiguous DMA allocation. It targets a two-lane ILI9881C
panel. **The screen has not been tested on hardware.**

```sh
nix build .#display-sd-image --out-link result-display-image -L
nix build .#checks.x86_64-linux.display-config
```

This image enables the display kernel/module, device-tree overlay, and
automatic panel initialization. Its candidate profile uses Waveshare's
ILI9881C sequence with page-1 `B7=03` for two lanes, together with LCKFB's
documented 800×1280 timings: 66 MHz pixel clock, approximately 59 Hz.
The default `sd-image` leaves display disabled.

See [display notes](display/README.md) for wiring and configuration, and
[the CanMV comparison](display/CANMV-COMPARISON.md) for a saved alternative
initialization sequence and timings. Neither candidate is confirmed as the
exact LCKFB vendor initialization. Touch support remains pending.

The display uses Linux's device tree and `nano-panel` service; Sipeed's
vendor `panel=...` selection in `uEnv.txt` does not configure this port.

## Optional packages

```sh
nix build .#fastfetch
nix build .#box64
nix build .#git
nix build .#xorg-server .#x11vnc .#strace .#xdpyinfo
nix build .#dosbox
nix build .#display-driver
nix build .#display-kernel
```

Fastfetch omits desktop/media detection dependencies and has been tested on
the board. DOSBox 0.74-3 uses software X11 rendering and omits OpenGL and
hardware audio backends. Its headless x86 execution smoke test passed using
`scripts/dosbox-smoke.sh`; games, graphics, audio, and performance remain
untested. The default image includes htop, bat, lsd, vis, Fastfetch, and this DOSBox
package, so they survive regenerating the SD card. Box64 is also included,
with BOX32 enabled for 32-bit x86 programs and RISC-V dynarec. `SAVE_MEM` is
disabled because Box64 0.4.4's RISC-V backend lacks its extra jump-table level;
enabling it crashes dynamically linked programs on this board.
Invoke either x86-64 or x86 executables explicitly with `box64 PROGRAM`;
automatic binfmt registration is not configured. Applications may also need
x86 libraries and corresponding native libraries; this package does not
provide a complete x86 distribution or Wine environment.

The experimental Box32 patches handle ELF32 version definitions without a
version-needs table, weak-provider ordering, guest brk and selected startup
syscalls. Heap and startup/select fixtures pass on the board. Fully emulating
an old i386 userland still encounters missing signal support; the passing
fixtures and smoke tests do not establish complete application compatibility.
See `AUDIT.md` for the measured translator failures. OverlayFS is available
for temporary chroot roots; the game and its rootfs are not included here.

Xvfb (from Xorg server), x11vnc, strace and xdpyinfo are included for headless
X11 sessions and debugging. These tools do not start automatically.
Git's minimal build is included, with HTTPS support. It omits the manual,
Perl/Python helpers and PCRE2 support to keep the board's closure small.

The display driver must be paired with the display kernel; it cannot be
loaded into the default kernel, which lacks framebuffer support.

## Project layout

- `nixos/`: board, kernel, boot firmware, services, device trees, and build checks.
- `pkgs/`: cross-built package definitions.
- `vendor/nano-display/`: vendor-derived display code and framebuffer implementation.
- `display/`: initialization profiles, upstream reference, and comparison notes.
- `AUDIT.md`: development findings and historical hardware validation.

## Upstream sources and licensing

- [Sipeed Nano SDK](https://github.com/sipeed/LicheeRV-Nano-Build)
- [U-Boot Nano documentation](https://docs.u-boot.org/en/latest/board/sophgo/licheerv_nano.html)
- [Sophgo FIP tool and FSBL](https://github.com/sophgo/fiptool)
- [Sipeed peripheral documentation](https://wiki.sipeed.com/hardware/en/lichee/RV_Nano/5_peripheral.html)
- [LCKFB panel documentation](https://wiki.lckfb.com/zh-hans/tspi-rk3566/system-usage/android-system-usage.html)

Imported code retains its upstream notices. Waveshare's command-table source
uses Apache-2.0; the saved CanMV source includes BSD terms. Display driver
files retain their individual license notices; see the vendor README.
The boot chain includes a vendor binary FSBL without a separate license grant
in the pinned source. The assembled firmware is conservatively marked unfree;
the board allows only that package through its unfree predicate. Review the
vendor binary's redistribution terms before distributing built images.
No blanket license is assigned
to this repository; check component licenses before redistributing.

## Checks and downstream use

`nix flake check --no-build --all-systems` evaluates every supported output.
`nix flake check -L` also builds the default and display SD images, board
content checks, display integration checks and module option regression checks
for the current build host.

The exported `nixosModules.licheerv-nano` (also `nixosModules.default`) supplies
its own firmware-tool input.
Downstream configurations can import it with `nixpkgs.hostPlatform` set to
`riscv64-linux` and a supported `nixpkgs.buildPlatform`. It includes the board
image, minimal services and requested programs; add hostname, access settings,
and `system.stateVersion` in the consuming configuration.

If you set your own `nixpkgs.config.allowUnfreePredicate`, include
`"licheerv-nano-fip"` alongside your other allowed package names. Nixpkgs does
not union predicates from different modules; a consumer predicate can replace
the board's firmware allowance.

Minimal service settings are defaults that consumers can override. Full
systemd session management also requires enabling the `systemd-logind` and
`user@` units and overriding this board's PAM `startSession` and NSS settings;
enabling `services.logind` alone does not restore those facilities.
