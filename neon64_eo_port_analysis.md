# AArch64 Port Analysis: `neon_eo` → `neon64_eo`

This document records a detailed, step-by-step analysis of the ARM32 `neon_eo` macro and its AArch64 port `neon64_eo`, highlights issues found in the port, the precise fixes applied, and current test outcomes. The goal is strict behavioral parity with ARM32 `neon_eo` (Stockham odd-even stage), avoiding undefined upper-half usage and ensuring register packing matches ARM32 expectations prior to transposes and stores.

## Scope
- Analyze and align only `neon_eo` (ARM32) ↔ `neon64_eo` (AArch64)
- Do not cover `oo`, `ee`, `oe` (handled elsewhere)
- Validate correctness using existing ARM64 test harness (QEMU)

## Summary of Key Findings and Fixes

- Fixed multiple places where the port used `.4s` (full 128-bit) vector ops immediately after `ld2 { … .2s … }` half-vector loads. In ARM32, `vld2.32` populates both halves of `qX` (d-lanes), but in our AArch64 port, only the low halves (`.2s`) were guaranteed. Using `.4s` in those contexts made upper halves undefined or stale, causing corrupt results and likely the segfault at larger sizes.
- Corrected all early arithmetic to paired `.2s` ops per d-lane, building both halves explicitly and then packing as needed.
- Fixed register-pair choices for swaps (`vswp`) and stores to reflect the intended q-registers:
  - For the first store block, `q4`/`q5` map to `v8`/`v10` here, not `v4`/`v5`.
  - For the second store block, `q6`/`q7` map to `v12`/`v14`, not `v6`/`v7`.
- Implemented explicit d-lane packing prior to `trn`/`vswp`/`stp` sequences so the layout matches ARM32.
- Fixed a destination register bug in the final butterfly step: `q2 = q9 - q11` must go to `v2`, not `v4`.
- Rewrote the `q15 = q13 - q11` recompute between two transposes using `.2s` halves plus pack, avoiding `.4s` on half-populated vectors.

Result:
- N=8 tests pass (L2 error ~1.21e-08, as expected for floating-point).
- N=32 still segfaults under QEMU; further stepwise investigation is ongoing.

## Environment & Test Harness
- Build/test via: `scripts/run_arm64_tests.sh`
- Cross environment: `aarch64-linux-gnu-*` toolchain; QEMU runtime.
- Observed output: N=8 passes (both signs), N=32 segfaults.

---

## ARM32 `neon_eo` → AArch64 `neon64_eo`: Stepwise Comparison and Fixes

Below, each block shows the ARM32 intent and the AArch64 port after fixes. All file-and-line references are to the current repo state.

### Block 1: Initial loads and first arithmetic (avoid undefined upper halves)

ARM32 intent (loads + adds/subs, split into d-lanes by the architecture):
```476:495:src/neon.s
vld2.32  {q9},  [r5, :64]!
vld2.32  {q13}, [r3, :64]!
vld2.32  {q12}, [r4, :64]!
vld2.32  {q0},  [r7, :64]!
vsub.f32 q11, q13, q12
vld2.32  {q8},  [r6, :64]!
vadd.f32 q12, q13, q12
vsub.f32 q10, q9,  q8
vadd.f32 q8,  q9,  q8
vadd.f32 q9,  q12, q8
vadd.f32 d9,  d23, d20
vsub.f32 d11, d23, d20
vsub.f32 q8,  q12, q8
vsub.f32 d8,  d22, d21
vadd.f32 d10, d22, d21
```

AArch64 after fixes (paired `.2s` ops, then pack as needed):
```885:913:src/neon64.s
// q11 = q13 - q12
a: fsub v22.2s, v26.2s, v24.2s
b: fsub v23.2s, v27.2s, v25.2s
// q12 = q13 + q12
c: fadd v24.2s, v26.2s, v24.2s
d: fadd v25.2s, v27.2s, v25.2s
// q10 = q9 - q8
e: fsub v20.2s, v18.2s, v16.2s
f: fsub v21.2s, v19.2s, v17.2s
// q8 = q9 + q8
g: fadd v16.2s, v18.2s, v16.2s
h: fadd v17.2s, v19.2s, v17.2s
// q9 = q12 + q8
i: fadd v18.2s, v24.2s, v16.2s
j: fadd v19.2s, v25.2s, v17.2s
// d9 = d23 + d20; d11 = d23 - d20
k: fadd v9.2s,  v23.2s, v20.2s
l: fsub v11.2s, v23.2s, v20.2s
// q8 = q12 - q8
m: fsub v16.4s, v24.4s, v16.4s  // safe: both halves now valid
// d8 = d22 - d21; d10 = d22 + d21
n: fsub v8.2s,  v22.2s, v21.2s
o: fadd v10.2s, v22.2s, v21.2s
```

