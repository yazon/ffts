# ARM32 → ARM64 Codegen Port Review

Date: 2025-08-08

## Scope
- Compare `src/arch/arm/arm-codegen.c` (ARM32) vs `src/arch/arm64/arm64-codegen.c` (ARM64)
- Identify mismatches, omissions, and incorrect ports
- Produce a concrete fix plan and acceptance criteria

## Findings (function-by-function)

- arm_emit_std_prologue (ARM32)
  - Purpose: Save args, setup frame, allocate local stack (`local_size`).
  - ARM64 status: `arm64_generate_prologue` exists but does not support `local_size` and saves only a subset of GPRs; caller arg save semantics differ (x0–x7 are caller-saved on AArch64).
  - Issue: Not equivalent; stack allocation unsupported; optional saves not parameterized.

- arm_emit_std_epilogue (ARM32)
  - Purpose: Deallocate `local_size`, restore registers; supports `pop_regs`.
  - ARM64 status: `arm64_generate_epilogue` exists; no `local_size` handling; no configurable pops.
  - Issue: Not equivalent.

- arm_emit_lean_prologue (ARM32)
  - Purpose: Lean frame with selective pushes and optional local allocation.
  - ARM64 status: Missing.
  - Issue: Missing counterpart.

- arm_bsf / arm_is_power_of_2 / calc_arm_mov_const_shift / is_arm_const / arm_const_steps (ARM32)
  - Purpose: Bit operations and constant synthesis heuristics.
  - ARM64 status: Missing or non-equivalent; ARM64 has different immediate rules (MOVZ/MOVN/MOVK, logical-immediate masks).
  - Issue: Missing equivalents; `arm64_is_valid_immediate` placeholder is incorrect.

- arm_mov_reg_imm32_cond / arm_mov_reg_imm32 (ARM32)
  - Purpose: Synthesize arbitrary 32-bit constant via MOV/MVN/ORR sequences (conditional variant).
  - ARM64 status: No direct equivalent; header has `arm64_mov_imm64()` helper but not exposed under parity names.
  - Issue: Missing parity helpers; conditional execution model differs on AArch64 (predication via branches).

- arm64_generate_complex_mul (ARM64-only)
  - Purpose: Complex multiply on interleaved vectors.
  - Status: Incomplete; comment notes layout issues; result not interleaved as required.
  - Issue: Incorrect output layout for [re0, im0, re1, im1].

- arm64_generate_size16_base_case (ARM64-only)
  - Purpose: 16-point FFT kernel.
  - Status: Comments claim saving callee-saved vector regs, but only GPRs are saved; ±i multiplication implemented as swap only.
  - Issues: ABI comment mismatch; ±i multiply is mathematically incorrect.

- arm64_is_valid_immediate (ARM64-only)
  - Purpose: Validate immediates.
  - Status: Oversimplified; does not reflect AArch64 immediate classes.
  - Issue: Incorrect logic; misleading.

- arm64_emit_bit_reverse_address (ARM64-only)
  - Purpose: Emit bit-reverse and shift-right for address calculation.
  - Status: Uses 32-bit RBIT opcode and 32-bit UBFM for LSR regardless of register width.
  - Issue: Wrong encodings for 64-bit case; shift amount should use 64-bit (LSR by 64−logN).

## Fix Plan

1. Prologue/Epilogue Parity
   - Add `arm64_emit_std_prologue(p, local_size)` and `arm64_emit_std_epilogue(p, local_size)` with correct SP adjustment (chunked 12-bit immediates).
   - Add `arm64_emit_lean_prologue(p, local_size, push_mask)` supporting at least x19–x22 saves.
   - Keep existing `arm64_generate_prologue/epilogue` for current callers.
   - Acceptance: Unit test emits expected bytes for representative `local_size` values (0, 64, 4095, 5000).

2. Constant Utilities
   - Implement `arm64_bsf`, `arm64_is_power_of_2`, `arm64_const_movk_steps`.
   - Expose `arm64_mov_reg_imm64()` parity helper (wrapper to existing inline `arm64_mov_imm64`).
   - Replace `arm64_is_valid_immediate` with correct checks for ADD/SUB immediates (12-bit, optional 12-bit shift) and make it explicit that MOV{Z,N,K} can synthesize any 32/64-bit constant.
   - Acceptance: Unit tests for step counts and validity checks.

3. Complex Arithmetic
   - Fix `arm64_generate_complex_mul` to produce interleaved `[re0, im0, re1, im1]`:
     - Compute re = a*c − swap(a)*d, im = a*d + swap(a)*c, then `uzp1` even lanes and `zip1` into interleaved form.
   - Acceptance: Compare against `macros-neon64.h` for a set of input vectors.

4. Size-16 Base Case Corrections
   - Correct comments regarding callee-saved vector regs; avoid claiming saves.
   - Replace incorrect ±i multiply snippets with correct swap+sign operations or leave kernel as placeholder without misleading math.
   - Acceptance: No mathematically wrong transforms emitted; placeholder clearly marked.

5. Bit-Reverse Address Emission
   - Use 64-bit RBIT (`0xDAC00000`) and LSR via UBFM 64-bit encoding (`0xD3400000 | immr<<16 | imms<<10`).
   - Acceptance: Encoded instructions match disassembly for sample values.

6. Documentation & Tasks
   - Update `TASKS.md` with this plan and track progress.
   - Update `CHANGELOG.md` with fixes.

## Acceptance Criteria
- Builds on AArch64 toolchain without new warnings.
- Unit tests (where applicable) pass for new helpers.
- No regressions in existing ARM64 tests.
- Correctness for complex multiply verified against reference macro. 