# Board image audit

The Ethernet-enabled image builds successfully. Static checks verify the
configuration and packaged files below; running them does not establish
that the board has booted or that a physical Ethernet link works.

## Corrections

- Enabled the Ethernet MAC and MDIO mux in the board device tree.
- Load `dwmac_generic` and `mdio_mux_mmioreg`. The MAC's
  `snps,dwmac-3.70a` compatibility selects the generic DesignWare driver;
  `dwmac_sophgo` supports other Sophgo chips and is not this MAC's driver.
- Enabled U-Boot's board initialization and reused upstream Milk-V Duo's
  CV1800B PHY initialization. It powers the integrated PHY, assigns the
  nonzero PHY ID needed by Linux's generic PHY driver, and switches the
  PHY back to MDIO access. The previous Nano build skipped this step.
- Configured public-key access. Root SSH remains
  key-only, with password and keyboard-interactive authentication disabled.

## Verified

| Area | Evidence |
| --- | --- |
| Architecture | Linux and U-Boot both describe RV64IMAFDC and 256 MiB RAM; the target is RISC-V with the LP64D ABI. |
| Boot firmware | U-Boot board and Ethernet initialization compile; OpenSBI and the CV181x FSBL are packaged into the new `fip.bin`. |
| Image layout | Valid MBR; FAT firmware and ext4 root partitions fit the image; root label matches `NIXOS_SD`; packaged firmware exactly matches the newly built FIP. |
| Boot files | Extlinux references the final system, kernel, initrd, and overlaid DTB; all referenced files exist inside the root image. |
| Memory layout | The 46,991,872-byte kernel and 25,864,465-byte initrd fit their load regions without overlapping the configured FDT location. |
| SD boot | SD controller, pinctrl, clocks, reset, and ext4 drivers are built in; the SD node is enabled. The corrected initrd archive contains `mmc_block.ko`, and the module is explicitly loaded before root mounting. |
| CPU/DMA | T-Head errata and RISC-V noncoherent DMA handling are enabled. |
| Serial | UART0 is enabled at 115200 8N1; USB controller/PHY and ACM gadget drivers are present; USB mode is peripheral; `ttyGS0` getty is enabled. |
| Ethernet | MAC and MDIO nodes are enabled with internal PHY mode; both required modules exist and their aliases match the device tree. |
| Networking/login | DHCP and SSH services are enabled; a user-supplied key is packaged in root's authorized keys; serial root password starts as `nixos`. |
| Storage/RAM | First-boot root expansion and Nix store registration services are enabled; zram support and its service are present. |

`nix flake check --no-build --all-systems` passes. The built
`checks.x86_64-linux.board-config` checks device-tree status and mode,
driver aliases, login/network service links, and boot load sizes.
It also decompresses the initrd and checks that `mmc_block.ko` is actually
packaged, rather than relying solely on kernel configuration.

## First physical boot findings

UART0 confirmed that FSBL, OpenSBI, and U-Boot run on the board. U-Boot
initially reported SD read/stop-command errors. After an MMC rescan, it
read both partitions and booted Linux using
`sysboot mmc 0:2 any 0x80c00000 /boot/extlinux/extlinux.conf`.
The default boot command now performs the rescan and direct boot.
This is a workaround; the original intermittent read failure is not yet
fully explained, and a replacement 32 GB card is being tried.

Linux reached the NixOS initrd but failed to expose the root block device.
The original audit missed `CONFIG_MMC_BLOCK=m`: the controller was built
in, but `mmc_block` had not been included in the initrd. The corrected
image includes and loads that module, reusing the existing kernel. Its
build and actual archive-content check passed. Full NixOS startup and
networking still need to be verified on hardware.

The corrected image was written and flushed to the replacement 32 GB
card. Readback verification was skipped at the user's request.

## Memory reduction after physical boot

The 32 GB card successfully booted through root mounting and NixOS stage 2.
UART and USB serial login services started; the USB gadget enumerated on the
host. Repeated OOM kills prevented a usable login. No memory measurements
were available, so the precise runtime allocation problem remains unconfirmed.

The revised image uses NixOS's minimal profile, a reduced board module tree,
no NSS cache or systemd OOM daemon, and an 8 MiB volatile journal limit. It
preformats a 512 MiB SD swap file during image construction, avoiding a
first-boot allocation before root expansion. LZ4 zram retains higher swap
priority. The Nix registration service waits for swap.target.

## Physical tests still required

1. Confirm a usable root login over UART or USB serial, then change the
   initial `nixos` password.
2. Inspect memory and swap with `free -m` and `swapon --show`; confirm
   both zram and the SD swap file are active.
3. Confirm Ethernet interface, carrier, and a DHCP lease using `ip -br link`
   and `ip -br addr`, then test SSH from the workstation. If needed inspect
   `dmesg | grep -Ei 'stmmac|dwmac|mdio|phy'`.
