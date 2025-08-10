#!/usr/bin/env bash
# Compare N=8 forward dump between ARM32 and ARM64 under QEMU
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
ARM32_SCRIPT="$ROOT/scripts/run_arm32_tests.sh"
ARM64_SCRIPT="$ROOT/scripts/run_arm64_tests.sh"
OUTDIR="${OUTDIR:-$ROOT/build/n8_compare}"
mkdir -p "$OUTDIR"

# Build+run and capture outputs
ARM32_LOG="$OUTDIR/arm32_n8_dump.txt"
ARM64_LOG="$OUTDIR/arm64_n8_dump.txt"

# Ensure fresh builds and capture only the dump sections
bash "$ARM32_SCRIPT" | tee "$OUTDIR/arm32_full.txt" >/dev/null || true
bash "$ARM64_SCRIPT" | tee "$OUTDIR/arm64_full.txt" >/dev/null || true

# Extract relevant sections
awk '/^p->ws\[0../, /^L2 Error:/{print}' "$OUTDIR/arm32_full.txt" > "$ARM32_LOG" || true
awk '/^p->ws\[0../, /^L2 Error:/{print}' "$OUTDIR/arm64_full.txt" > "$ARM64_LOG" || true

# Show diffs
echo "=== DIFF: p->ws and output (ARM32 vs ARM64) ==="
diff -u "$ARM32_LOG" "$ARM64_LOG" || true

echo "Logs saved under: $OUTDIR" 