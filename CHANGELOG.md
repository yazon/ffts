## Unreleased

- Add NEON macro parity tests to compare ARM32 (`macros-neon.h`) vs ARM64 (`macros-neon64.h`).
  - New test program: `tests/test_macros.c`
  - New runners: `tests/run_macros_arm32.sh`, `tests/run_macros_arm64.sh`
  - Output is human-readable; intended to be run under QEMU via cross toolchains. 
- Add ARM32→ARM64 codegen port review and fix plan:
  - New doc: `doc/ARM64_PORT_REVIEW.md`
  - TODO: Parity helpers for prologue/epilogue, constant synthesis, complex multiply, bit-reverse fixes.
- Fix ARM64 FFT size-8 correctness: use AArch64 add/sub select bit (0x00800000) in sign-dependent patching for `neon64_x8_t` and related helpers. Expected to reduce N=8/N=16 relative L2 error to parity with ARM32. 
- ARM64 N=8/16 parity: identified mismatch due to calling base-case blobs with `x0 = out` instead of `x0 = input`. Plan to wrap `neon64_x8`/`neon64_x8_t` invocations with `mov x0, x1` before and `mov x0, x2` after so leaves still see `x0 = out`.

### 2025-08-09
- ARM64: Fixed JIT prologue stream pointer setup. Replaced ad-hoc ADD (shifted register) encodings with `arm64_emit_add_shifted_reg` helper; base register now x0.
- ARM64: Tightened size-8 base-case copy range to [neon64_x8 .. neon64_x8_t) and bounded sign patching to blob range.
- ARM64: Refactored sign-patching to a pattern-based toggle for AdvSIMD FP add/sub and mla/mls (bit 23), avoiding corruption outside blob bounds.
- ARM64: Added optional debug envs `FFTS_DEBUG_PATCH` and `FFTS_DEBUG_JIT` to trace patching and dump JIT words. 

## 2025-08-10
- Tests: add focused N=8 debug mode to `tests/test` via `--dump-n8 <sign>`
- Scripts: add `scripts/run_arm32_tests.sh`, `scripts/run_arm64_tests.sh` to build and run minimal N=8 tests under QEMU
- Scripts: add `scripts/compare_n8.sh` to diff `p->ws` and output slices for ARM32 vs ARM64
- ARM64: tweak `arm64_patch_neon64_x8_t` polarity helper (will replace with precise indices); N=8 still mismatches (L2=1.0) indicating sign-toggle scope/indices likely differ from ARM32 