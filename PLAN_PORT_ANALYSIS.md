### ARM32 → ARM64 Port Analysis Plan

This document outlines a thorough, step-by-step plan to identify and fix the root causes of failures in the ARM64 dynamic FFTS implementation. The focus areas are:
- Port of `src/neon.s` to `src/neon64.s`
- Port of `src/arch/arm/arm-codegen.c` to `src/arch/arm64/arm64-codegen.c`
- Integration in `src/codegen.c` and runtime glue under ARM64

We will proceed in three phases per repository rules: Analysis → Planning → Implementation.

### Objectives
- Make N=8 and N=16 produce correct outputs (low L2 error comparable to ARM32).
- Eliminate the SIGSEGV at N≥32 by fixing register setup and control-flow in the ARM64 JIT path.
- Keep dynamic code generation as the final solution (static only allowed temporarily for isolation).

### Acceptance criteria
- tests/test: “L2 Error” for N=8,16 around machine epsilon (similar to ARM32 output).
- tests/test completes up to 2^18 under AArch64/QEMU without crash.
- No accidental use of static kernels for ARM64 dynamic build path.

---

## Phase 1: Analysis

1) Validate execution environment and instruction set
- Confirm QEMU aarch64 “max” emulates the NEON FP ops (FADD/FSUB/FMUL/FMLA) we use. FCMLA is not required.
- Record QEMU version used and command line.

2) Data layout and calling conventions
- Verify the expected data layout in all ARM64 NEON kernels (interleaved vs split-complex) and confirm it matches `ffts_generate_luts` and JIT expectations.
- Map the exact calling convention for each kernel (x4, x8, x8_t, ee, oo, eo, oe): registers used and their meanings.
- Compare against ARM32 `neon.s` comments and usage.

3) JIT integration on ARM64
- Trace entry registers for the generated transform: at function entry, AAPCS64 dictates x0=plan, x1=in, x2=out.
- Ensure ARM64 prologue configures:
  - x3..x10: eight in-stream pointers computed from x0 (out base) and N*8 stride (see doc’s Fig. 8 and ARM32 prologue).
  - x12: `plan->offsets` pointer (δk offsets used by leaf kernels to compute destinations).
  - x0: out pointer (move x2 → x0), preserved plan pointer (x19) for LDRs.
  - Twiddle pointers per kernel: ee uses x2; eo/oe use x11; (base-case x8 uses x12 as LUT internally).
  - x11: loop counter used by the leaf kernels.
- Verify `generate_leaf_*_arm64` register assumptions match what is set above.

4) Blob copy ranges and sign patching
- For base cases:
  - x4: copy [neon64_x4 .. neon64_x8)
  - x8: copy [neon64_x8 .. neon64_x8_t)
  - Ensure patch indices for sign flipping apply to the copied ranges only and flip AArch64 bit 23 (FADD⇄FSUB/FMLA⇄FMLS).
- For leaf kernels:
  - ee: copy [neon64_ee .. neon64_oo)
  - oo: copy [neon64_oo .. neon64_eo)
  - eo: copy [neon64_eo .. neon64_oe)
  - oe: copy [neon64_oe .. neon64_end)
- Reconfirm all indices in `codegen_arm64_macros.h` correspond to AArch64 blobs (not ARM32)

5) Instruction-by-instruction cross-check of each kernel
- x4/x8/x8_t: complex mul and butterfly, loads/stores, stride usage (r1/x1), and that x8_t patching flips the right ops for inverse.
- ee/oo/eo/oe: check loop counter register (x11), ld2/st2 constraints (consecutive vector regs), vtrn/trn ordering, δk offsets usage via x12, address calculations from x0 + δk<<2 (doc Fig. 3 and ARM32 code).

6) LUT/offset generation parity (from doc)
- δk offsets: Confirm `ffts_elaborate_tree`/`INIT-OFFSETS` semantics match doc Fig. 3 and that leaf kernels use δk (x12) to place outputs (no explicit bit-reversal pass).
- Sign handling: NEON variant absorbs sign in code; verify our runtime sign patching (bit 23) reproduces forward/inverse differences (doc Sec. VI).
- Base cases: Size-8 is the largest without spills (doc Sec. V). Verify our AArch64 base cases still use 16 regs (q0–q15) and avoid callee-saved spills.

