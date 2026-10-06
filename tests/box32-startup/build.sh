#!/usr/bin/env bash
set -euo pipefail
src=$(cd -- "$(dirname -- "$0")" && pwd)
out=${1:?usage: build.sh OUTPUT_FILE}
"${CC:-cc}" -m32 -nostdlib -static -Wl,--build-id=none -o "$out" "$src/probe.S"
