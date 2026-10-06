#!/usr/bin/env bash
set -euo pipefail
fixture=${1:?usage: check-native.sh BUILT_FIXTURE}
ulimit -c 0
check() {
 local binary=$1 expected=$2 actual
 if timeout -k 2 10 "$binary"; then actual=0; else actual=$?; fi
 printf '%s: exit%s, expected%s\n' "$binary" "$actual" "$expected"
 [ "$actual" -eq "$expected" ]
}
check "$fixture" 0
check "$fixture-no-nesting" 1
check "$fixture-bad-restorer" 139
