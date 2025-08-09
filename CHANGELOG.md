## Unreleased

- Add NEON macro parity tests to compare ARM32 (`macros-neon.h`) vs ARM64 (`macros-neon64.h`).
  - New test program: `tests/test_macros.c`
  - New runners: `tests/run_macros_arm32.sh`, `tests/run_macros_arm64.sh`
  - Output is human-readable; intended to be run under QEMU via cross toolchains. 
- Add ARM32→ARM64 codegen port review and fix plan:
  - New doc: `doc/ARM64_PORT_REVIEW.md`
  - TODO: Parity helpers for prologue/epilogue, constant synthesis, complex multiply, bit-reverse fixes.
- Fix ARM64 FFT size-8 correctness: use AArch64 add/sub select bit (0x00800000) in sign-dependent patching for `neon64_x8_t` and related helpers. Expected to reduce N=8/N=16 relative L2 error to parity with ARM32. 