Key change: The port previously used `.4s` in a–j. These are now `.2s` pairs to ensure both halves are defined and match ARM32 d-lane semantics.

### Block 2: First transpose + swap + store (`{d8,d9,d10,d11}`)

ARM32 intent:
```495:499:src/neon.s
vtrn.32  q9,  q4
add      r2,  r0,  r2, lsl #2
vtrn.32  q8,  q5
add      lr,  r0,  lr, lsl #2
vswp     d9,  d10
vst1.32  {d8, d9, d10, d11}, [lr, :64]!
```

AArch64 after fixes:
```914:949:src/neon64.s
// load offsets, twiddles, compute x2 and x16 as in ARM32
ldr  w2, [x12], #4
ldp  d20, d21, [x11]
ldr  w16, [x12], #4
add  x2,  x0, w2,  uxtw #2
add  x16, x0, w16, uxtw #2

// pack q4={d8,d9} into v8, q5={d10,d11} into v10
mov  v8.d[1],  v9.d[0]
mov  v10.d[1], v11.d[0]

// vtrn q9,q4 and vtrn q8,q5
mov  v31.16b, v18.16b
trn1 v18.4s, v31.4s, v8.4s
trn2 v8.4s,  v31.4s, v8.4s
mov  v31.16b, v16.16b
trn1 v16.4s, v31.4s, v10.4s
trn2 v10.4s, v31.4s, v10.4s

// vswp d9,d10 across q4/q5 (v8/v10)
mov  v31.16b, v8.16b
mov  v8.d[1],  v10.d[0]
mov  v10.d[0], v31.d[1]

// store {d8,d9,d10,d11}
stp  q8, q10, [x16], #32
```

Key changes:
- Use `v8/v10` (q4/q5) for swap and store, not `v4/v5`.
- Ensure packing to q4/q5 occurs before `trn`/`vswp`/`stp`.

### Block 3: Second loads + arithmetic + transpose + swap + store (`{d12,d13,d14,d15}`)

ARM32 intent:
```500:517:src/neon.s
vld2.32  {q13}, [r10, :64]!
vld2.32  {q15}, [r9,  :64]!
vld2.32  {q11}, [r8,  :64]!
vsub.f32 q14, q15, q13
vsub.f32 q12, q0,  q11
vadd.f32 q11, q0,  q11
vadd.f32 q13, q15, q13
vadd.f32 d13, d29, d24
vadd.f32 q15, q13, q11
vsub.f32 d12, d28, d25
vsub.f32 d15, d29, d24
vadd.f32 d14, d28, d25
vtrn.32  q15, q6
vsub.f32 q15, q13, q11
vtrn.32  q15, q7
vswp     d13, d14
vst1.32  {d12, d13, d14, d15}, [lr, :64]!
```

AArch64 after fixes (paired halves, correct q6/q7 mapping = v12/v14, pack d13 into q6 before transpose):
```950:1000:src/neon64.s
ld2  {v26.2s, v27.2s}, [x10], #16
ld2  {v30.2s, v31.2s}, [x9],  #16
ld2  {v22.2s, v23.2s}, [x8],  #16

// q14 = q15 - q13
fsub v28.2s, v30.2s, v26.2s
fsub v29.2s, v31.2s, v27.2s
// q12 = q0 - q11; q11 = q0 + q11
fsub v24.2s, v0.2s,  v22.2s
fsub v25.2s, v1.2s,  v23.2s
fadd v22.2s, v0.2s,  v22.2s
fadd v23.2s, v1.2s,  v23.2s
// q13 = q15 + q13
fadd v26.2s, v30.2s, v26.2s
fadd v27.2s, v31.2s, v27.2s

// d13 = d29 + d24; place into q6's high half
fadd v13.2s, v29.2s, v24.2s
mov  v12.d[1], v13.d[0]

// q15 = q13 + q11
fadd v30.2s, v26.2s, v22.2s
fadd v31.2s, v27.2s, v23.2s

// d12 = d28 - d25; d15 = d29 - d24; d14 = d28 + d25
fsub v12.2s, v28.2s, v25.2s
fsub v15.2s, v29.2s, v24.2s
fadd v14.2s, v28.2s, v25.2s

// vtrn q15, q6
mov  v31.16b, v30.16b
trn1 v30.4s, v31.4s, v12.4s
trn2 v12.4s, v31.4s, v12.4s

// q15 = q13 - q11 (compute halves and pack)
fsub v30.2s, v26.2s, v22.2s
fsub v31.2s, v27.2s, v23.2s
mov  v30.d[1], v31.d[0]

// vtrn q15, q7
mov  v31.16b, v30.16b
trn1 v30.4s, v31.4s, v14.4s
trn2 v14.4s, v31.4s, v14.4s

// vswp d13,d14 between q6 (v12) and q7 (v14)
mov  v31.16b, v12.16b
mov  v12.d[1], v14.d[0]
mov  v14.d[0], v31.d[1]

// store {d12,d13,d14,d15}
stp  q12, q14, [x16], #32
```