7) Branching and code-size sanity
- Ensure all internal branches within copied blobs are PC-relative and remain valid after relocation.
- Ensure no blob references external labels outside copied range.

### Cross-check from extracted_text2.md (requirements distilled)
- Algorithm: conjugate-pair split-radix with δk precomputed offsets; base cases (N≤16) executed iteratively, then recursion free of base cases (FFTS-NOLEAVES).
- Data format: NEON path uses ld2/st2 to operate on interleaved complex data by de-/re-interleaving (doc Sec. V); our AArch64 leaf kernels must adhere to this.
- Twiddle/sign: ARM NEON flips certain add/sub at runtime to switch FFT⇄IFFT (we must flip AArch64 bit 23 on the same instruction classes).
- Base-case size and stride: Size-8 kernels, with stride = N*8 bytes for stream pointers; register map mirrors ARM32 (r0→x0 out, r1→x1 stride/size, r2→x2 ee_ws, r11→x11 eo/oe twiddles, r12→x12 δk offsets).

Validation tasks added:
- [Doc→Code] Confirm δk used via x12 in ee/oo/eo/oe and that addressing is base x0 + (δk<<2) as in ARM32 ports.
- [Doc→Code] Confirm stride usage (x1) for base-cases and leafs; verify x3..x10 computed from x0, N (LSL #3) matches Fig. 8 patterns (e.g., 32→256 byte deltas).
- [Doc→Code] Verify add/sub flips cover all places marked in doc’s size-4 codelet example (lines 301–307) analogously in AArch64.

---

## Phase 2: Implementation Plan (Fixes)

A) Make base cases correct (N=8/16)
- Correct x8 blob copy range to [neon64_x8 .. neon64_x8_t).
- Verify and adjust sign patch routine for x8.
- Add a minimal unit harness to run N=8 and N=16 using JIT-only path.

B) Fix ARM64 JIT prologue/setup
- Implement an ARM64 prologue mirroring ARM32 register setup:
  - Preserve plan pointer in x19.
  - Compute in-stream pointers x3..x10 from x1 and N.
  - Load x12 with `plan->offsets`.
  - Move out pointer from x2→x0.
  - Load correct twiddle ws into x2 just before the specific leaf kernel (ee/e o/oo/oe) is emitted.
  - Initialize x11 loop counter to the correct iteration count (use p->i0/p->i1, matching ARM32 logic).
- Ensure leaf kernel emission order matches the original ARM32 selection logic.

C) Leaf kernels correctness
- Verify each leaf kernel receives correct x2 (ee_ws/e o_ws/oe_ws), x12, x3..x10, x11.
- Audit all st2/ld2 pairs to ensure consecutive register operands.
- Re-run patch indices on AArch64 bit 23, update any incorrect tables.

D) Robustness of immediate encoding
- Replace raw literal encodings with helper functions where possible.
- For ADD immediate beyond 12 bits, emit multiple adds (as done for stack locals) to avoid silent truncation.

E) Testing and instrumentation
- Add a debug mode to print first few complex outputs for N=8/16 to quickly spot sign/layout errors.
- Add `scripts/run_arm64_tests.sh` to invoke qemu-aarch64 with adjustable QEMU_CPU.
- Keep `tests/test` as the authoritative acceptance test.

---

## Phase 3: Validation & Review

- Verify N=2..2^18 forward and inverse runs complete without crash and with low error.
- Compare ARM32 vs ARM64 outputs on a few sizes to ensure close parity.
- Ensure dynamic code path is used (no accidental static substitution) per build scripts.

---

## Artifacts to update
- `STATUS_PORT_ANALYSIS.md`: per-step progress, findings, decisions.
- `CHANGELOG.md`: summarize fixes to ARM64 codegen and kernels.
- `TASKS.md`: mark completed tasks, add follow-ups.
- Add `scripts/run_arm64_tests.sh` for reproducible testing under qemu.

---

## Risks & Mitigations
- Incorrect patch indices: re-derive indices from AArch64 disassembly (use objdump) and lock them with comments.
- Immediate encoding limits: introduce chunked add helpers where needed.
- QEMU differences: If emu bugs suspected, validate on real AArch64 when possible. 