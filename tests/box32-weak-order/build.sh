#!/usr/bin/env bash
# Build i386 fixtures without libc or libgcc; native host cc needs -m32 support.
set -euo pipefail
src=$(cd -- "$(dirname -- "$0")" && pwd)
out=${1:?usage: build.sh OUTPUT_DIRECTORY}
mkdir -p -- "$out"
out=$(cd -- "$out" && pwd)
cc=${CC:-cc}
for name in first second; do
  "$cc" -m32 -nostdlib -shared -Wl,--build-id=none \
    -Wl,--version-script="$src/version.map" -Wl,-soname,lib$name.so \
    -o "$out/lib$name.so" "$src/$name.S"
done
for order in first reverse; do
  expected=11
  libs=(-lfirst -lsecond)
  if [ "$order" = reverse ]; then
    expected=22
    libs=(-lsecond -lfirst)
  fi
  "$cc" -m32 -nostdlib -no-pie -DEXPECTED="$expected" \
    -Wl,--build-id=none -Wl,--dynamic-linker,/lib/ld-linux.so.2 \
    -Wl,--no-as-needed -Wl,-rpath,'$ORIGIN' -L"$out" \
    -o "$out/$order-wins" "$src/start.S" "${libs[@]}"
done
# A weak undefined reference exercises the separate weak-resolution helper.
sed 's/call foo@PLT/.weak foo\n call foo@PLT/' "$src/start.S" > "$out/weak-start.S"
"$cc" -m32 -nostdlib -no-pie -DEXPECTED=11 \
  -Wl,--build-id=none -Wl,--dynamic-linker,/lib/ld-linux.so.2 \
  -Wl,--no-as-needed -Wl,-rpath,'$ORIGIN' -L"$out" \
  -o "$out/weak-reference" "$out/weak-start.S" -lfirst -lsecond
