#!/usr/bin/env bash
set -euo pipefail
src=$(cd -- "$(dirname -- "$0")" && pwd)
out=${1:?usage: build.sh OUTPUT_FILE}
"${CC:-cc}" -m32 -nostdlib -static -Wl,--build-id=none -o "$out" "$src/probe.S"
"${CC:-cc}" -m32 -nostdlib -static -DBLOCK_NESTED -Wl,--build-id=none -o "$out-no-nesting" "$src/probe.S"
"${CC:-cc}" -m32 -nostdlib -static -DOMIT_RESTORER_POP -Wl,--build-id=none -o "$out-bad-restorer" "$src/probe.S"
