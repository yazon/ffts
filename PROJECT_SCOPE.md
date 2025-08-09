# Project Scope

## Current Objective: NEON Macro Parity ARM32 vs ARM64

Validate that `macros-neon.h` and `macros-neon64.h` implement equivalent semantics for all exposed macros used in FFT kernels.

### How to run

- ARM32:
  - `bash tests/run_macros_arm32.sh` (uses `${TOOLCHAIN:-arm-linux-gnueabihf}` and `qemu-arm`)
- ARM64:
  - `bash tests/run_macros_arm64.sh` (uses `${TOOLCHAIN:-aarch64-linux-gnu}` and `qemu-aarch64`)

Compare the textual outputs line-by-line to ensure matching behavior. For automated comparison, redirect both outputs to files and `diff` them.

### Notes
- The test program conditionally uses the 2-arg complex multiply helpers on ARM64 and the legacy 3-arg helpers on ARM32 via `macros.h` selection logic.
- Tests cover: load/store, arithmetic ops, data reorg helpers, XOR sign masks, IMULI, IMUL, IMULJ, and interleaved LD2/ST2.

## Current Objectives (ARM64)
- Achieve correctness for N=8 and N=16 in dynamic JIT path with low L2 error.
- Eliminate illegal instruction/segfault at N≥32 by fixing prologue, loop counters, twiddle/offset pointer setup.
- Keep dynamic generation enabled; static kernels only for isolation.

## Debug Aids
- `FFTS_DEBUG_PATCH=1` to log sign patch toggles.
- `FFTS_DEBUG_JIT=1` to dump first 256 bytes of the generated JIT buffer.

## Short-term Objective: ARM64 Size-8/16 Correctness

- Fix large relative L2 error for N=8 and N=16 when running `tests/test` under ARM64.
- Align sign handling with ARM32 by toggling the correct AArch64 opcode bit during blob patching.
- Ensure plan assembly for N=16 composes from the 8-pt kernel + twiddle stage rather than using placeholder kernels. 