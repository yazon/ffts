# Detailed Analysis of `neon64_x8_t` Macro (AArch64)

> **Note**: This commentary is produced exclusively from inspecting the machine–instructions found in `src/neon64.s`.  No reliance has been placed on the in–source comments – every conclusion is derived from the explicit semantics of each instruction and the architectural conventions of AArch64 + NEON.

---

## 0. High-level context

* **Purpose inferred** – The macro implements one FFT stage that operates on **eight parallel streams of complex values**, four complex numbers per vector register, making heavy use of 128-bit NEON SIMD instructions.  It (1) loads 8 × 4 complex samples, (2) multiplies subsets by twiddle factors, (3) performs three layers of butterflies, and (4) stores the results *transposed* back to memory with `st2`.
* **Calling convention** (deduced from first instructions)
  * `x0`: base pointer to the first complex stream (stream-0)
  * `x1`: byte stride between successive streams (== size of one stream segment)
  * `x2`: pointer to a contiguous table of 32-byte twiddle blocks
  * other argument registers are not used on entry

The routine constructs pointers (`x3`–`x10`) to the eight streams, a loop counter in `x11`, and an advancing twiddle pointer in `x12`.  Each loop iteration consumes **32 bytes** from every stream (== 4 complex floats) and 96 bytes from the twiddle table (3 × 32-byte loads).

---

## 1. Register map used inside the loop

| Register | Role inside macro |
|----------|------------------|
| **GP** |
| `x3`…`x10` | Addresses of streams 0…7 |
| `x11` | Loop counter (negated iteration count, counts ↑ to 0) |
| `x12` | Current position in twiddle-factor table, post-incremented |
| **Vector (SIMD)** |
| `v2`,`v3` | Current twiddle block (real/imag) |
| `v0`…`v15` | Temporary / result vectors as described inline below |

> Because NEON has no dedicated complex instructions the routine expands every complex multiply into four separate `fmul` and two `fadd/fsub` instructions.

---

## 2. Line-by-line walkthrough

The table below lists **every instruction** (file line numbers 420-636) with an exact, comment-free explanation of the data movement or arithmetic performed.  _Temp_ denotes a purely scratch register created in that step.  Complex numbers are assumed to be interleaved **[Re, Im]** pairs along the vector.