4. Confirm root expansion with `df -h /` and sustained operation without OOM.

Wi-Fi, camera/ISP, display, TPU, and the secondary-core RTOS remain outside
this image's configured support. Header UART/I2C/SPI functions need appropriate
pinmux configuration. GPIO pins, suspend, and reboot/poweroff remain untested.

The first minimal-image boot exposed two additional packaging problems:
`mkfs.ext4 -d` made the zero-filled swap file sparse (512 MiB logical size,
only 4 KiB allocated), and the reduced module closure omitted dynamically
requested USB serial function and compression drivers. The corrected build
uses nonzero swap contents before formatting and includes `usb_f_acm`,
`usb_f_serial`, `u_serial`, `lz4`, `lzo`, and `lzo-rle`. Its board checks pass,
and inspection of the actual ext4 image confirms the swap file has its full
512 MiB allocated. Runtime activation remains to be tested after flashing.


## Board-specific kernel

The corrected minimal image reached a usable root shell, activated both
swaps, and the user confirmed Ethernet works. `free` reported 183800 KiB
total RAM, 30000 KiB available, and 24024 KiB of swap in use. Login remained
slow; the exact cause has not been measured.

The new kernel uses Sipeed's public Nano vendor config as a hardware reference:
https://github.com/sipeed/LicheeRV-Nano-Build/blob/main/build/boards/sg200x/sg2002_licheervnano_sd/linux/sg2002_licheervnano_sd_defconfig

It remains mainline 7.0.12, configured from allnoconfig with explicit NixOS
and board requirements and strict configuration checking. It disables SMP,
PCI, graphics, audio, Wi-Fi, tracing, virtualization, and memory-allocation
profiling. It retains the C906 errata, noncoherent DMA, SD controller and
block module, UART, USB serial, Ethernet/MDIO, nftables firewall, and swap.
Its Image is 5809680 bytes, down from 46991872. The kernel and SD image
build successfully, the generated-config and board checks pass, and actual
ext4-image inspection confirms 512 MiB of allocated swap-file blocks.

The optional userspace service removals discussed with the user have not
been applied. Measure boot/login time and `free -m` after testing the new
kernel to assess its actual runtime improvement.

The small kernel booted to a usable UART root shell. `free -m` reported
245 MiB total RAM and 126 MiB available, with zero swap used; both SD swap
and zram were active. Root expansion exposed a missing requirement:
`BLK_DEV_WRITE_MOUNTED`. The partition table grew successfully, but
`resize2fs` could not open the mounted root partition (EBUSY). Enable that
kernel setting and check the generated config so NixOS can grow ext4 online.

The user authorized removing login session management. The configuration now
disables logind, lingering-user management, and the user@ service template.
PAM login, SSH, and systemd-user hooks do not invoke pam_systemd. The separate
systemd-user-sessions boot service remains to permit logins by removing
/run/nologin. Board checks verify these units and PAM files, alongside the
BLK_DEV_WRITE_MOUNTED correction. Runtime validation of this combined image
is pending.


## Dropbear experiment

The user authorized replacing the OpenSSH server with Dropbear. The custom
service listens on TCP 22, disables password authentication, installs the
approved root public key with mode 0600, and generates one persistent
Ed25519 host key. Serial authentication remains unchanged. The configured
PATH gives SSH shells access to NixOS commands. SFTP is not provided.
Build checks verify Dropbear is enabled and sshd is not; runtime login and
memory comparisons remain to be measured on the board.


Dropbear's first boot failed because the SSH-shell PATH overrode the service
PATH and preStart invoked dropbearkey by name. UART diagnostics confirmed
exit 127. Generating the host key with its absolute store path repaired the
running service; the image now also uses absolute executable paths and its
board check inspects the generated preStart script.

Public-key SSH to the board succeeded after verifying the
host key against UART output. Idle Dropbear RSS was about 1944 KiB versus
OpenSSH's earlier 6880 KiB (RSS includes shared pages). The board reported
133 MiB available, zero swap use, and a successfully expanded 29 GiB root
filesystem with 26 GiB free. The persistent host key makes the live repair
survive reboot.

## MIPI DSI integration investigation

The requested display interface is the Nano's two-lane MIPI DSI output
(31-pin connector); the separate six-pin connector is for capacitive touch.
The panel model, timings, initialization sequence, and adapter wiring are
still needed. Connector specifications alone do not identify the panel.

The Linux 7.0.12 source used here has no CV1800/SG2002 display-controller
driver or display nodes in cv180x.dtsi/cv181x.dtsi. Enabling DRM or a generic
ST7701 panel driver therefore does not provide a working DSI output.
The current kernel also deliberately disables DRM, INPUT, and VT.

