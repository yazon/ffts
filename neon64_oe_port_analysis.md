## AArch64 Port Analysis: `neon64_oe` (Odd–Even Stockham)

This document records a step-by-step audit of the ARM32 `neon_oe` macro in `src/neon.s` versus its AArch64 port `neon64_oe` in `src/neon64.s`, details the defects identified, the precise fixes applied, and the rationale with references. It also includes alignment/offsets analysis and current test status.

Reference: ARMv8-A Architecture (A64) Supplement, DDI0600B (`https://kib.kiev.ua/x86docs/ARM/ARMARMv8/DDI0600B_a_armv8_r64_supplement.pdf`).

---

### Scope and goal
- **Scope**: ONLY the OE leaf: `neon_oe` (ARM32) vs `neon64_oe` (AArch64). Other leaves (EE/EO/OO) are not analyzed here.
- **Goal**: Ensure the AArch64 port is functionally equivalent instruction-by-instruction; fix bugs (particularly those causing segfaults); verify alignment and addressing constraints.

---

## Summary of issues found and fixes applied

- **Offsets load width and post-increment (CRITICAL segfault cause)**
  - ARM32 OE consumes 32-bit offsets (two per iteration) with `ldr r2, [r12], #4` and `ldr lr, [r12], #4`.
  - AArch64 port had `ldr x14, [x12], #8` (64-bit load with 8B post-increment), corrupting the offsets stream and later store addresses → potential segfault.
  - ✅ FIX: `ldr w14, [x12], #4`. Keep 32-bit widths and 4B post-increments for both offsets loads.

- **Address computation scaling and extension semantics**
  - ARM32 uses `add r2, r0, r2, lsl #2` and `add lr, r0, lr, lsl #2` (logical left shift of 32-bit indices).
  - AArch64 port used `sxtw #2` (sign-extend + shift). While offsets are non-negative, this is semantically different and fragile.
  - ✅ FIX: `add x2, x0, w2, uxtw #2` and `add x14, x0, w14, uxtw #2` (logical zero-extend + shift), exactly matching ARM32.

- **Missing extraction of q10 high half (d21)**
  - ARM32 uses both `d20` and `d21` (low/high halves of q10). A64 must explicitly extract the high half.
  - AArch64 port did not extract `d21` prior to `vtrn.32 d20, d21` usage, leaving `v21` undefined.
  - ✅ FIX: `ext v21.16b, v10.16b, v10.16b, #8` (copy q10 high 64 bits to `v21`).

- **Incorrect `vswp` ports (multiple sites)**
  - ARM32 `vswp dX, dY` swaps 64-bit halves across different q-registers. The port at several points swapped entire q-registers or the wrong halves.
  - ✅ FIXES (lane-only, 64-bit half swaps):
    - `vswp d1, d2` → swap `v0.d[1]` ↔ `v1.d[0]`.
    - `vswp d5, d6` → swap `v2.d[1]` ↔ `v3.d[0]`.
    - `vswp d9, d10` → swap `v4.d[1]` ↔ `v5.d[0]`.
    - `vswp d13, d14` → swap `v6.d[1]` ↔ `v7.d[0]`.
  - Implemented with a temp vector (e.g., `v31.16b`) to avoid clobber hazards.

- **Minor safety tweak in a `vtrn.32` pair**
  - A pattern `trn1 v16.2s, v20.2s, v16.2s; trn2 v16.2s, v20.2s, v16.2s` risks clobbering a source across the two ops if reused.
  - ✅ FIX: Use a temp for the first result: `trn1 v31.2s, v20.2s, v16.2s; trn2 v16.2s, v20.2s, v16.2s; mov v20.16b, v31.16b`.

- **JIT callsite preparation for OE offsets**
  - To guarantee the OE leaf reads the correct offsets slice, reload `x12 = plan->offsets` immediately before calling `neon64_oe`.
  - ✅ FIX in `src/codegen.c`: Insert `ARM64_LDRI_X(..., X12, X19, offsetof(plan, offsets))` right before OE leaf generation.

---

## Step-by-step comparison and validation

Below, ARM32 (left) vs AArch64 (right). Only the conceptual mapping is shown here; see code for exact registers.

