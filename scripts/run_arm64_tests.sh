#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

TOOLCHAIN=${TOOLCHAIN:-aarch64-linux-gnu}
QEMU_CPU_MODEL=${QEMU_CPU:-max}
INSTALL_DIR=${INSTALL_DIR:-$(pwd)/build/arm64}

SKIP_QEMU_TEST=1 ./build_arm64.sh "$TOOLCHAIN" "$INSTALL_DIR"

# Preserve ARM64 test binary
if [ -f tests/test ]; then
  cp -f tests/test tests/test_arm64
fi

if ! command -v qemu-aarch64 >/dev/null 2>&1; then
  echo "qemu-aarch64 not found; install qemu-user-static or qemu-user" >&2
  exit 1
fi

QEMU_LD_PREFIX=${QEMU_LD_PREFIX:-/usr/aarch64-linux-gnu}

echo "ARM64 N=32 plan dump (no execute)"
qemu-aarch64 -cpu "$QEMU_CPU_MODEL" -L "$QEMU_LD_PREFIX" tests/test_arm64 --dump-plan-32 || true

echo "Running ARM64 N=8 trace (sign=-1)"
qemu-aarch64 -cpu "$QEMU_CPU_MODEL" -L "$QEMU_LD_PREFIX" tests/test_arm64 --trace-n8 -1 || true

echo "Running ARM64 L2 N=8/-1 and N=8/+1"
qemu-aarch64 -cpu "$QEMU_CPU_MODEL" -L "$QEMU_LD_PREFIX" tests/test_arm64 --l2 8 -1 || true
qemu-aarch64 -cpu "$QEMU_CPU_MODEL" -L "$QEMU_LD_PREFIX" tests/test_arm64 --l2 8 1 || true

echo "ARM64 L2 N=32/-1 (may crash)"
qemu-aarch64 -cpu "$QEMU_CPU_MODEL" -L "$QEMU_LD_PREFIX" tests/test_arm64 --l2 32 -1 || true 