Sipeed's vendor source uses soph_mipi_tx, soph_vo, and soph_fb modules in
osdrv/interdrv/v2. Their Makefiles reference base, vpss, and sys module
symbols and vendor headers; these are not drop-in modules for our kernel.
Integration must resolve those dependencies and the device-tree/clock/DMA
interfaces, or use a compatible vendor kernel with NixOS. No display
support has been enabled or tested yet.

References:
- https://wiki.sipeed.com/hardware/en/lichee/RV_Nano/5_peripheral.html
- https://wiki.sipeed.com/hardware/zh/lichee/RV_Nano/6_develop_mainline.html
- https://github.com/sipeed/LicheeRV-Nano-Build/tree/main/osdrv/interdrv/v2/vo
- https://github.com/sipeed/LicheeRV-Nano-Build/tree/main/osdrv/interdrv/v2/fb

## Lean DOSBox cross-build

DOSBox 0.74-3 built successfully on x86_64 for riscv64-linux, using slim
SDL 3 / SDL 2 / SDL 1.2 compatibility libraries with software X11 output.
OpenGL, hardware audio backends, SDL_sound codecs, and GraphicsMagick
icon conversion are omitted. The flake exposes the package as `dosbox`.

The executable package occupies about 2.6 MiB on disk. Its full NAR closure
is about 91 MiB including shared system libraries; only 14 missing paths,
about 10.5 MiB of NAR data, were transferred to the running Nano.
It was installed into root's existing profile without rebooting.

The board reported version 0.74-3 and passed scripts/dosbox-smoke.sh:
a real 16-bit x86 COM program executed DOS INT 21h and produced the expected
DOSBOX_X86_OK marker. SDL dummy drivers make this a headless emulation
check. GUI output, audio, game compatibility, and speed remain untested.

## Experimental mainline display port

The SDK confirms two-lane 800x1280 at 60 Hz: zct2133v1 uses 85352 kHz
pixel clock (approximately 1.024 Gbps per data lane for RGB888). Its
physical mapping is TX0=data0, TX1=clock, TX2=data1. Waveshare's ILI9881C
implementation selects command page 1 then writes B7=03 for two lanes;
the previously discussed register 00 is not its lane-control write.

A standalone vendor-derived module now builds against Linux 7.0.12. It
includes MIPI TX, DPHY/scaler/VIP register code, and a new single-buffer
RGB888 fbdev implementation, with Linux 7 GPIO/procfs/platform APIs.
The opt-in NixOS module packages the driver in the trimmed module closure,
adds vendor display resources and GPIOE reset/backlight mapping, and selects
an experimental fbdev kernel with 8 MiB CMA. Build checks inspect the
compiled display DT, kernel helpers, module ABI and trimmed closure.

This is compile/integration validation only. No driver was loaded or
screen tested on the running board. Exact LCKFB panel initialization and
timings are pending; pinmux, wiring, scanout and touch remain unverified.
The working/default SD image still has display disabled.

Fastfetch 2.64.2 was cross-built with desktop/media detection disabled,
transferred and installed live. Its command runs and identifies the SG2002.
It replaces Neofetch in root's profile and in the flake package outputs.

## Current display candidate

The experimental image now builds with Waveshare initialization adapted to
two lanes and LCKFB's documented 66 MHz mode. Display hardware and touch remain
untested. A pinned CanMV alternative and register comparison are saved in
`display/CANMV-COMPARISON.md`. Personal SSH keys are not included in the public
configuration; add an authorized public key to enable SSH.

## Publication review fixes

The credential-free configuration builds and uses serial login; Dropbear is
conditional on authorized keys. The known provisioning password is stored as
a hash and still must be changed on first boot. USB serial can be disabled
without autoloading g_serial; only the PC keyboard autoload is overridden,
so downstream module additions survive. The exported module supplies fiptool.
Images are included in checks; formatter and revision outputs are configured.
Build platforms are x86_64 and aarch64 Linux (target remains RISC-V).
Requested htop, bat, lsd, vis, Fastfetch and DOSBox packages are in the system
profile. Firmware metadata conservatively identifies the vendor binary as
unfree pending clarification of redistribution terms.

Post-review validation: all-system evaluation passes for both supported build
hosts. The x86_64-host `nix flake check` builds both SD images and passes
board content, display integration and option/consumer checks. Formatting
passes for all 16 Nix files. Independent read-only re-review returned
ACCEPTABLE with no verified findings. These are build checks; the revised
images have not yet been booted on hardware.

A second review found that negated grep commands were exempt from Bash's
`set -e`. Both negative content checks now explicitly exit on unwanted
matches; clean and failing fixtures verified their behavior. Module policy
settings now use overridable defaults, the redundant OpenSSH setting was
removed, and `nixosModules.default` aliases the board module. Downstream
firmware allowance and session-management requirements are documented.
Both independent reviews returned ACCEPTABLE after these fixes. All-system
evaluation, formatting and the full current-host build checks passed again;
the corrected board content check rebuilt against the validated images.