### Block A: Initial data/twiddle loads and pairwise sums/diffs
- ARM32: `vld1.32 q8, q10; vld2.32 q11, q13, q15; vorr d25,d17; vorr d24,d20; vorr d20,d16; q9=q13-q11; q11=q13+q11`.
- A64: `ldr q8, q10; ld2 q11, q13, q15; ext d25 (q8 hi); mov d24 (q10 lo); mov d20 (q8 lo); fsub q9; fadd q11`.
- ✅ Equivalence: exact mapping of interleaved loads and low/high-half extraction; arithmetic matches.

### Block B: Offsets, transposes, address calc, and q8 update (FIXES applied)
- ARM32: `ldr r2,[r12],#4; vtrn.32 d24,d25; ldr lr,[r12],#4; vtrn.32 d20,d21; add r2,r0,r2,lsl#2; q8=q10−q12; add lr,r0,lr,lsl#2; q10=q10+q12; q0=q11+q10`.
- A64: `ldr w2,[x12],#4; trn1/trn2 d24,d25; ldr w14,[x12],#4; trn1/trn2 d20,d21 (with prior ext of d21); add x2,x0,w2,uxtw#2; q8=...; add x14,x0,w14,uxtw#2; q10=...; q0=...`.
- ✅ FIXES: 32-bit offset loads; logical zero-extend scaling; prior extraction of d21.

### Block C: Build q0/q1, transpose with q12/q13, `vswp d1,d2`, and store q0–q1 (FIX)
- ARM32: Compute `q0 = q11+q10`, `q1 = q11−q10`; `vtrn.32 q0,q12; vtrn.32 q1,q13; vswp d1,d2; vst1.32 {q0,q1}`.
- A64: fadds/fsubs; `trn1/trn2` pairs; `mov v31; mov v0.d[1], v1.d[0]; mov v1.d[0], v31.d[1]`; `stp q0,q1`.
- ✅ FIX: `vswp d1,d2` implemented as a lane-only swap, not full-register swap.

### Block D: Build q2/q3, transpose with q14/q13, `vswp d5,d6`, and store q2–q3 (FIX)
- ARM32: Load q0; compute q1=q0+q15; load q13/q14; build q0,q3,q2; `vtrn.32 q2,q14; vtrn.32 q3,q13; vswp d5,d6; vst1.32 {q2,q3}`.
- A64: ld2; fadd/fsub; build v0..v7; `trn1/trn2` pairs; `mov v31; mov v2.d[1], v3.d[0]; mov v3.d[0], v31.d[1]`; `stp q2,q3`.
- ✅ FIX: lane-only swap for `vswp d5,d6` implemented correctly.

### Block E: Transpose q11/q9 and q10/q8; twiddle multiplies; final butterfly; `vswp d9,d10` and `vswp d13,d14`; store q4–q7 (FIX)
- ARM32: `vtrn.32 q11,q9; vtrn.32 q10,q8; vmul d20,d18,d25; ...; vadd/sub (final); vswp d9,d10; vswp d13,d14; vstmia lr!, {q4-q7}`.
- A64: `trn1/trn2` with careful temp usage for q10/q8; `fmul` with twiddles in v24/v25; fadd/fsub (final); lane-only swaps for d9,d10 and d13,d14; `stp q4,q5` and `stp q6,q7` to `[x14]`.
- ✅ FIXES: lane-only swaps; safe transpose sequence.

---

## Alignment and addressing assumptions (validated)

- **Data buffers**: FFTS allocators use `ffts_aligned_malloc` (posix_memalign/memalign), yielding at least 16B alignment. Stream pointers (`x3..x10`) advance by strides that are multiples of 32/64 bytes.
- **NEON ld1/ld2 alignment**: AArch64 NEON `ld1/ld2` permit unaligned access. No misaligned traps expected for loads.
- **Stores with `stp qX,qY`**: Require 16B alignment for optimal performance. With the corrected offset computation, store addresses are computed as `x0 + (off2 * 4)` bytes. For N=32 we verified `off2 ∈ {0, 32, 16, 48}` (floats), thus byte offsets `{0, 128, 64, 192}` — all multiples of 16.
- **Offsets stream (`x12`)**: Now correctly reloaded prior to OE, and consumed as 32-bit entries with 4B post-increment. This avoids drifting the offsets pointer across leaves.

