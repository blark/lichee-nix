# Board image audit

This is a chronological record. The latest checkpoint at the end supersedes
earlier blockers. HANDOVER.md contains sanitized instructions. Exact local
deployment commands and SSH host pins are kept outside this public repository.

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

## Box64 and headless X11 tools

Box64 0.4.4 was cross-compiled with BOX32 and RISC-V dynarec enabled and
installed live through the root Nix profile. Two small static ELF tests and
upstream `tests/test01`, `tests/test02`, `tests32/test01` and `tests32/test02`
all passed on the Nano with dynarec enabled. These cover 32-bit and 64-bit
execution, native libc startup and syscall wrapping; they do not establish
compatibility with arbitrary applications or Wine.

The initial SAVE_MEM build crashed when dynamically linked programs entered
native libc. Both Box64 0.4.2 and 0.4.4 define `JMPTABL_SHIFT4` for that option,
but the RV64 helper tests the misspelled `JMPTABLE_SHIFT4` and its indirect
lookup omits the additional level. The resulting jump entered table data.
SAVE_MEM is explicitly disabled in the installed and image packages.

Xorg server (including Xvfb), x11vnc, strace and xdpyinfo were also cross-built
and installed live. A temporary Xvfb instance exposed an 800×1280, 24-bit
display; xdpyinfo read its dimensions and x11vnc attached and answered a
remote-control ping. The VNC test listened only on loopback. Both test servers
were stopped afterward. strace successfully traced a small command.
All tools are included in the image configuration; no desktop or VNC service
is automatically started. Existing installed tools remained available.

Git 2.54.0 uses the minimal package, retaining HTTPS transport while omitting
manuals and optional Perl/Python helpers. It was cross-built and installed
live; local init/add/commit/log operations and an HTTPS query of the public
repository passed on the Nano. The board configuration check also passed
with Git included in the system profile.

## Ruby chroot experiments

The Ruby chroot launcher was cross-built on the build host and copied with a
prepared, patched rootfs to the Nano; the board evaluated no flakes. OverlayFS
was built against the running kernel's exact headers and loaded live. Future
images enable the module, retain it in the trimmed module closure, and check
for its presence. The updated board configuration build check passed.

Box64's 32-bit port-permission wrappers now return ENOSYS, matching its existing
64-bit unsupported behavior. Native graphics libraries are retained in its
RPATH so wrapped X11 and FreeType libraries can be found inside the chroot.
The six ELF smoke tests passed again with these changes. Ruby then reached a
legacy libio ABI mismatch: its old libstdc++ requires `_IO_init@GLIBC_2.0`,
which the wrapped modern host libc does not supply.

QEMU 11.0.1 was separately cross-built for i386 user mode and installed live;
it is not included in the image's program list. The old guest shell and X11
socket visibility check passed. The game failed Allegro initialization when
QEMU rejected LinuxThreads' `clone(CLONE_VM|CLONE_FS|CLONE_FILES|CLONE_SIGHAND)`
with EINVAL. No game rendering or useful performance measurement was reached.

Moving pristine library backups outside the guest search path did not change
Box32's fully emulated loader crash. The old guest shell reproduced it without
loading Merit libraries. A core backtrace identified a null version name in
`SymbolMatch` during relocation of the guest loader. Its ELF has version
definitions without a version-needs table; Box32 0.4.4 returned NULL before
consulting those definitions. The included patch uses the existing definition
lookup for this case. A focused test of the actual lookup functions fails with
the original code and passes with the patch, including existing needs-table
behavior and absent versions. The cross-built patch fixed that loader crash
on the board and the six established ELF smoke tests passed again.

Full guest-library emulation still fails. The old shell reaches execution but
Box32 returns ENOSYS for i386 brk and old sigprocmask. The game reaches its
entry point with emulated libc, libstdc++ and X11, but encounters unsupported
getpid, uname, signal, sysctl and time calls. The trace records malloc binding
to the guest loader's minimal allocator and a dl-minimal.c allocator assertion;
the underlying cause remains unresolved. Box32 reports guest EAX=127 but
subsequently suppresses a shutdown fault and exits zero, so that exit status
does not establish success. No game rendering was observed under either
translator.

A subsequent native startup/menu/attract trace establishes that brk is on the
game's normal path. Its normal signals use rt_sigaction, rt_sigprocmask and
rt_sigsuspend plus legacy sigreturn. Legacy sigaction/sigprocmask warnings in
the translated game occur after a failed rt_sigaction; they do not establish
requirements for the successful native path. The native trace also returns
an error from _sysctl, and the stubbed game's ioperm/iopl may fail harmlessly.

