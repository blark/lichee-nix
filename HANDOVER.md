# Box32 development handover

Build on a supported Linux host; the package is cross-built for RISC-V:

```sh
nix build .#box64 --out-link result-box64 --no-write-lock-file \
  --option allow-import-from-derivation false -L --max-jobs 4 --cores 8 \
  --option substituters https://cache.nixos.org
```

Copy the result to your board without changing its installed profile:

```sh
# Set NIX_SSHOPTS to your SSH identity and verified known-hosts options.
nix copy --no-check-sigs --to "ssh://root@$BOARD_ADDRESS" \
  "$(readlink -f result-box64)"
```

Run target binaries by their copied store path. Do not evaluate/build the
legacy-userland launcher flake on the board. A translated chroot test needs
its prepared rootfs, the copied translator path, an existing X display and
windowed argument W. The launcher clears environment variables, so selecting
fully emulated libraries requires the guarded temporary guest RC described
in the local operational notes.

The tested work is committed: ELF32 version definitions, first weak-provider
selection, guest brk and selected startup/select syscalls. Static regression
sources are in tests/. [AUDIT.md](AUDIT.md) records before/after evidence and
the precise unfinished signal-frame design. The game has not rendered.

Real board addresses, SSH identity path, host pin, rootfs paths and exact
controller commands are retained locally in the durable handover notes,
separate from this public repository. No private-key contents are copied.
The person taking over has the local notes location.

Next: raw174/175/179 and genuine sigreturn119, including RT32–34 delivery to
separate PIDs. Do not hide missing RT calls by implementing legacy fallback72.
Box32 accepted the old LinuxThreads clone flags, but healthy timer signalling
is unproven. IPC117 SHMAT21/SHMGET23 is the subsequent measured X11 surface.
Upstream issues/PRs remain unfiled; their reproducers must contain only clean,
synthetic sources and reproducible before/after measurements.
