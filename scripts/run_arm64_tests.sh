#!/usr/bin/env bash
# Minimal ARM64 N=8 test runner
set -euo pipefail

# Config
TOOLCHAIN=${TOOLCHAIN:-aarch64-linux-gnu}
CPU_MODEL=${QEMU_CPU:-max}
INSTALL_DIR=${INSTALL_DIR:-$(pwd)/build/arm64}

# Build (dynamic JIT enabled; no static path)
"$(pwd)/build_arm64.sh" "${TOOLCHAIN}" "${INSTALL_DIR}"

# Run tests under QEMU
if ! command -v qemu-aarch64 >/dev/null 2>&1; then
  echo "qemu-aarch64 not found" >&2
  exit 1
fi

export QEMU_CPU="${CPU_MODEL}"

if [ -x tests/test ]; then
  echo "--- ARM64: N=8 forward (sign=-1) L2 ---"
  qemu-aarch64 -cpu "${CPU_MODEL}" -L /usr/aarch64-linux-gnu tests/test --l2 8 -1 | cat
  echo "--- ARM64: N=8 inverse (sign=+1) L2 ---"
  qemu-aarch64 -cpu "${CPU_MODEL}" -L /usr/aarch64-linux-gnu tests/test --l2 8 1 | cat
  echo "--- ARM64: N=8 dump forward ---"
  qemu-aarch64 -cpu "${CPU_MODEL}" -L /usr/aarch64-linux-gnu tests/test --dump-n8 -1 | cat
else
  echo "tests/test not found" >&2
  exit 1
fi 