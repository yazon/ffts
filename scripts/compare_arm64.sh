#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Rebuild for ARM64 so tests/test and lib are AArch64 ELF
SKIP_QEMU_TEST=1 ./build_arm64.sh aarch64-linux-gnu "$(pwd)/build/arm64"

# Run the snapshot and save output
OUT="$(pwd)/build/arm64_snap.txt"
if ! command -v qemu-aarch64 >/dev/null 2>&1; then
  echo "qemu-aarch64 not found. Please install qemu-user-static or qemu-user." >&2
  exit 1
fi
QEMU_CPU=${QEMU_CPU:-max}
qemu-aarch64 -cpu "$QEMU_CPU" -L /usr/aarch64-linux-gnu tests/test --snap-stores-32 | tee "$OUT"
echo "Saved ARM64 snapshot to $OUT" 