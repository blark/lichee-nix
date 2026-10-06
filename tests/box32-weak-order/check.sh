#!/usr/bin/env bash
set -euo pipefail
old=${1:?usage: check.sh OLD_BOX64 NEW_BOX64 FIXTURE_DIRECTORY}
new=${2:?provide patched Box64 executable}
fixtures=${3:?provide fixture directory}
for test in first-wins reverse-wins weak-reference; do
  if BOX64_LOG=0 "$old" "$fixtures/$test"; then
    echo "FAIL: original Box32 unexpectedly passed $test" >&2
    exit 1
  else
    status=$?
    [ "$status" -eq 1 ] || { echo "FAIL: original $test exit=$status, expected 1" >&2; exit 1; }
  fi
  BOX64_LOG=0 "$new" "$fixtures/$test"
  echo "PASS: $test fails with original, passes with patched"
done