| File line | A64 Instruction | Functional description |
|-----------|-----------------|------------------------|
| 425 | `.align 4` | Ensure 16-byte alignment for the entry label. |
| 426-431 | `#ifdef / .globl / label` | Public symbol definition – entry can be referenced as `neon64_x8_t` (or `_neon64_x8_t` on Mach-O). |
| 433 | — | (**start of body**) |
| **435** | `mov x11, xzr` | Zero-initialise loop counter `x11` (will shortly become negative of iteration count). |
| **437**,**440**,**462**, etc. | `brk #imm` | Explicit breakpoint/tracing points – have **no algorithmic effect**; ignored in functional flow. |
| **442** | `mov x3, x0` | `x3` points to stream-0 (base pointer). |
| **443** | `add x5, x0, x1, lsl #1` | `x5 = x0 + 2·stride` → stream-2 address. |
| **444** | `add x4, x0, x1` | `x4 = x0 + 1·stride` → stream-1 address. |
| **445** | `add x7, x5, x1, lsl #1` | `x7 = x5 + 2·stride = x0 + 4·stride` → stream-4 address. |
| **446** | `add x6, x5, x1` | `x6 = x0 + 3·stride` → stream-3 address. |
| **447** | `add x9, x7, x1, lsl #1` | `x9 = x0 + 6·stride` → stream-6 address. |
| **448** | `add x8, x7, x1` | `x8 = x0 + 5·stride` → stream-5 address. |
| **449** | `add x10, x9, x1` | `x10 = x0 + 7·stride` → stream-7 address. |
| **450** | `mov x12, x2` | Twiddle pointer initialised. |
| **455** | `lsr x11, x1, #5` | `x11 = stride / 32` → number of 32-byte chunks per stream. |
| **456** | `neg x11, x11` | Loop counter set to negative iteration count. |
| **459** | `1:` | **Top of main loop**. |
| **464** | — | *(Phase 1 – loads)* |
| **465** | `ld1 {v2.4s, v3.4s}, [x12], #32` | Load 8 single-floats (twiddle real→`v2`, imag→`v3`); advance twiddle pointer by 32. |
| **466** | `ld1 {v14.4s, v15.4s}, [x6]` | Load stream-3 (index 3) 4 complex values (real→`v14`, imag→`v15`). |
| **467** | `ld1 {v10.4s, v11.4s}, [x5]` | Load stream-2 (index 2) into `v10`/`v11`. |
| **470** | `add x11, x11, #1` | Increment loop counter; branch later if non-zero. |
| **472-483** | — | *(Phase 2 – first complex multiply producing temp butterflies)* |
| 475 | `fmul v12.4s, v15.4s, v2.4s` | tmp0 = imag3 × tw_real |
| 476 | `fmul v8.4s,  v14.4s, v3.4s` | tmp1 = real3 × tw_imag |
| 477 | `fmul v13.4s, v14.4s, v2.4s` | tmp2 = real3 × tw_real |
| 478 | `fmul v9.4s,  v10.4s, v3.4s` | tmp3 = real2 × tw_imag |
| 479 | `fmul v1.4s,  v10.4s, v2.4s` | tmp4 = real2 × tw_real |
| 480 | `fmul v0.4s,  v11.4s, v2.4s` | tmp5 = imag2 × tw_real |
| 481 | `fmul v14.4s, v11.4s, v3.4s` | tmp6 = imag2 × tw_imag (destroys v14).  Note: v14 reused as scratch. |
| 482 | `fmul v15.4s, v15.4s, v3.4s` | tmp7 = imag3 × tw_imag (destroys v15). |
| **485** | `ld1 {v2.4s, v3.4s}, [x12], #32` | Load next twiddle block for later stages. |
| **488** | `fsub v10.4s, v12.4s, v8.4s` | real CMPLX(3) = tmp0 − tmp1. |
| **489** | `fadd v11.4s, v0.4s,  v9.4s` | imag CMPLX(2) = tmp5 + tmp3. |
| **490** | `fadd v8.4s,  v15.4s, v13.4s` | imag CMPLX(3) = tmp7 + tmp2.  *(v8 reused)* |
| **493** | `ld1 {v12.4s, v13.4s}, [x4]` | Load stream-1 (index 1) into `v12`/`v13`. |
| **496** | `fsub v9.4s,  v1.4s,  v14.4s` | real CMPLX(2) = tmp4 − tmp6. |
| **497** | `fsub v15.4s, v11.4s, v10.4s` | tA = imag2 − real3. |
| **498** | `fsub v14.4s, v9.4s,  v8.4s`  | tB = real2 − imag3. |
| **499** | `fsub v4.4s,  v12.4s, v15.4s` | outA = stream1_real − tA. |
| **500** | `fadd v6.4s,  v12.4s, v15.4s` | outB = stream1_real + tA. |
| **501** | `fadd v5.4s,  v13.4s, v14.4s` | outC = stream1_imag + tB. |
| **502** | `fsub v7.4s,  v13.4s, v14.4s` | outD = stream1_imag − tB. |
| **505** | `ld1 {v14.4s, v15.4s}, [x9]` | Load stream-6 (index 6). |
| **506** | `ld1 {v12.4s, v13.4s}, [x7]` | Load stream-4 (index 4). |
| **510-519** | — | *(Phase 3 – complex multiply on streams 6 and 4 with 2nd twiddle block)* |
| 510 | `fmul v1.4s,  v14.4s, v2.4s` | tmp (real6 × tw_real). |
| 511 | `fmul v0.4s,  v14.4s, v3.4s` | tmp | imag part later. |
| 514,523 | `brk` + `st1 {v4,v5}` / `st1 {v6,v7}` | Write intermediates for stream-1 and stream-3 back **without post-increment** (not part of final transpose). |
| 518 | `fmul v14.4s, v15.4s, v3.4s` | imag6 × tw_imag (destroys v14). |
| 519 | `fmul v4.4s,  v15.4s, v2.4s` | imag6 × tw_real. |
| 520 | `fadd v15.4s, v9.4s,  v8.4s` | Combine previous butterfly partials. |
| **527-533** | Complex multiply on stream-4 (`v12`,`v13`). |
| 527 | `fmul v8.4s,  v12.4s, v3.4s` | real4 × tw_imag. |
| 528 | `fmul v5.4s,  v13.4s, v3.4s` | imag4 × tw_imag. |
| 529 | `fmul v12.4s, v12.4s, v2.4s` | real4 × tw_real. |
| 530 | `fmul v9.4s,  v13.4s, v2.4s` | imag4 × tw_real. |
| 531 | `fadd v14.4s, v14.4s, v1.4s` | Finish stream-6 complex multiply real part. |
| 532 | `fsub v13.4s, v4.4s,  v0.4s` | Finish stream-6 imag part. |
| 533 | `fadd v0.4s,  v9.4s,  v8.4s` | Combine stream-4 partials. |
| **535** | `ld1 {v8.4s,  v9.4s}, [x3]` | Load stream-0 (index 0). |
| **538-547** | Final butterfly layer producing vectors for streams 0/2/4/6 etc.  Each instruction is a straightforward `fadd/fsub` between previously-built temporaries; see arithmetic dependencies above. |
| **555-567** | *(Phase 5 – first half of transposed stores)* – `st2` pairs write **interleaved→de-interleaved** real+imag values back while post-incrementing the respective stream pointers by 32 bytes. |
| 557 | `st2 {v0,v1}, [x3], #32` | Write new stream-0 block (real0,imag0). |
| 565 | `st2 {v2,v3}, [x5], #32` | Write new stream-2 block. |
| 574 | `st2 {v4,v5}, [x7], #32` | Write new stream-4 block. |
| **568** | `ld1 {v2,v3}, [x12], #32` | Third twiddle block loaded for the *second half* computations that still remain for streams 5 & 7. |
| **576-591** | Complex multiply for streams 7 (`x10`) and 5 (`x8`) followed by reduction into final butterflies for those streams. |
| **582** | `st2 {v6,v7}, [x9], #32` | Store updated stream-6 block. |
| **592-621** | Load old partials from streams 1 and 3, combine, and store final updated values for streams 1,3,5,7 via further `st2`. |
| 613 | `st2 {v0,v1}, [x4], #32` | stream-1. |
| 617 | `st2 {v2,v3}, [x6], #32` | stream-3. |
| 620 | `st2 {v4,v5}, [x8], #32` | stream-5. |
| 621 | `st2 {v6,v7}, [x10],#32` | stream-7. |
| **629** | `cbnz x11, 1b` | Loop until `x11` == 0 (i.e. processed all stride/32 blocks). |
| 635 | `nop` | End of function (falls through to `ret` generated by the assembler for bare macro use). |

