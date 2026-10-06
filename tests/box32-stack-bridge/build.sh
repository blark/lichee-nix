#!/usr/bin/env bash
set -euo pipefail
src=$(cd -- "$(dirname -- "$0")" && pwd)
out=${1:?usage: build.sh OUTPUT_DIRECTORY}
mkdir -p "$out"
"${CC:-cc}" -m32 -nostdlib -shared -fPIC -Wl,--build-id=none -o "$out/libanswer.so" "$src/answer.S"
"${CC:-cc}" -m32 -nostdlib -no-pie -Wl,--build-id=none -Wl,-z,lazy '-Wl,-rpath,$ORIGIN' -L"$out" -o "$out/probe" "$src/probe.S" -lanswer
