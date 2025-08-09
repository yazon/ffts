#!/usr/bin/env bash
# Run unit tests for NEON macros on ARM64 (AArch64) using cross-compiler + QEMU
# Usage: ./tests/run_macros_arm64.sh [toolchain]
# Default toolchain: aarch64-linux-gnu
set -euo pipefail

TOOLCHAIN=${1:-aarch64-linux-gnu}
CC=${CC:-"${TOOLCHAIN}-gcc"}
CXX=${CXX:-"${TOOLCHAIN}-g++"}
SYSROOT_DIR=${SYSROOT_DIR:-/usr/aarch64-linux-gnu}
QEMU_CPU_MODEL=${QEMU_CPU:-max}

if ! command -v "$CC" >/dev/null 2>&1; then
  echo "Error: cross-compiler '$CC' not found. Install ${TOOLCHAIN}-gcc or set CC." >&2
  exit 1
fi

mkdir -p build/arm64
OUT=build/arm64/test_macros64
SRC=tests/test_macros.c

# Target AArch64 with NEON, define HAVE_ARM64 to select macros-neon64.h in macros.h
CFLAGS="-std=c99 -O2 -pipe -march=armv8-a -DHAVE_ARM64 -DHAVE_STDLIB_H"
INCLUDES="-Isrc -Iinclude"

set -x
"$CC" $CFLAGS $INCLUDES "$SRC" -o "$OUT"
set +x

echo "Built: $OUT"

if command -v qemu-aarch64 >/dev/null 2>&1; then
  echo "Running under QEMU..."
  set -x
  qemu-aarch64 -cpu "$QEMU_CPU_MODEL" -L "$SYSROOT_DIR" "$OUT" | cat
  set +x
else
  echo "qemu-aarch64 not found; cannot run the ARM64 binary here."
fi 