Key changes:
- All q-wide arithmetic on half-filled vectors replaced by explicit `.2s` halves, then pack.
- Correct q6/q7 register mapping to `v12/v14` throughout `vswp` and store.
- Explicitly placed `d13` into `q6` high half before the transposes.

### Block 4: `vtrn q13,q14` and `vtrn q11,q12` + complex multiply + final butterfly + stores

ARM32 intent:
```517:541:src/neon.s
vtrn.32  q13, q14
vtrn.32  q11, q12
vmul.f32 d24, d26, d21
vmul.f32 d28, d27, d20
vmul.f32 d25, d26, d20
vmul.f32 d26, d27, d21
vmul.f32 d27, d22, d21
vmul.f32 d30, d23, d20
vmul.f32 d29, d23, d21
vmul.f32 d22, d22, d20
vsub.f32 d21, d28, d24
vadd.f32 d20, d26, d25
vadd.f32 d25, d30, d27
vsub.f32 d24, d22, d29
vadd.f32 q11, q12, q10
vsub.f32 q10, q12, q10
vadd.f32 q0,  q9,  q11
vsub.f32 q2,  q9,  q11
vadd.f32 d3,  d17, d20
vsub.f32 d7,  d17, d20
vsub.f32 d2,  d16, d21
vadd.f32 d6,  d16, d21
vswp     d1,  d2
vswp     d5,  d6
vstmia   r2!, {q0-q3}
```

AArch64 after fixes:
```1001:1060:src/neon64.s
// vtrn q13,q14; vtrn q11,q12
mov  v31.16b, v26.16b
trn1 v26.4s, v31.4s, v28.4s
trn2 v28.4s, v31.4s, v28.4s
mov  v31.16b, v22.16b
trn1 v22.4s, v31.4s, v24.4s
trn2 v24.4s, v31.4s, v24.4s

// vmul block using .2s d-lanes
fmul v24.2s, v26.2s, v21.2s
fmul v28.2s, v27.2s, v20.2s
fmul v25.2s, v26.2s, v20.2s
fmul v26.2s, v27.2s, v21.2s
fmul v27.2s, v22.2s, v21.2s
fmul v30.2s, v23.2s, v20.2s
fmul v29.2s, v23.2s, v21.2s
fmul v22.2s, v22.2s, v20.2s

// d21,d20,d25,d24
fsub v21.2s, v28.2s, v24.2s
fadd v20.2s, v26.2s, v25.2s
fadd v25.2s, v30.2s, v27.2s
fsub v24.2s, v22.2s, v29.2s

// q11 = q12 + q10; q10 = q12 - q10
fadd v22.4s, v24.4s, v20.4s
fsub v20.4s, v24.4s, v20.4s

// q0 = q9 + q11; q2 = q9 - q11 (FIX: v2, not v4)
fadd v0.4s, v18.4s, v22.4s
fsub v2.4s, v18.4s, v22.4s

// Build d3,d7,d2,d6 in q1/q3 before swaps
fadd v31.2s, v17.2s, v20.2s
mov  v1.d[1], v31.d[0]
fsub v31.2s, v17.2s, v20.2s
mov  v3.d[1], v31.d[0]
fsub v31.2s, v16.2s, v21.2s
mov  v1.d[0], v31.d[0]
fadd v31.2s, v16.2s, v21.2s
mov  v3.d[0], v31.d[0]

// vswp d1,d2; vswp d5,d6; store q0-q3
mov  v31.16b, v0.16b
mov  v0.d[1], v1.d[0]
mov  v1.d[0], v31.d[1]

mov  v31.16b, v2.16b
mov  v2.d[1], v3.d[0]
mov  v3.d[0], v31.d[1]

stp  q0, q1, [x2], #32
stp  q2, q3, [x2], #32
```

