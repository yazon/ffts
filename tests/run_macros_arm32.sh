#!/usr/bin/env bash
# Run unit tests for NEON macros on ARM32 (AArch32) using cross-compiler + QEMU
# Usage: ./tests/run_macros_arm32.sh [toolchain]
# Default toolchain: arm-linux-gnueabihf
set -euo pipefail

TOOLCHAIN=${1:-arm-linux-gnueabihf}
CC=${CC:-"${TOOLCHAIN}-gcc"}
CXX=${CXX:-"${TOOLCHAIN}-g++"}
SYSROOT_DIR=${SYSROOT_DIR:-/usr/arm-linux-gnueabihf}

if ! command -v "$CC" >/dev/null 2>&1; then
  echo "Error: cross-compiler '$CC' not found. Install ${TOOLCHAIN}-gcc or set CC." >&2
  exit 1
fi

mkdir -p build/arm32
OUT=build/arm32/test_macros32
SRC=tests/test_macros.c

# Enable NEON and hard-float ABI for common gnueabihf toolchains
CFLAGS="-std=c99 -O2 -pipe -march=armv7-a -mfpu=neon -mfloat-abi=hard -D__ARM_NEON -DHAVE_NEON -DHAVE_STDLIB_H"
INCLUDES="-Isrc -Iinclude"

set -x
"$CC" $CFLAGS $INCLUDES "$SRC" -o "$OUT"
set +x

echo "Built: $OUT"

if command -v qemu-arm >/dev/null 2>&1; then
  echo "Running under QEMU..."
  set -x
  qemu-arm -L "$SYSROOT_DIR" "$OUT" | cat
  set +x
else
  echo "qemu-arm not found; cannot run the ARM32 binary here."
fi 