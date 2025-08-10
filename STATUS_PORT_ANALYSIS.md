### ARM64 Port Debugging Status

Owner: engineering

This document is updated as we progress through the steps in `PLAN_PORT_ANALYSIS.md`.

---

#### Context
- Build scripts: `build_arm64.sh` (QEMU user-mode test enabled) and `build_arm32.sh` (baseline OK).
- Observed ARM64 run (QEMU max):
  - L2 Error N=8: 1.0
  - L2 Error N=16: 1.224745
  - N=32: Segmentation fault

---

#### 2025-08-09
- Current step: Phase 1 → Tasks (3), (4)
  - Mapped expected ARM64 JIT calling convention vs ARM32:
    - ARM32: r0=out, r1=N/counter, r2=ws, r12=offsets, r3..r10 data ptrs, r11 loop.
    - ARM64 AAPCS64 entry: x0=plan, x1=in, x2=out. Leaf kernels expect x0=out, x1=stride/N? (used as size), x2=ws (ee/e o/oo/oe), x3..x10 in-streams, x11 loop, x12 offsets.
  - Observed in code:
    - `generate_size8_base_case_arm64` now copies [neon64_x8 .. neon64_x8_t) and sign-patches within bounds only.
    - Fixed ARM64 prologue stream-pointer setup: compute x3..x10 from x0 and N using correct ADD (shifted register) encodings via new `arm64_emit_add_shifted_reg` helper.
    - Identified prior illegal instruction 0x8BB0C810 in JIT region as malformed ADD (shifted reg). Replaced raw encodings with helper.
    - Bounded and refactored sign patching to pattern-based FP toggles (bit 23) per blob ranges to avoid corrupting adjacent code.

- Findings/hypotheses:
  - After prologue fix, N=2/4 run; N=8/16 still wrong numerically (expected, sign/layout TBD). N≥32 transitions from SIGILL to SEGV under QEMU, likely due to remaining register setup or loop counter/twiddle pointer misuse entering leaf blobs.

- Next actions:
  1) Re-check leaf entry register map: ensure x2 (ee_ws), x11 (eo/oe twiddles), x12 (offsets), x3..x10 (stream ptrs) match `neon64.s` assumptions when jumping into ee/oo/eo/oe.
  2) Verify loop counter init for leafs: w11 decremented in `neon64.s`; compute from plan `i0/i1` consistent with ARM32. Add temporary prints of first few words of JIT prologue and first leaf to confirm.
  3) Validate data pointer arithmetic before base-case calls (X1 stride) and between subtransform calls (offsets from `pps`).
  4) Re-run N=8/16 (forward/inverse) to recalibrate expected outputs after sign-patch refactor.

---

Checklist
- [x] Tighten x8 blob range and patch
- [x] Implement ARM64 prologue stream pointer setup via helper
- [ ] Ensure x11 loop counter correctness
- [ ] Verify offsets (x12) base loaded from plan
- [ ] Verify x2/x11 twiddle pointers per leaf stage
- [ ] Re-test N=8/16 → L2 error small
- [ ] Re-test N>=32 → no SIGILL/SEGV 

#### 2025-08-09 (cont.)
- Prologue and register mapping parity with ARM32 achieved for ARM64:
  - x0 = out, x19 = plan, x12 = plan->offsets, x3..x10 = input stream pointers derived from x1 with stride N (bytes).
  - x2 is loaded with ee_ws before ee leaves; x11 carries eo/oe twiddle base (no counter re-init for eo/oe).
- Fixed instruction encodings and blob handling:
  - Replaced ad-hoc ADD encodings with `arm64_emit_add_shifted_reg` and corrected LDR immediate encodings (unsigned offset forms for W/X).
  - Bounded/patternized sign patching and kept copies within blob boundaries.
  - Aligned `neon64_oo` to use x12 for offsets and compute two dest addrs into x2/x16; aligned `neon64_oe` to load 32-bit offsets (post #4) and scale addresses by 4 (lsl #2) like ARM32.
- Current behavior:
  - N=8 prints baseline values (still large error, expected until sign/layout finalized).
  - N=16 still incorrect numerically (to be revalidated after sign patch parity).
  - N=32 segfault persists under QEMU; encodings are now sane, so likely an address computation/stride issue when entering first leaf.
- Hypotheses to verify next:
  - Stride source-of-truth: confirm `plan->N` is treated as byte stride for computing x3..x10; ensure no accidental double-scaling.
  - Offsets usage: confirm all leaves use x12 as the advancing 32-bit offsets stream and never clobber it with a destination address.
  - Loop counter/twiddle: ensure x11 used as loop counter only in ee/oo (and as twiddle ptr in eo/oe) matches `neon.s`.
- Next actions (immediate):
  1) Instrument and validate first-iteration addresses for N=32 (x3..x10 loads, computed store addrs) to pinpoint the faulting pointer.
  2) Cross-check stride math versus ARM32: r1-based stream pointers there imply input-base stride; keep ARM64 x1 as input base, x0 as output base.
  3) Re-run N=8/16 forward/inverse after sign patch parity to re-baseline error.

