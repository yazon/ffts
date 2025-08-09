### [ARM64 NEON Integration] Implementation

Brief description of the feature and its purpose.

Ensure ARM64 path uses hand-tuned NEON kernels in `neon64.s`, mirroring ARM32 behaviour with `neon.s`.

### Completed Tasks
- Verified label symmetry between `neon64.s` and C extern declarations.
- Confirmed patch helpers present in `codegen_arm64_macros.h`.
- Added `codegen_arm64_macros.h` and `neon64.s` to `EXTRA_DIST` in `src/arch/arm64/Makefile.am`.
- Added `codegen_arm64_macros.h` to `noinst_HEADERS`.
- Compile-test ARM64 build to ensure successful linkage (warnings remain to fix includes)

### In Progress Tasks
- (none)

### Future Tasks
- Implement further performance-critical kernels if profiling indicates.
- Update documentation in `PROJECT_SCOPE.md` and `CHANGELOG.md` after successful build.

### Implementation Plan
1. Finish CI build on real ARM64 runner.
2. Address any compilation warnings/errors.
3. Update documentation files per project guidelines.

### Relevant Files
- `src/arch/arm64/arm64-codegen.c` – Copies blobs and emits instructions.
- `src/codegen_arm64.h` – Public interface and wrappers.
- `src/arch/arm64/codegen_arm64_macros.h` – Patch helpers and blob copy.
- `src/neon64.s` – Hand-written NEON kernels for FFT.

### Architecture Decisions
- Reused ARM32 patch index lists to toggle FMLA/FMLS bits on ARM64.
- Kept assembly labels identical to aid cross-platform plan builder reuse. 

### [NEON Macro Parity] Implementation

Create unit tests to verify that `macros-neon.h` (ARM32) and `macros-neon64.h` (ARM64) produce identical results for each macro.

### Completed Tasks
- [x] Added `tests/test_macros.c` covering: load/store, add/sub/mul, swap pairs, duplicate RE/IM, unpack hi/lo, blend, XOR, IMULI, IMUL, IMULJ, V4SF2 load/store.
- [x] Added `tests/run_macros_arm32.sh` and `tests/run_macros_arm64.sh` to cross-compile and run under QEMU.

### In Progress Tasks
- [ ] Execute both scripts on CI and capture outputs for comparison.

### Future Tasks
- [ ] Add an automated diff checker to compare ARM32 vs ARM64 outputs.
- [ ] Extend coverage to edge cases (NaN, +/-0, denormals) and randomized vectors.

### Implementation Plan
- Build and run `tests/run_macros_arm32.sh` and `tests/run_macros_arm64.sh` locally or in CI.
- Save outputs for both and compare line-by-line.

### Relevant Files
- `tests/test_macros.c` – Macro unit tests.
- `tests/run_macros_arm32.sh` – ARM32 build+run via QEMU.
- `tests/run_macros_arm64.sh` – ARM64 build+run via QEMU. 

### [ARM32→ARM64 Codegen Parity] Implementation

Audit and fix the ARM64 code generator (`src/arch/arm64/arm64-codegen.c`) to be a correct functional port of `src/arch/arm/arm-codegen.c` where applicable, and correct ARM64-only routines.

### Completed Tasks
- [x] Wrote audit: `doc/ARM64_PORT_REVIEW.md` summarizing issues and fix plan.

### In Progress Tasks
- [ ] Prologue/epilogue parity: add `arm64_emit_std_prologue/epilogue` with `local_size` handling.
- [ ] Implement `arm64_emit_lean_prologue` API for selective saves.
- [ ] Replace `arm64_is_valid_immediate` with correct helpers and expose `arm64_mov_reg_imm64` wrapper.
- [ ] Fix `arm64_generate_complex_mul` to correct interleaved complex layout.
- [ ] Correct `arm64_generate_size16_base_case` comments and ±i math.
- [ ] Fix `arm64_emit_bit_reverse_address` to use 64-bit encodings and correct shifts.

### Future Tasks
- [ ] Add unit-style emission tests for prologue/epilogue and bit-reverse helpers.
- [ ] Gate optional instructions (e.g., FCMLA) on CPU features.

### Implementation Plan
- Implement helper functions in `src/arch/arm64/arm64-codegen.c` and declare in `src/arch/arm64/arm64-codegen.h`.
- Prefer existing inline encoders in `arm64-codegen.h`; avoid ad-hoc magic constants.
- Validate emitted encodings via `objdump` in CI on AArch64 when available.

### Relevant Files
- `src/arch/arm/arm-codegen.c` – Reference behavior
- `src/arch/arm64/arm64-codegen.c` – Target of fixes
- `src/arch/arm64/arm64-codegen.h` – Encoders and prototypes

### Architecture Decisions
- Do not emulate ARM32 conditional DPIs; use straight-line code with branches where needed on AArch64.
- Synthesize constants with MOVZ/MOVN+MOVK; detect logical immediates only where beneficial. 

### [ARM64 Size-8/16 Correctness] Implementation

Fix excessive L2 error for N=8 and N=16 on ARM64 by auditing base-case code paths and sign handling.

### Completed Tasks
- [x] Corrected sign-dependent patch bit for AArch64: use 0x00800000 (bit 23) instead of ARM32's 0x00200000 (bit 21) in `arm64_patch_neon64_x8_t` and related helpers in `src/arch/arm64/codegen_arm64_macros.h`.

### In Progress Tasks
- [ ] Verify N=8 output accuracy matches ARM32 reference within ~1e-8 relative L2 error.
- [ ] Validate that twiddle LUT selection (`ws_is`) and pointer arithmetic are correct for leaf_N=8 in the ARM64 path.
- [ ] Implement a correct size-16 base case or ensure the 16-point path is built from two 8s+twiddle without placeholder code.

### Future Tasks
- [ ] Extend sign-patching to other kernels (`neon64_ee/oo/e o/oe`) only if required by the specific transform sign.

### Implementation Plan
- Rebuild and run tests; inspect N=8 L2 error. If still high, cross-check `neon64_x8` vs ARM32 `neon_x8` arithmetic ordering and twiddle conjugation for sign.
- For N=16, ensure the generator uses the 8-point kernel + twiddle stage and not the placeholder `arm64_generate_size16_base_case`.

### Relevant Files
- `src/arch/arm64/codegen_arm64_macros.h` – sign patch helpers
- `src/arch/arm64/arm64-codegen.c` – base case generators and copy ranges
- `src/codegen.c` – plan assembly and calls to base cases

### Acceptance Criteria
- N=8 relative L2 error ~1e-8 (comparable to ARM32)
- N=16 relative L2 error ~1e-8
- No regressions for N=2,4 