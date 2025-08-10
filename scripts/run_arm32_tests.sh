#!/usr/bin/env bash
# Minimal ARM32 N=8 test runner
set -euo pipefail

# Config
TOOLCHAIN=${TOOLCHAIN:-arm-linux-gnueabihf}
INSTALL_DIR=${INSTALL_DIR:-$(pwd)/build/arm32}

# Build (dynamic JIT enabled; no static path)
"$(pwd)/build_arm32.sh" "${TOOLCHAIN}" "${INSTALL_DIR}"

# Run tests under QEMU
if ! command -v qemu-arm >/dev/null 2>&1; then
  echo "qemu-arm not found" >&2
  exit 1
fi

if [ -x tests/test ]; then
  echo "--- ARM32: N=8 forward (sign=-1) L2 ---"
  qemu-arm -L /usr/arm-linux-gnueabihf tests/test --l2 8 -1 | cat
  echo "--- ARM32: N=8 inverse (sign=+1) L2 ---"
  qemu-arm -L /usr/arm-linux-gnueabihf tests/test --l2 8 1 | cat
  echo "--- ARM32: N=8 dump forward ---"
  qemu-arm -L /usr/arm-linux-gnueabihf tests/test --dump-n8 -1 | cat
else
  echo "tests/test not found" >&2
  exit 1
fi 