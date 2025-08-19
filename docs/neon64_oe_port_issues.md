### AArch64 `neon64_oe` vs ARM32 `neon_oe`: Defects and Mismatches

This report enumerates correctness bugs, ordering inconsistencies, and design flaws in `src/neon64.s` (`neon64_oe`) by direct comparison to the ARM32 reference in `src/neon.s` (`neon_oe`). The analysis relies solely on instructions and their semantics, not on in-source comments.

References:
- ARM32 source slice: `src/neon.s` lines 557–627
- ARM64 source slice: `src/neon64.s` lines 1336–1706

---

### 1) First transpose-store (q0/q1) is incomplete (only half updated)

ARM32 performs two full-vector transposes then stores:

```581:600:src/neon.s
vtrn.32  q0,  q12
vtrn.32  q1,  q13
vld1.32  {d24, d25}, [r11, :64]
vswp     d1, d2
vst1.32  {q0,  q1},  [r2, :64]!
```

ARM64 only writes back the low 64-bit half for `v0` and `v1` after `trn1`/`trn2`, leaving their high halves stale:

```1475:1492:src/neon64.s
mov     v12.d[0], v24.d[0]
mov     v12.d[1], v25.d[0]
trn1    v16.4s, v0.4s, v12.4s
trn2    v12.4s, v0.4s, v12.4s
mov     v0.d[0], v16.d[0]            // v0.d[1] NOT updated
...
trn1    v16.4s, v1.4s, v13.4s
trn2    v13.4s, v1.4s, v13.4s
mov     v1.d[0], v16.d[0]            // v1.d[1] NOT updated
```

Impact: The subsequent `st2 {v0.4s, v1.4s}` writes incorrect 32-bit elements for the upper 64-bit halves. This diverges from the ARM32 `vtrn.32 q0,q12` and `vtrn.32 q1,q13` semantics which update both halves.

Recommended fix:
- After each transpose pair, copy the full result into the destination, e.g.:
  - `trn1 v31.4s, v0.4s, v12.4s; trn2 v12.4s, v0.4s, v12.4s; mov v0.16b, v31.16b`
  - `trn1 v31.4s, v1.4s, v13.4s; trn2 v13.4s, v1.4s, v13.4s; mov v1.16b, v31.16b`

Additionally, the store pattern differs:

- ARM32 uses a contiguous store `vst1.32 {q0, q1}, [r2, :64]!` (no interleaving).
- ARM64 uses `st2 {v0.4s, v1.4s}, [x2], #32` (interleaving).

Impact: The interleaved store is not byte-equivalent to the ARM32 contiguous store, even if the transpose was correct. This can corrupt the expected memory layout for downstream stages.

Recommended fix:
- Use a pair of contiguous stores to match ARM32. Example: `stp q0, q1, [x2], #32` (twice if needed), or `str q0, [x2], #16; str q1, [x2], #16`.

---

### 2) Clobbering of v31 breaks later use as data

`v31` holds data loaded here:

```1370:1373:src/neon64.s
ld2     {v30.4s, v31.4s}, [x10], #32
```

Later it is reused as a scratch during the first store preparation:

```1502:1506:src/neon64.s
orr     v31.16b, v0.16b, v0.16b
mov     v0.d[1], v1.d[0]
mov     v1.d[0], v31.d[1]
```

but then referenced again as if it still contained the data from the earlier load:

```1525:1527:src/neon64.s
fadd    v2.4s, v0.4s, v30.4s
fadd    v3.4s, v1.4s, v31.4s   // uses v31 as if it were still loaded data
```

Impact: `v31` no longer holds the deinterleaved stream from `[x10]` when used in 1526–1527, producing incorrect results.

Recommended fix:
- Do not use `v31` as a scratch before all uses as data are complete. Use another temporary (e.g., `v16` at this point) for half-swaps at 1502–1506.

---

### 3) Wrong source registers used in twiddle multiplication phase

ARM32 multiplies only q8–q11 (d16–d23 and d20–d21) after transposing them:

```603:616:src/neon.s
vtrn.32  q11, q9
vtrn.32  q10, q8
vmul.f32 d20, d18, d25
vmul.f32 d22, d19, d24
vmul.f32 d21, d19, d25
vmul.f32 d18, d18, d24
vmul.f32 d19, d16, d25
vmul.f32 d30, d17, d24
vmul.f32 d23, d16, d24
vmul.f32 d24, d17, d25
```

ARM64 performs the pre-transpose, but the multiplies then use `v6/v7` and `v4/v5` (which correspond to earlier q3/q2 paths), not the re-paired q8–q11 values:

```1608:1620:src/neon64.s
trn1/2 on (v22,v18), (v23,v19), (v20,v16), (v21,v17)  // re-pair q11,q9 and q10,q8
```

```1625:1638:src/neon64.s
fmul    v20.4s, v6.4s, v25.4s
fmul    v22.4s, v7.4s, v24.4s
fmul    v21.4s, v7.4s, v25.4s
fmul    v18.4s, v6.4s, v24.4s
fmul    v19.4s, v4.4s, v25.4s
fmul    v30.4s, v5.4s, v24.4s
fmul    v23.4s, v4.4s, v24.4s
fmul    v24.4s, v5.4s, v25.4s
```

