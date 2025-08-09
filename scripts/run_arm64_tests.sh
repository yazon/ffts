#!/usr/bin/env bash
set -euo pipefail

CPU_MODEL=${QEMU_CPU:-max}
TEST_BIN=${1:-tests/test}

if ! command -v qemu-aarch64 >/dev/null 2>&1; then
  echo "qemu-aarch64 not found" >&2
  exit 1
fi

if [ ! -x "$TEST_BIN" ]; then
  echo "Test binary '$TEST_BIN' not found or not executable" >&2
  exit 1
fi

echo "Running under qemu-aarch64 -cpu ${CPU_MODEL} ..."
exec qemu-aarch64 -cpu "$CPU_MODEL" -L /usr/aarch64-linux-gnu "$TEST_BIN" 