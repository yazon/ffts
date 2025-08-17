#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Rebuild for ARM32 so tests/test is an ARM32 ELF
./build_arm32.sh arm-linux-gnueabihf "$(pwd)/build/arm32"

# Run the snapshot and save output
OUT="$(pwd)/build/arm32_snap.txt"
if ! command -v qemu-arm >/dev/null 2>&1; then
  echo "qemu-arm not found. Please install qemu-user-static or qemu-user." >&2
  exit 1
fi
qemu-arm -L /usr/arm-linux-gnueabihf tests/test --snap-stores-32 | tee "$OUT"
echo "Saved ARM32 snapshot to $OUT" 