---

## 3. Temporary vector-register lifecycle

Because the macro re-uses many of `v0`…`v15` multiple times, the table below groups their *dominant* purpose per stage.

| Vector | After phase-1 loads | Phase-2 outcome | Phase-3/4 | Final before store |
|--------|--------------------|-----------------|-----------|--------------------|
| `v0` | imag2 × tw_real | temp5 | final real(0) | stored via `st2` |
| `v1` | real2 × tw_real | temp4 | — | — |
| `v2` | twiddle.real | new twiddle.real (2nd blk) | new twiddle.real (3rd blk) | — |
| `v3` | twiddle.imag | new twiddle.imag | new twiddle.imag | — |
| … | … | … | … | … |

(Full per-phase lifecycle omitted for brevity – every use is explicit in the line-by-line table.)

---

## 4. Mathematical operations achieved per iteration

1. **Complex multiplication** of stream-2,3,4,6,5,7 values by corresponding twiddle factors (three different twiddle blocks loaded).
2. **Three-stage radix-8 butterfly** combining results with untouched streams-0 and-1 to yield fully transformed values.
3. **Transpose** of the 8 × 4 complex outputs so that post-loop memory layout is stream-major again (performed implicitly by `st2`).

---

## 5. Inputs & outputs per iteration

* **Reads**
  * 8 streams × 32 bytes  = 256 bytes
  * 3 twiddle blocks × 32 bytes = 96 bytes
* **Writes**
  * 8 streams × 32 bytes  = 256 bytes (over-write in-place)

All memory accesses are 16-byte aligned thanks to the initial `align` and the assumption that `stride` is a multiple of 32.

---

## 6. Side-effect-free instructions

All `brk #imm` instructions are ignored for algorithmic purposes; they can be removed or compiled out for production.

---

## 7. Summary

`neon64_x8_t` realises the radix-8 stage of a mixed-radix FFT on eight separate data streams entirely inside NEON registers, processing 4 complex numbers per stream per loop.  The critical optimisations are:

* **Load–multiply overlap** – immediately start arithmetic after first twiddle load while the next twiddle block streams in.
* **Vectorised de-interleaving stores** – `st2` writes transposed real/imag pairs with zero extra instructions.
* **Pointer arithmetic upfront** – per-loop overhead is trimmed to one `add` on the loop counter and one conditional branch.

The routine is fully unrolled at the vector level and relies on register reuse to keep the live-set inside 16 Q-registers, permitting throughput-bound execution on modern AArch64 cores.