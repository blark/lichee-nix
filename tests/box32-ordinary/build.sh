#!/usr/bin/env bash
set -euo pipefail
src=$(cd -- "$(dirname -- "$0")" && pwd)
"${CC:-cc}" -m32 -nostdlib -static -fno-pie -fno-stack-protector -fno-builtin -O2 -Wl,--build-id=none -o "${1:?usage: build.sh OUTPUT_FILE}" "$src/probe.c"
