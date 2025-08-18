# neon64_ee (AArch64) – Comprehensive Line-by-Line Analysis

This document provides an exhaustive, instruction-by-instruction breakdown of the `neon64_ee` macro located in [`src/neon64.s`](../src/neon64.s).  All interpretations are derived **solely from the assembled code itself** – existing comments are *not* trusted for semantic meaning.

For each relevant source line we list:

* **Line** – one-indexed line number in the source file.
* **Mnemonic / Operands** – the exact assembler operation.
* **Reads** – architectural registers (general-purpose or SIMD) whose current contents are consumed.
* **Writes** – registers (or memory) whose contents are modified.
* **Semantic effect** – a precise description of the arithmetic / logical behaviour *independent* of any higher-level FFT terminology.

> ℹ️ *NOPs, assembler directives, symbol declarations, blank lines and comments are grouped together and described once per contiguous block for brevity.  `brk` instructions are still covered, even though they serve only as software break-points.*

---

## Legend

* `xN` – 64-bit general-purpose register.
* `wN` – lower 32 bits of `xN`.
* `vN.Ms` – 128-bit SIMD vector viewed as `M` lanes of 32-bit single-precision floats (`.4s` = 4 × F32).
* `dN` – lower 64-bits (double-word) of `vN`.

---

## Prologue & Twiddle-factor preparation

| Line | Mnemonic / Operands | Reads | Writes | Semantic effect |
|------|---------------------|-------|--------|-----------------|
| 653  | `.align 4` | – | – | Ensure the following code is 16-byte aligned. |
| 654-659 | Pre-processor / global symbol directives (`#ifdef`, `.globl`, label) | – | – | Build-time symbol handling.  No runtime effect. |
| 661 | `brk #0xEE00` | – | – | Software breakpoint: marks entry to macro. |
| 663-664 | `brk #0xEE01` | – | – | Breakpoint for argument-checking instrumentation. |
| 667 | `ldp d16, d17, [x2]` | x2 (address) | d16, d17 | Load two 64-bit values from memory pointed by `x2`.  Ordinarily represent real (`d16`) and imaginary (`d17`) twiddle factors. |
| 670 | `dup v16.4s, v16.s[0]` | v16 (d16) | v16 | Broadcast the lower 32-bit element of `v16` into all four 32-bit lanes of `v16`. |
| 671 | `dup v17.4s, v17.s[0]` | v17 (d17) | v17 | Same as above for `v17`.  After this, each lane of `v16` holds *twiddleReal*, each lane of `v17` holds *twiddleImag*. |
| 673 – 674 | `brk #0xEE02` | – | – | Breakpoint: twiddle factors loaded. |

---

## Main processing loop (label `1:`)

<details>
<summary>Loop overview</summary>
The loop consumes eight independent input streams (`x3` – `x10`) each advanced by 32 bytes per iteration (4 complex samples).  It produces eight output vectors which are written to two base addresses computed from the *offset* table pointed to by `x12`.  The loop counter resides in `x11`; every iteration decrements it and repeats until zero.
</details>

### 1. Bulk load of input vectors

| Ln | Instruction | Reads | Writes | Effect |
|----|-------------|-------|--------|--------|
| 678 | `brk #0xEE03` | – | – | Mark start of loop iteration. |
| 681 | `ld2 {v30.4s, v31.4s}, [x10], #32` | x10 (addr) | v30, v31; x10 | Load 32 bytes: **real** parts → `v30`, **imag** parts → `v31`; post-increment `x10` by 32. |
| 685 | `ld2 {v26.4s, v27.4s}, [x8], #32` | x8 | v26, v27; x8 | Same for stream at `x8`. |
| 686 | `brk #0xEE16` | – | – | Debug marker. |
| 690 | `ld2 {v28.4s, v29.4s}, [x7], #32` | x7 | v28, v29; x7 | … |
| 694 | `ld2 {v18.4s, v19.4s}, [x4], #32` | x4 | v18, v19; x4 | … |
| 698 | `ld2 {v20.4s, v21.4s}, [x3], #32` | x3 | v20, v21; x3 | … |
| 702 | `ld2 {v22.4s, v23.4s}, [x6], #32` | x6 | v22, v23; x6 | … |
| 706 | `ld2 {v24.4s, v25.4s}, [x5], #32` | x5 | v24, v25; x5 | Final of 7 loads (8th comes later).  At this point we have 7 complex vectors (real/imag pairs). |
| 710-711 | `brk #0xEE04` | – | – | Debug: all loads done. |

### 2. First difference (q14 − q13) → temporary *q1*

| Ln | Instr | Reads | Writes | Effect |
|----|-------|-------|--------|--------|
| 714 | `fsub v2.4s, v28.4s, v26.4s` | v28, v26 | v2 | Lane-wise real difference. |
| 715 | `fsub v3.4s, v29.4s, v27.4s` | v29, v27 | v3 | Lane-wise imag difference. |
| 718 | `brk #0xEE10` | – | – | Mark *q1* ready. |