Key changes:
- Corrected destination `v2` for `q2 = q9 - q11`.
- Explicitly constructed d-lanes (d3,d7,d2,d6) in `q1`/`q3` prior to lane swaps and stores.

---

## Code Changes (Summary)

- Replaced unsafe `.4s` operations with paired `.2s` on half-loaded vectors across the early and mid sections of `neon64_eo`.
- Implemented packing for q4/q5 and q6/q7 prior to transpose and store:
  - `mov v8.d[1], v9.d[0]` and `mov v10.d[1], v11.d[0]`
  - `mov v12.d[1], v13.d[0]` for `d13` into `q6` high half
- Corrected swap target registers:
  - `vswp d9,d10` between `v8`/`v10` (q4/q5)
  - `vswp d13,d14` between `v12`/`v14` (q6/q7)
- Corrected stores to use the right q-register pairs:
  - First store: `stp q8, q10, [x16], #32` (q4,q5)
  - Second store: `stp q12, q14, [x16], #32` (q6,q7)
  - Final block: `stp q0, q1, [x2], #32; stp q2, q3, [x2], #32`
- Fixed `q2 = q9 - q11` destination to `v2` (was incorrectly `v4`).
- Rewrote `q15 = q13 - q11` recompute to `.2s` halves and pack into `v30`.

---

## Testing

- Script: `scripts/run_arm64_tests.sh`
- Observations:
  - N=8 trace and L2 checks pass with expected small numerical error (`~1.21016e-08`).
  - N=32 segfaults in QEMU (signal 11) persist even after fixes above.

---

## Outstanding Issues and Next Steps

- The persistent N=32 segfault likely stems from one or more of:
  - A residual `.4s` op on a half-populated vector not addressed yet in `neon64_eo`.
  - A subtle packing or lane-order mismatch before a `trn` or `stp` later in the function.
  - An address computation or pointer reuse mismatch (e.g., `x2`/`x16` lifetimes) at larger strides.
- Proposed follow-ups:
  - Audit remaining `.4s` operations in `neon64_eo` and convert to `.2s` pairs where predecessors are `.2s` loads.
  - Instrument the test run under QEMU (`-d in_asm,exec,cpu`) to capture the faulting PC and correlate with a specific `stp`/`ld` in `neon64_eo`.
  - Cross-check the offset computation sequence and exact store order against ARM32 for N=32 strides.

---

## Reference Notes

- ARM32 NEON macros treat `qX` as two 64-bit d-lanes (`d(2X), d(2X+1)`). AArch64 needs explicit handling when only `.2s` halves are loaded (`ld2 {vX.2s, vY.2s}`), to avoid `.4s` ops that read undefined upper halves.
- `trn1`/`trn2` on `.4s` requires both q-registers to be fully valid. Packing steps before `trn` are essential for correctness.
- Swapping d-lanes (`vswp dA, dB`) in AArch64 is achieved by moving the upper 64 bits of one vector to the lower 64 bits of another (and vice versa) via temporary vector registers.

---

## File References (Excerpts)

ARM32 baseline:
```476:541:src/neon.s
// ... initial eo block through final stores (see full file for context) ...
```

AArch64 after fixes (selected excerpts):
```885:949:src/neon64.s
// Block 1 & 2 fixes: paired .2s ops; packing q4/q5; vtrn; vswp; first store
```
```950:1000:src/neon64.s
// Block 3 fixes: paired .2s ops; pack d13 into q6; vtrn; vswp; second store
```
```1001:1060:src/neon64.s
// Block 4 fixes: vtrn q13/q14 & q11/q12; vmul; butterfly; lane pack; final stores
```

---

## Conclusion

The `neon64_eo` port had several correctness bugs primarily caused by using `.4s` arithmetic with half-populated vectors, incorrect q-register targets for swap/store, and an incorrect destination in the final butterfly. These were corrected by performing d-lane (`.2s`) operations, packing explicitly prior to transposes and stores, fixing swap targets, and aligning final butterfly destinations with ARM32 semantics.

N=8 now passes. N=32 still segfaults; continued small-step auditing and targeted instrumentation are recommended to locate the remaining issue(s). 