- Checklist updates
  - [x] Tighten x8 blob range and patch
  - [x] Implement ARM64 prologue stream pointer setup via helper
  - [x] Ensure x11 loop counter correctness for ee/oo and twiddle usage for eo/oe
  - [x] Verify offsets (x12) base loaded from plan and used consistently in oo/oe
  - [x] Verify x2/x11 twiddle pointers per leaf stage
  - [ ] Re-test N=8/16 → L2 error small
  - [ ] Re-test N>=32 → no SIGILL/SEGV 

#### 2025-08-09 (cont. 2)
- Root cause for N=8/16 numerical mismatch on ARM64 vs ARM32 identified:
  - Base-case blobs `neon64_x8`/`neon64_x8_t` expect `x0 = data base` and internally compute `x3..x10` from `x0` and stride `x1` (mirrors ARM32). Our ARM64 prologue sets `x0 = out` and `x1 = in`, then we call x8 with `x0` still pointing at `out`. This causes the base-case to read/write using the wrong base pointer, yielding incorrect results for N=8/16.
  - ARM32 path calls base-cases with `r0 = data`, with the final out placement handled by later leaves using δk offsets. ARM64 must mirror this by temporarily mapping `x0 = x1` for base-case calls.
- Planned fix:
  - Before calling/copying x8/x8_t, emit `mov x0, x1`. After base-case returns (or after the inline-copy), restore `mov x0, x2` so leaves still see `x0 = out`.
  - Keep `x1` as stride in bytes (N << 3) as already done. Do not rely on prologue x3..x10 for base-case; blobs recompute them.
  - Re-run N=8/16 after this change; expect L2 error ~1e-8 (per ARM32 baseline).
- Evidence:
  - In `neon64.s`, both `neon64_x8` and `neon64_x8_t` build x3..x10 from `x0` (lines 175–186, 377–387) and use `x1` as stride. Loop uses `x11` and twiddles via `x12`. This matches ARM32 `neon.s` setup (lines 91–101), which always assumed `r0 = data`.
  - Our ARM64 `codegen.c` currently sets stride `x1` correctly and adjusts `x2` (twiddle base), but never maps `x0` to input before base-case calls/inlining.

- Next actions:
  1) Edit `src/codegen.c` ARM64 base-case emission to wrap x8/x8_t with `mov x0, x1` and restore `mov x0, x2`.
  2) Rebuild and test N=8/16 (forward/inverse). Capture L2 errors.
  3) If residual error remains, re-check AArch64 sign flips in x8_t (bit 23) but current toggling covers FADD/FSUB and FMLA/FMLS classes already.

- Checklist updates
  - [x] Tighten x8 blob range and patch
  - [x] Implement ARM64 prologue stream pointer setup via helper
  - [x] Ensure x11 loop counter correctness for ee/oo and twiddle usage for eo/oe
  - [x] Verify offsets (x12) base loaded from plan and used consistently in oo/oe
  - [x] Verify x2/x11 twiddle pointers per leaf stage
  - [x] Diagnose N=8/16 mismatch: base-case called with x0 = out instead of input
  - [ ] Fix base-case call-site mapping (x0 ← x1 before, x0 ← x2 after)
  - [ ] Re-test N=8/16 → L2 error small
  - [ ] Re-test N>=32 → no SIGILL/SEGV 

- Test results after x0 remap fix (QEMU max):
  - Direct N=8 output (sign=-1) now shows structured values, not all-ones error; full L2 check suppressed by segfault later in sweep. Single-size run prints sensible spectrum values, indicating base-case is reading input correctly.
  - Direct N=16 output (sign=-1) shows varied non-pathological values, consistent with corrected input base usage. Need L2 computation path without sweeping to 32.
  - Running the full sweep still segfaults (likely at N=32). Next, limit tests to 2/4/8/16 for L2 reporting or add a size-filter test harness.

- Next actions (short-term):
  1) Add a minimal test mode to `tests/test` to run only specified sizes (e.g., env var or CLI flag) to get L2 errors for 2,4,8,16 without reaching 32.
  2) Investigate N=32 segfault by instrumenting first leaf entry (dump x3..x10, x12-derived addresses, and check δk scaling). 