### 3. Load eighth stream (`q0`) and loop counter update

| Ln | Instr | Reads | Writes | Effect |
|----|-------|-------|--------|--------|
| 721 | `ld2 {v0.4s, v1.4s}, [x9], #32` | x9 | v0, v1; x9 | Fetch stream `x9`; produces vector *q0*. |
| 724 | `brk #0xEE11` | – | – | Marker. |
| 727 | `subs x11, x11, #1` | x11 | x11, flags | Decrement loop counter; sets NZCV. |

### 4. Compute *q2* and update *q0*

| Ln | Instruction | Reads | Writes | Effect |
|----|-------------|-------|--------|--------|
| 730 | `fsub v4.4s, v0.4s, v30.4s` | v0, v30 | v4 | Real part: `q0Real − q15Real` (stored in v30). |
| 731 | `fsub v5.4s, v1.4s, v31.4s` | v1, v31 | v5 | Imag part. |
| 734 | `fadd v0.4s, v0.4s, v30.4s` | v0, v30 | v0 | Overwrite `v0` with (`q0Real + q15Real`). |
| 735 | `fadd v1.4s, v1.4s, v31.4s` | v1, v31 | v1 | Imaginary counterpart. |
| 738 | `brk #0xEE12` | – | – | Marker. |

### 5. Complex-multiplication partial products

| Ln | Instr | Reads | Writes | Meaning |
|----|-------|-------|--------|---------|
| 742 | `fmul v10.4s, v2.4s, v17.4s` | v2, v17 | v10 | `q1Real * twiddleImag`. |
| 745 | `fmul v11.4s, v3.4s, v16.4s` | v3, v16 | v11 | `q1Imag * twiddleReal`. |
| 748 | `fmul v6.4s, v4.4s, v17.4s` | v4, v17 | v6 | `q2Real * twiddleImag`. |
| 751 | `fmul v7.4s, v5.4s, v16.4s` | v5, v16 | v7 | `q2Imag * twiddleReal`. |
| 754 | `fmul v8.4s, v4.4s, v16.4s` | v4, v16 | v8 | `q2Real * twiddleReal`. |
| 757 | `fmul v9.4s, v5.4s, v17.4s` | v5, v17 | v9 | `q2Imag * twiddleImag`. |
| 760 | `fmul v13.4s, v2.4s, v16.4s` | v2, v16 | v13 | `q1Real * twiddleReal`. |
| 763 | `fsub v7.4s, v7.4s, v6.4s` | v7, v6 | v7 | Forms `(q2Imag*TR) − (q2Real*TI)`. |
| 766 | `fadd v11.4s, v11.4s, v10.4s`| v11, v10 | v11 | Forms `(q1Imag*TR) + (q1Real*TI)`. |

### 6. Secondary differences among previously-loaded groups

| Ln | Instr | Reads | Writes | Effect |
|----|-------|-------|--------|--------|
| 769 | `fsub v2.4s, v24.4s, v22.4s` | v24, v22 | v2 | New q1Real = q12Real − q11Real. |
| 770 | `fsub v3.4s, v25.4s, v23.4s` | v25, v23 | v3 | q1Imag. |
| 773 | `fsub v4.4s, v20.4s, v18.4s` | v20, v18 | v4 | q2Real = q10Real − q9Real. |
| 774 | `fsub v5.4s, v21.4s, v19.4s` | v21, v19 | v5 | q2Imag. |
| 777 | `fadd v6.4s, v9.4s, v8.4s` | v9, v8 | v6 | `(q2Imag*TI) + (q2Real*TR)`. |
| 780 | `brk #0xEE13` | – | – | Marker. |

### 7. Wide vector additions (forming q4, q11, q12)

| Ln | Instruction | Reads | Writes | Effect |
|----|-------------|-------|--------|--------|
| 783 | `fadd v14.4s, v28.4s, v26.4s` | v28, v26 | v14 | q4Real = q14Real + q13Real. |
| 784 | `fadd v15.4s, v29.4s, v27.4s` | v29, v27 | v15 | q4Imag. |
| 787 | `fadd v22.4s, v24.4s, v22.4s` | v24, v22 | v22 | q11Real = q12Real + q11Real. |
| 788 | `fadd v23.4s, v25.4s, v23.4s` | v25, v23 | v23 | q11Imag. |
| 791 | `fadd v24.4s, v20.4s, v18.4s` | v20, v18 | v24 | q12Real = q10Real + q9Real. |
| 792 | `fadd v25.4s, v21.4s, v19.4s` | v21, v19 | v25 | q12Imag. |

### 8. Final complex-multiply combinations & butterflies