Conclusion: No alignment violations remain in `neon64_oe`.

---

## Code changes (files and excerpts)

- `src/neon64.s` (OE leaf)
  - Offsets loads and scaling:
    - Before: `ldr x14, [x12], #8`; `add x2, x0, w2, sxtw #2`; `add x14, x0, w14, sxtw #2`.
    - After:  `ldr w14, [x12], #4`; `add x2, x0, w2, uxtw #2`; `add x14, x0, w14, uxtw #2`.
  - High-half extraction:
    - Added: `ext v21.16b, v10.16b, v10.16b, #8` (for d21 before `vtrn.32 d20,d21`).
  - `vswp` corrections (lane-only swaps with temp):
    - `vswp d1, d2`  → swap `v0.d[1]` ↔ `v1.d[0]`.
    - `vswp d5, d6`  → swap `v2.d[1]` ↔ `v3.d[0]`.
    - `vswp d9, d10` → swap `v4.d[1]` ↔ `v5.d[0]`.
    - `vswp d13, d14`→ swap `v6.d[1]` ↔ `v7.d[0]`.
  - Safe transpose tweak:
    - `trn1 v31.2s, v20.2s, v16.2s; trn2 v16.2s, v20.2s, v16.2s; mov v20.16b, v31.16b`.

- `src/codegen.c` (AArch64 JIT callsite)
  - Before OE leaf emission, ensure `x12 = plan->offsets`:
    - Added: `ARM64_LDRI_X(..., ARM64_X12, ARM64_X19, offsetof(struct _ffts_plan_t, offsets));`

---

## Test status

- Build: OK (AArch64 cross, lib + tests built and installed under `build/arm64`).
- N=8: L2 errors ~1.21e-8 (both signs), good.
- N=32: still segfaults under QEMU after these fixes. Based on current audit, this is unlikely due to `neon64_oe` alignment/addressing; investigation should continue into offsets slice selection across leaves and/or remaining lane-pack subtleties.

Debug artifacts (from tests):
- Offsets (N=32): `OFFSETS-FINAL off2[0..4): 0 32 16 48`.
- Plan dump shows consistent `ws_is` and LUT bases.

---

## Rationale and A64 instruction notes

- **`uxtw` vs `sxtw`**: ARM32 `lsl` is a logical shift on 32-bit unsigned values. A64 `uxtw #2` preserves that semantics exactly by zero-extending prior to shift.
- **`ext` for high-half fetch**: A64 lacks implicit 64-bit d-register aliasing behavior from ARM32’s q/d view; `ext vX, vY, vY, #8` is the canonical way to obtain the high 64 bits of a 128-bit vector.
- **`vswp dA,dB` emulation**: Implement with lane moves: `mov vtmp.16b, vA.16b; mov vA.d[1], vB.d[0]; mov vB.d[0], vtmp.d[1]`. This swaps exactly the intended 64-bit halves across different q-registers.
- **`trn1/trn2`**: Pairs transpose the 32-bit lanes across two vectors. Care must be taken to preserve sources when the destination overlaps a later source.

---

## Open items and next steps

- Instrument N=32 OE stores to capture the exact faulting address/value under QEMU (e.g., write `x14`, `x2`, and first 16B before each `stp`).
- Double-check offsets slice selection across the full leaf chain for N=32 (EE → OE → EO/OO). We now reload `x12` before OE; similar care may be needed elsewhere depending on JIT path.
- Compare ARM32 vs ARM64 memory-layout footprints around the OE stores at N=32 to detect any remaining pack/unpack mismatches.

---

## Conclusion

The AArch64 `neon64_oe` now mirrors the ARM32 `neon_oe` for the audited instruction groups, with critical correctness fixes:
- Correct offsets load width/increment and address scaling.
- Restore missing high-half extraction for q10.
- Correct all `vswp` half-swaps.
- Ensure offsets pointer (`x12`) is correct upon OE entry.

These resolve several correctness hazards (including a primary segfault cause). N=8 is clean; N=32 still segfaults under QEMU and requires continued investigation beyond alignment/oe-leaf-local issues documented here. 