A native control runs successfully despite two zero-length, read-only mmap
calls on empty XFree86 font alias files returning EINVAL. That return value
alone is expected Linux behavior and is not a Box32 defect finding. The board
capture instead records five zero-length anonymous read/write mappings with
fd=-1, so the native font-file calls do not establish that these are the same
sequence. No mmap implementation patch has been made or justified.

Memory samples around the board's first such call show 110–113 MiB available
RAM and 614 MiB free swap. Kernel logs before and after that run are identical,
with no new OOM report. These observations do not identify the allocator
assertion's cause; a matching native allocator/binding control is still needed.

## Ruby investigation handoff: current state

The game still does not render on the Nano. Its launcher and patched rootfs
are installed live; QEMU i386 user mode and Box64 0.4.4 with BOX32 are available.
The installed Box64 includes the reviewed ELF32 version-definition fallback
fix. A separate diagnostic build adds logging only; it has not replaced the
installed profile or been added to the image. No mmap or auxv fix is pending.

Completed measurements and eliminations:

- Moving pristine libraries outside the search path did not fix the loader
  crash. A definitions-only ELF version lookup was the actual null-name cause;
  the patch fixes that crash and all six existing ELF smoke tests pass.
- Fully emulated runs explicitly load the guest libc, pthread, libstdc++ and
  ld-linux; wrapped modern libc's legacy libio ABI mismatch belongs to the
  separate wrapped-library experiment.
- A static i386 fixture passes natively and under the installed Box32 for
  old_mmap lengths 1, 4095, 4096 and 8192, and mmap2 length 4096. Host strace
  preserves every length exactly. A requested zero correctly returns EINVAL.
  This eliminates a general page-count/byte-count conversion error.
- Diagnostic entry logging confirms the game's old_mmap argument structure
  already contains len=0, prot=3, flags=0x22, fd=-1. my32_mmap64 and my_mmap64
  both receive zero. The conversion layers did not turn 4096 into zero.
- Native font-alias EINVALs are handled, read-only file-backed mappings;
  they are distinct from the board's anonymous writable requests. The native
  control has 326 anonymous mappings, none failing and none zero-length.
- The static i386 initial-stack auxv dump contains AT_PAGESZ=4096,
  AT_HWCAP=0x0681811f, AT_PHDR=0x6dfd55b0 and AT_PHNUM=6 (the fixture's header
  count). AT_CLKTCK and AT_BASE are absent. The pinned box32stack.c explicitly
  emits AT_PAGESZ, but its AT_CLKTCK and AT_BASE statements are commented out.
  Static-fixture observations do not establish dynamic-interpreter behavior.
  Missing AT_PAGESZ is eliminated; consumption into guest _dl_pagesize is
  a different question and has not been measured.
- Source inspection guards ELF32 BSS-tail handling; the recorded zero mmap
  occurs while executing a guest syscall, rather than host ELF-tail mapping.
- Memory sampling brackets the first failure with 110–113 MiB available RAM
  and 614 MiB free swap. Before/after kernel logs are identical, no new OOM.
- Native syscall inventory establishes brk as required, rt signal operations
  plus legacy sigreturn119 as used, and harmless error returns for ioperm/iopl
  on the patched tree. _sysctl errors also occur natively. Raw Box32 warnings
  are preserved by number; legacy signal fallbacks in failing startup are not
  assumed necessary on the successful native path.
- QEMU's measured blocker remains LinuxThreads clone flags without
  CLONE_THREAD, rejected with EINVAL before Allegro rendering.

The fully emulated game trace records this binding during a libwvstreams
constructor: old libstdc++ __builtin_new -> malloc@GLIBC_2.0 at guest address
0x404f2b30 in /lib/ld-linux.so.2 (mapped base 0x404e2000, offset 0x10b30).
That loader's __mmap executes int80 at offset 0x1355b; the syscall log reports
the following instruction at 0x404f555d. Guest write(2) calls assemble:

