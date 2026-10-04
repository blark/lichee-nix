#!/usr/bin/env bash
set -eu
work=$(mktemp -d /tmp/dosbox-smoke.XXXXXX)
cat > "$work/dosbox.conf" <<'CONF'
[sdl]
output=surface
[cpu]
core=normal
cycles=1000
[mixer]
nosound=true
[midi]
mididevice=none
[sblaster]
sbtype=none
[gus]
gus=false
[speaker]
pcspeaker=false
tandy=off
disney=false
CONF
# A real 16-bit x86 DOS program: print a string via INT 21h, then exit.
printf '\272\014\001\264\011\315\041\270\000\114\315\041DOSBOX_X86_OK\015\012$' > "$work/check.com"
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout 30s dosbox \
  -conf "$work/dosbox.conf" \
  -c "mount c $work" -c 'c:' -c 'check.com > cpu.txt' -c exit \
  > "$work/run.log" 2>&1 || { cat "$work/run.log"; exit 1; }
cat "$work/run.log"
cat "$work/CPU.TXT"
test "$(tr -d '\r\n' < "$work/CPU.TXT")" = DOSBOX_X86_OK
printf 'PASS: executed 16-bit x86 DOS program on the Nano\n'