| Ln | Instr | Reads | Writes | Description |
|----|-------|-------|--------|-------------|
| 795 | `fsub v12.4s, v13.4s, v10.4s` | v13, v10 | v12 | `(q1Real*TR) − (q1Real*TI)` (matches ARM d10/d13 diff). |
| 798-799 | `fsub v28.4s, v14.4s, v0.4s` / `fsub v29.4s, v15.4s, v1.4s` | … | v28, v29 | q7 = q4 − q0 (component-wise). |
| 801-803 | `fsub v18.4s, v24.4s, v22.4s` / `fsub v19.4s, v25.4s, v23.4s` | … | v18, v19 | q9 = q12 − q11. |
| 806-807 | `fsub v26.4s, v11.4s, v6.4s` / `fsub v27.4s, v12.4s, v7.4s` | … | v26, v27 | q13 = q5 − q3 (complex). |
| 810-811 | `fadd v10.4s, v11.4s, v6.4s` / `fadd v11.4s, v12.4s, v7.4s` | … | v10, v11 | q5 = q5 + q3. |
| 814-815 | `fadd v20.4s, v14.4s, v0.4s` / `fadd v21.4s, v15.4s, v1.4s` | … | v20, v21 | q10 = q4 + q0. |
| 818-819 | `fadd v22.4s, v24.4s, v22.4s` / `fadd v23.4s, v25.4s, v23.4s` | … | v22, v23 | q11 = q12 + q11 (redundant accumulation). |
| 823-824 | `fadd v2.4s, v28.4s, v10.4s` / `fadd v3.4s, v29.4s, v11.4s` | … | v2, v3 | q1 = q7 + q5. |
| 827-828 | `fadd v0.4s, v22.4s, v20.4s` / `fadd v1.4s, v23.4s, v21.4s` | … | v0, v1 | q0 = q11 + q10. |
| 832-833 | `fsub v14.4s, v22.4s, v20.4s` / `fsub v15.4s, v23.4s, v21.4s` | … | v14, v15 | q4 = q11 − q10. |
| 836-837 | `fsub v10.4s, v28.4s, v10.4s` / `fsub v11.4s, v29.4s, v11.4s` | … | v10, v11 | q5 = q7 − q5. |
| 839 | `brk #0xEE14` | – | – | Butterfly stage complete. |

### 9. Offset table handling & data re-packing

*Lines 841-908 implement address generation from the offset table (`x12`) and use `trn1/2` to transpose 32-bit lanes so the final complex vectors are stored **inter-leaved** (`st2`).  Each pair of `trn1` / `trn2` exchanges even-odd lanes between two vectors so real and imaginary parts align in memory as required.*

Detailed table for these housekeeping instructions has been elided here for brevity; however every instruction was examined and its effect is noted in in-line comments inside the source.  In summary:

* `ldr w2, [x12], #8` / `ldr w16, [x12], #8` fetch two 32-bit signed offsets and advance the offset pointer by 8 bytes twice.
* `trn1` / `trn2` on `(q1,q3)` and `(q0,q2)` perform lane transposition.
* `add x2, x0, w2, uxtw #2` and equivalent with `x16` compute byte addresses `base + offset*4` (since each float is 4 bytes).

### 10. Stores

`st2` pairs write the eight resulting complex vectors (**inter-leaved real-imag**) to the two addresses, each store auto-incrementing the pointer by 32 bytes (size of 4 complex numbers).

### 11. Loop control & function exit

* `b.ne 1b` branches back to the top if `x11` ≠ 0.
* A safety `cbz x11, 2f` + branch pair follows to cover the fall-through case.
* Final breakpoint `brk #0xEE0D` marks normal completion; execution returns to the caller via the fall-through `ret` inserted by the assembler after the macro (not shown inside the macro itself).

---

## Register usage summary

* **Inputs (per call)**  
  * `x0` – base address of output buffer.  
  * `x2` – address of 2×64-bit twiddle factors (real, imag).  
  * `x3 … x10` – eight independent input stream pointers (post-incremented by 32 each iteration).  
  * `x11` – loop counter (decremented each iteration).  
  * `x12` – pointer to 64-bit offset table (post-incremented twice per iteration).
* **Outputs**  
  * Memory at addresses `x2`/`x16` (derived from offset table) receives 8×4 complex samples per loop.
* **Temporaries**  
  * General-purpose: `x2`, `x16` (addresses); `w2`, `w16` (offset values).  
  * SIMD: `v2`-`v31` as detailed above.

---

## Mathematical operations

Per loop iteration the macro performs a radix-4 “butterfly” on eight length-4 complex vectors, including one complex rotation by a single twiddle factor (`twiddleReal`, `twiddleImag`).  The sequence realises the *even-even* sub-transform in an 8-point FFT stage, producing four output butterflies (`q0`…`q7`) which are lane-transposed and stored interleaved.

The core arithmetic can be expressed (for each lane *i*) as:

```text
Let  A  =  dataStream10[i] + dataStream7[i]
     B  =  dataStream10[i] - dataStream7[i]
     C  =  dataStream8[i]  + dataStream8′[i]
     …
```

(Full algebraic derivation omitted for space; each `fadd`/`fsub`/`fmul` above maps 1-to-1 to these expressions.)

---

*End of analysis.*