```text
BUG IN DYNAMIC LINKER ld.so: dl-minimal.c: 83: malloc: Assertion `page != ((void *) -1)' failed!
```

This is an observed guest-loader code path even though Box32 performs ELF
loading itself. Its cause remains unresolved. Current candidates are guest
loader initialization and allocator symbol binding; neither is established
as the root cause. AT_PAGESZ presence alone does not verify that _dl_sysdep_start
ran or initialized the loader's BSS _dl_pagesize at offset 0x18460.

Exact next measurement: capture the guest return address/frame chain at the
zero-length old_mmap call, and read the relocated _dl_pagesize value. Compare
the native old libstdc++ constructor's malloc binding with the translated
binding. Do not patch mmap, force a nonzero length, or add auxv entries based
only on the current assertion.

Retained local diagnostic artifacts (not game files in this repository):
native references ruby-native-syscalls.txt and mmap-fd-trace.txt; extracted
board evidence in /tmp/nano-box32-memory-test/ and
/tmp/nano-box32-mmap-boundary/; exact syscall report
/tmp/nano-box32-syscall-report.md; auxv dumps /tmp/nano-box32-auxv.bin and
/tmp/nano-box32-auxv-native.bin; static fixture sources
/tmp/nano-box32-mmap-fixture.S and /tmp/nano-box32-auxv-fixture.S; diagnostic
patch/build script /tmp/nano-box32-mmap-trace.patch and
/tmp/nano-box32-mmap-trace-build.sh. The diagnostic build output is linked at
/tmp/nano-box32-mmap-trace-result. Native references remain on the build host;
board copies of the captures remain under the live deployment's directory.

### Update: weak-provider overwrite confirmed and corrected

The allocator assertion above is now explained by symbol lookup. The old
loader and libc both export weak malloc@@GLIBC_2.0. Box32's weak scan did not
stop at a matching provider: later matches overwrote earlier results. The
included box64-elf32-weak-order.patch preserves the first weak match in the
ordinary, weak-reference and NoSelf lookup helpers. Their existing strong
passes still complete first. This deliberately narrows the correction to
32-bit execution to avoid changing the established 64-bit path; it is not a
claim to have corrected or validated all 64-bit weak-symbol semantics.

A separate logging-only build enumerated the actual maplib->libraries array
at malloc lookup. libc.so.6 is entry 15 and ld-linux.so.2 is entry 16, including
when the scope later grows to 30 libraries. This is measured order, rather
than an inference from the wrong binding. The same diagnostic reads the
loader's _dl_pagesize at 0x404fa460 (offset 0x18460) as zero. An auxv entry of
4096 therefore did not establish that this guest loader's BSS was initialized.
No page-size initialization or mmap behavior change was applied.

The production patch build resolves the old libstdc++ constructor's malloc to
0x404374e0 in libc.so.6, whose base is 0x403c0000: offset 0x774e0, the real
allocator. It no longer resolves malloc to the loader's offset 0x10b30 and the
dl-minimal.c assertion is absent. The logging variant independently reproduces
the corrected binding while _dl_pagesize remains zero.

Discriminating regression checks:

- The saved tests/box32-weak-order fixture contains two shared objects with
  weak foo@@FOO_1.0. Both dependency orders fail with exit 1 under the original
  installed build, which selects the second provider; both pass with exit 0
  under the patched build, which selects the first. A weak undefined-reference
  variant also fails originally and passes patched, exercising the separate
  weak lookup helper. These are real ELF objects, not replacement lookup code.
- An independent native i386 probe supplied by the user prints 1 for libraries
  a,b and 2 for b,a. The original Box32 prints 2 and 1; the patched Box32 prints
  1 and 2. This supplies an independent versionless native reference.
- All six existing ELF32/ELF64 smoke tests pass with the production patch.
- Independent Nix review, both supported cross-host package evaluations,
  formatting, patch applicability and Bash syntax checks pass. Lock unchanged.

The saved fixture does not cover RTLD_NEXT/NoSelf at runtime, strong-versus-weak
precedence, or arbitrary dependency graphs that place an interpreter earlier
in the scope. The patch changes neither array order nor loader classification.
No universal loader-last guarantee is claimed.

Next blocker, now observed in the real libc allocator: guest __brk issues
raw i386 syscall 45 with brk(0), then requests 0xa and 0xfd0. Box32 returns
ENOSYS. The run exits 139 at libc chunk_alloc + 0x611, guest PC 0x40437d41,
accessing 0xffffffe4. This is distinct from the resolved loader assertion.
No brk implementation has yet been added and no game rendering was reached.
The exact next work is to implement/test Linux i386 brk semantics in Box32
with a guest fixture before retrying Ruby, including brk(0), growth/shrink and
failure returning the current break rather than a negated errno.

Production patch artifact: /tmp/nano-box32-weak-order-result. Scope diagnostic:
/tmp/nano-box32-weak-order-log-result. Both were built on the cross-build host
and copied to the board; the existing installed profile was not replaced by
these tests. Logs retained in /tmp/box32-weak-order/ and
/tmp/box32-weak-order-scope/ on the host, with board copies retained too.
The temporary rootfs RC was removed; no guest game process remains from these
bounded runs. No commit or push was performed.

### Live progress: guest brk and startup syscalls

A guest brk implementation was cross-built and tested live, separate from
host libc's process break. It starts after the main ELF reservation, maps
contiguous pages without replacement, unmaps whole pages on shrink, and
returns the current break on rejected requests. Its native-passing static
int80 fixture fails with the original Box32's ENOSYS and passes on the board
with the patch: repeated query, writable growth, byte-accurate shrink,
zero-filled regrowth, invalid addresses, and collision-marker preservation.
The reviewed correction includes Linux-style initialized-data accounting
for RLIMIT_DATA and defers ordinary asynchronous signal reentry during heap
updates. The reviewed brk build also passes all six existing ELF smoke tests.
Limit/concurrency stress beyond those fixtures remains unverified.

The game advanced beyond malloc to Allegro; raw uname122 returning ENOSYS
was followed by strtol(NULL) and SIGSEGV. A startup patch adds getpid20,
uname122, time13, ugetrlimit191 and setrlimit75, converting 32-bit limits and
checking tracked guest-page permissions. Failed queries leave output intact.
A static fixture passes natively and under the first board build, including
invalid pointers, unaligned output and guard markers. A subsequent memcpy
alignment correction is under cross-build; converters explicitly retain a
concurrent-unmap limitation and are not claimed fully race-free.

With these calls served, the game run reaches LinuxThreads manager creation
and times out in raw getppid64/_newselect142 calls. This was game exit124,
not successful clean shutdown. Fixture shutdown messages are distinct from
the game. All runs passed W; logged argv[1] confirms the windowed argument.
No game rendering is yet established. Trying wrapped pthread while retaining
emulated libc failed at an internal pthread-mutex-attribute call; that
experiment was reverted by removing its temporary RC.

The next source change implements register-argument _newselect142 with
32-bit bitmap lengths and timeval conversion, and getppid64. pipe42 is already
served and the request pipe is observed in the manager loop. This change is
not yet built or validated. Further measured native calls, notably legacy
signal return and rt signal operations, may still be missing. The updated
native inventory covers 55 calls observed across startup/menu/random pointer
interaction, not a proven complete play-through. Its count and clone/thread
interpretations are retained as reference evidence, not guarantees.

Opportunistic game-free x86_64 weak probes all select the second provider,
including both dependency orders and versioned/unversioned cases. Thus the
weak overwrite defect is not confined to Box32. The current bitness gate is
still a deliberate temporary narrowing; an upstream-quality fix must test
and correct both modes. Public reports, duplicate checks, synthetic
version-definition runtime reproduction and current-main verification remain
pending. No issue, PR or other publication is authorized now.

Artifacts: /tmp/nano-box32-brk-result (first experimental heap),
/tmp/nano-box32-brk-v2-result (reviewed heap),
/tmp/nano-box32-startup-result (first startup patch), and
/tmp/nano-box32-startup-v2-result (alignment build, check status before use).
Board captures are box32-brk-first, box32-startup-first and
box32-wrapped-pthread-test under the live deployment. First brk capture was
retrieved to /tmp/box32-brk-first/. Source fixtures are saved in
tests/box32-brk and tests/box32-startup. Profile installation is unchanged;
these builds are tested by explicit store path only. No commit or push.

### Compact handoff: current work

- Fixed and board-tested: weak lookup now binds malloc to guest libc; real
  two-provider fixtures fail before/pass after. Guest brk passes query,
  growth, shrink, zero-filled regrowth and mapping-collision tests on native
  Linux and the board; the reviewed heap build passes six ELF smoke tests.
- Startup support for getpid20, uname122, time13, ugetrlimit191/setrlimit75
  passes native and board fixtures. Alignment-corrected build is now complete
  at /tmp/nano-box32-startup-v2-result but not yet tested on the board.
- Route: fully emulated guest libc AND pthread, preserving the old userland.
  Wrapped pthread experiment failed at __pthread_mutexattr_init and was
  abandoned; its temporary RC was removed. W is confirmed in logged argv[1].
- Latest game run timed out, exit124, in LinuxThreads manager calls to missing
  getppid64 and _newselect142. pipe42 is already working. Source now serves
  64/142, with real select and 32-bit fdset/timeval conversion. Review passed;
  /tmp/nano-box32-select-fixture passes natively; its select-only variant fails
  at syscall142 on the previous board build. Cross-build completed successfully:
  /tmp/nano-box32-select-result, store basename
  ynpbck7hvq0132vj5vb60ni2xwga5z25-box64-riscv64-unknown-linux-gnu-0.4.4.
- Exact next measurement: copy that build, run brk/startup/select fixtures,
  then run the game with host strace capturing clone, failed writes and X
  connections. Record each clone's flags/return/PID, not an inferred thread
  count, and inspect EBADF writes for fatal text. LinuxThreads clone without
  CLONE_THREAD is a known QEMU blocker; Box32's outcome must be measured.
- Native signal reference, corrected by the measuring agent: in the 60s run,
  kill/sigreturn/rt_sigsuspend each count147, rt_sigprocmask159, rt_sigaction12,
  clone3, pipe1, getppid31, poll31, nanosleep244, _newselect16216. Earlier
  _newselect7304/getppid14 counts belong to the 25s run. LinuxThreads uses
  kill(pid, sig), with reserved RT signals32–34, between separate processes
  sharing memory without CLONE_THREAD. Measure delivery to the intended PID;
  the triplet is a native conformance reference, with incomplete cycles at a
  bounded trace boundary considered before diagnosing count differences.
- Existing profile unchanged; tested artifacts invoked explicitly. No game
  rendering established. No commit, issue, PR or publication performed.

### Latest board measurement: select and LinuxThreads clone

The select build named above passes all four brk/startup/select probes on the
board, including the select-only before/after control. In the 40s game trace,
PID22996 calls clone(CLONE_VM|CLONE_FS|CLONE_FILES|CLONE_SIGHAND), without
CLONE_THREAD, and receives PID22999. Thus Box32 accepts the exact clone shape
that QEMU rejected, using emulated guest LinuxThreads, though a healthy timer
thread and its signalling are not established. The run times out124, makes
no X connection and has no recovered fatal EBADF write; child22999 logs
SIGABRT. Missing rt_sigaction174 is followed by legacy signal fallback
warnings (67/126/72), with72 repeated. Do not implement72 to mask this:
native controls use174/175/179 and legacy sigreturn119. Next: implement/test
these RT paths and genuine guest-handler return, including32–34 to separate
PIDs; then capture actual delivery and clone outcomes. Host captures and all
four PASS logs are saved in /tmp/box32-select-test/.

### Signal handover: design only, no patch yet

Raw i386174/175/179/119 remain unimplemented. The existing signal32.c invokes
the guest handler through EmuCall/DynaCall, restores registers, then invokes
the restorer separately. That call lacks a genuine i386 kernel signal frame;
forwarding native sigreturn or stubbing119 would conceal the mismatch.
Use fixed-width action fields (handler/flags/restorer plus two u32 mask words,
20 bytes total) and eight-byte RT masks. Existing native-unsigned-long i386
mask types and oversized extramask are unsuitable. Linux's legacy frame has
return address, signal, sigcontext_32, legacy FP area, one extra mask word and
trampoline. Syscall119 finds it at ESP-8; RT173 uses ESP-4. Return must restore
registers, flags, segments, FP state and mask, then leave nested handler
execution without stale C-side register restoration or a second restorer.
These offsets/layouts were checked against upstream Linux
[signal_32.c](https://github.com/torvalds/linux/blob/master/arch/x86/kernel/signal_32.c)
and [sigframe.h](https://github.com/torvalds/linux/blob/master/arch/x86/include/asm/sigframe.h).

Guest RT32–34 require consistent installation, mask, delivery and returned
signal-number translation to available native RT signals, preserving native
glibc's reserved32/33. The exact mapping and raw-path integration are not yet
implemented or tested. First fixture targets: separate-PID kill delivery,
blocked/pending signals, atomic suspend/EINTR, nested handlers and restored
registers/masks. Count completed park/unpark cycles against the native signal
triplet, accounting for trace boundaries. IPC117 subcommands21/23 (SHMAT/
SHMGET) are the next measured X11 shared-memory surface; not implemented yet.

Cross-build from the repository on a supported Linux build host:

```sh
nix build .#box64 --out-link result-box64 --no-write-lock-file \
  --option allow-import-from-derivation false -L --max-jobs 4 --cores 8 \
  --option substituters https://cache.nixos.org
```

Do not build/evaluate the game launcher on the board. The operational
handover supplies the exact SSH, store-copy and fully-emulated W launch
commands, current artifact and rootfs paths, alongside a durable host pin.

Synthetic version-definition runtime control now verified on the board:
unpatched build returns244 for both good/bad cases (unresolved ver_fn);
patched build returns0/255 respectively and the check passes. The fixture
uses a no-libc ELF32 DSO with VERDEF and no VERNEED. Box32 runs must select
the good/bad libraries from distinct working directories with relative
executable paths; the initial shared-cwd absolute-path check loaded the good
DSO twice and was rejected. No upstream report has been filed.