Impact: Complex multiplication is performed on the wrong vectors (q2/q3 instead of q8–q11), producing incorrect twiddled results.

Recommended fix:
- Use the re-paired vectors from 1608–1620 as sources, mirroring ARM32’s d16–d23, d20–d21 mapping. For example:
  - Replace uses of `v6/v7` with the appropriate `v18/v19` or `v16/v17` depending on real/imag mapping, and replace uses of `v4/v5` with `v22/v23` or `v20/v21` accordingly.

---

### 4) Potentially incorrect twiddle broadcast width

ARM32 loads twiddles into `d24`/`d25` and uses them in `vmul.f32` at d-width, which implies both 32-bit lanes of each `d` element are equal. ARM64 does:

```1494:1499:src/neon64.s
ldp     d24, d25, [x11]
dup     v24.2d, v24.d[0]
dup     v25.2d, v25.d[0]
```

Impact: `dup .2d` replicates the entire 64-bit doubleword, preserving both 32-bit sub-lanes. If only the low 32-bit element is valid (typical), the result across `.4s` lanes becomes `[s0, s1, s0, s1]` instead of `[s0, s0, s0, s0]`, breaking lane-wise `fmul .4s` equivalence.

Recommended fix:
- Broadcast from the low 32-bit lane: `dup v24.4s, v24.s[0]` and `dup v25.4s, v25.s[0]`.

---

### 5) Use of an uninitialized vector (v15) before it is defined

ARM64 computes with `v15` before any prior definition in this routine:

```1668:1671:src/neon64.s
fadd    v8.4s,  v14.4s, v18.4s
fadd    v9.4s,  v15.4s, v19.4s   // v15 used here
fsub    v12.4s, v14.4s, v18.4s
fsub    v13.4s, v15.4s, v19.4s   // v15 used here
```

The first definition of `v15` occurs later:

```1675:1681:src/neon64.s
fadd    v11.4s, v27.4s, v16.4s
fsub    v15.4s, v27.4s, v16.4s   // v15 defined here, after prior use
```

Impact: Use-before-def leads to undefined results in `v9` and `v13`.

Recommended fix:
- Reorder definitions so that `v15` is computed before any use; mirror ARM32 ordering (where d9/d10 swaps occur only after the dependent arithmetic is complete).

---

### 6) Final stores: whole-vector swaps vs 64-bit half swaps

ARM32 does two 64-bit lane swaps before a contiguous store of `q4–q7`:

```621:627:src/neon.s
vadd.f32 d11, d27, d16
vsub.f32 d15, d27, d16
vsub.f32 d10, d26, d17
vadd.f32 d14, d26, d17
vswp     d9,  d10
vswp     d13, d14
vstmia   lr!, {q4-q7}
```

ARM64 swaps entire 128-bit vectors and then uses interleaved stores:

```1691:1703:src/neon64.s
st2 {v8.4s,  v9.4s},  [x14], #32
orr     v31.16b, v10.16b, v10.16b
mov     v10.16b,  v11.16b
mov     v11.16b,  v31.16b
st2 {v10.4s, v11.4s}, [x14], #32
st2 {v12.4s, v13.4s}, [x14], #32
orr     v31.16b, v14.16b, v14.16b
mov     v14.16b,  v15.16b
mov     v15.16b,  v31.16b
st2 {v14.4s, v15.4s}, [x14], #32
```

Impact: Whole-vector swaps are not equivalent to the ARM32 half-swaps (`vswp d9,d10` and `vswp d13,d14`). The change to `st2` stores also implies a different memory layout unless carefully proven equivalent.

Recommended fix:
- Implement 64-bit lane swaps on the specific pairs and then either:
  - Retain a contiguous store equivalent to `vstmia lr!, {q4-q7}` using `stp qX, qY` pairs, or
  - Carefully derive an equivalent `st2` sequence that preserves the byte-exact layout expected by later stages.

Also ensure the earlier `st2 {v2.4s, v3.4s}, [x2], #32` (1597) that mirrors ARM32’s `vst1.32 {q2, q3}, [r2, :64]!` is replaced with a byte-equivalent contiguous store.

---

### 7) Minor ordering and redundancy issues

- Redundant duplicate computations:
  - `fsub v17.4s, v10.4s, v12.4s` (1437) duplicates `v16 = v10 - v12` (1436). If both d-halves are needed separately later, construct just the required halves.

- Address computation ordering differences (1431/1440 vs ARM32 571/573) are benign provided no hazards exist; they do not appear to affect correctness.

---

### Summary of critical fixes to reach ARM32 parity

1. Fully write back both halves for `v0` and `v1` in the first `vtrn.32` group.
2. Avoid clobbering `v31` before all its data-uses complete (or stop using it as a data register entirely in this routine).
3. Use the correct source vectors (re-paired q8–q11) for the twiddle multiplications.
4. Broadcast twiddles with `dup .4s, s[0]` instead of `dup .2d`.
5. Define `v15` before any use; correct the operation order accordingly.
6. Replace final whole-vector swaps with precise 64-bit lane swaps and verify store layout equivalence with ARM32.

These changes address correctness mismatches against the ARM32 `neon_oe` and should restore functional equivalence for the OE leaf on AArch64.