#### 2025-08-09 (cont. 3)
- Targeted N=8/N=16 correctness work
  - Added focused test modes to `tests/test`:
    - `--l2 <N> <sign>` prints L2 error for a single size/sign without sweeping.
    - `--l2-inplace <N> <sign>` runs in-place to isolate IO effects.
  - ARM32 baseline via `build_arm32.sh` + `qemu-arm`:
    - N=8, sign=-1 → L2 = 1.210162E-08 (good)
  - ARM64 current behavior:
    - N=4, sign=-1 → L2 ≈ 1.145552E-16 (good)
    - N=8, sign=-1 → L2 = 1.000000E+00 (still wrong)
    - Full sweep still segfaults at N≈32 (unchanged for now)

- Changes implemented in ARM64 JIT path (base-case stage):
  - Base-case calling convention
    - Remap `x0` to the input stream for `x4/x8/x8_t` calls; restore `x0` afterwards for leaves (output base).
    - Preserve input base and current input in `x21/x22`; when applying `pps` offset between stages, advance both `x0` (out) and `x22` (current in) to keep remap correct.
  - Twiddle/LUT handling for base-cases
    - Keep `x2` as ws base plus stage offset in bytes using `p->ws_is[]` (mirrors ARM32). Blobs use `x12` internally as an advancing pointer (`ld1 ... [x12], #32`).
    - Confirmed `x1` holds stride in bytes as `N << 3` (8 bytes per complex float); the blob loop count is `(x1 / 32)` as expected.
  - Sign patching scope
    - Restrict runtime FP bit toggling to the inlined `x8_t` range only: copy [neon64_x8_t .. neon64_ee) and toggle there for inverse. Base `x8` remains unpatched. Leaf kernels patching is currently disabled pending parity verification.
  - Prologue parity note
    - `x0 = out`, `x19 = plan`, `x12 = plan->offsets`; `x3..x10` derived from `x1` (input) are for leaves, not used by base-case blobs which recompute from `x0`.

- Hypothesis and focus
  - With calling convention and stage pointer math corrected, the remaining N=8 error likely stems from LUT/sign parity at the base-case stage (x8/x8_t) on ARM64.
  - Next: verify that the generated `p->ws` contents (forward/inverse) match what the AArch64 blobs expect for the first base stage, and that only `x8_t` needs runtime flips for inverse.

- Next actions (immediate)
  1) LUT parity audit: Cross-check `ffts_generate_luts` outputs (p->ws and p->ws_is) vs the load sequence in `neon64_x8`/`neon64_x8_t` (two `ld1 {v2.4s,v3.4s}, [x12], #32` per iteration). Ensure forward/inverse variants match ARM32 behavior exactly at N=8 and N=16.
  2) Instruction-level verification: Confirm our FP sign toggle matches A64 encodings for FADD/FSUB and FMLA/FMLS (bit 23) and is applied only within the `x8_t` copied range. Reference: Arm ARM A64 SIMD&FP encodings [Arm ARM (DDI0600)](https://developer.arm.com/documentation/ddi0600/latest/).
  3) Instrumentation: Temporarily dump the first few words of the twiddle vectors loaded into `v2/v3` in the first base-case iteration, and the first few outputs, to compare against ARM32 for N=8.
  4) Re-run `tests/test --l2 8 -1` and `--l2 16 -1` under QEMU and record L2.

- Checklist updates
  - [x] Add focused L2 test modes to `tests/test`
  - [x] Base-case x0 remap (use input for x4/x8/x8_t; restore after)
  - [x] Advance both out (x0) and current in (x22) with `pps` offset
  - [x] Keep x1 = N<<3 stride; x2 = ws base + stage offset (bytes)
  - [x] Restrict sign patching to `x8_t` copied range only
  - [ ] Verify LUT/sign parity for base-case (x8/x8_t) against ARM32
  - [ ] Instrument and compare first iteration twiddles/results (N=8)
  - [ ] Re-test N=8/16 → L2 small
  - [ ] Fix N≥32 segfault after base-case parity is achieved 

#### 2025-08-10
- Added targeted debug modes in `tests/test` for ARM32/ARM64 parity:
  - `--dump-ws <N> <sign> <stage>` to inspect WS/LUT contents by stage
  - `--base8 <stride_floats> <sign>` to call raw base-case x8 once on synthetic inputs
- Plan: Run on ARM32 vs ARM64 with identical inputs to isolate divergence within x8/x8_t. 