#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

TOOLCHAIN=${TOOLCHAIN:-arm-linux-gnueabihf}
INSTALL_DIR=${INSTALL_DIR:-$(pwd)/build/arm32}

./build_arm32.sh "$TOOLCHAIN" "$INSTALL_DIR"

# Preserve ARM32 test binary
if [ -f tests/test ]; then
  cp -f tests/test tests/test_arm32
fi

if ! command -v qemu-arm >/dev/null 2>&1; then
  echo "qemu-arm not found; install qemu-user-static or qemu-user" >&2
  exit 1
fi

QEMU_LD_PREFIX=${QEMU_LD_PREFIX:-/usr/arm-linux-gnueabihf}

echo "ARM32 N=32 plan dump"
qemu-arm -L "$QEMU_LD_PREFIX" tests/test_arm32 --dump-plan-32 || true

echo "Running ARM32 N=8 trace (sign=-1)"
qemu-arm -L "$QEMU_LD_PREFIX" tests/test_arm32 --trace-n8 -1 || true

echo "Running ARM32 L2 N=8/-1 and N=8/+1"
qemu-arm -L "$QEMU_LD_PREFIX" tests/test_arm32 --l2 8 -1 || true
qemu-arm -L "$QEMU_LD_PREFIX" tests/test_arm32 --l2 8 1 || true

echo "ARM32 L2 N=32/-1"
qemu-arm -L "$QEMU_LD_PREFIX" tests/test_arm32 --l2 32 -1 || true 