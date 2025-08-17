# N=32 ARM64 Segfault Investigation Log

Date: 2025-08-10
Owner: engineering

## Scope
- Compare ARM32 vs ARM64 behavior for N=32.
- Gather minimal, reproducible evidence without modifying JIT aggressively.
- Keep dynamic path; avoid sweeping sizes; focus on N=32 only.

## What changed in this session
- tests/test:
  - Added `--dump-plan <N> <sign>`: prints `plan.N`, `i0/i1`, `n_luts`, `ws_is[0..]`, and first 16 `(size, off2)` pairs from `plan->offsets`.
  - Added `--dump-plan-32` (ARM64 convenience) to dump same info for N=32.
  - Added `--dump-leaf32` initially intended to capture JIT registers; reverted risky JIT instrumentation; currently not used.
- scripts:
  - `scripts/run_arm32_tests.sh`: now runs `--dump-plan 32 -1` and `--l2 32 -1` after N=8 checks.
  - `scripts/run_arm64_tests.sh`: runs `--dump-plan 32 -1` attempt was replaced by `--dump-plan-32` direct run (size-focused) and tries `--l2 32 -1` (may crash).
- build_arm64.sh:
  - Added `SKIP_QEMU_TEST=1` to skip the internal post-build test sweep.
- src/ffts.c:
  - When `FFTS_DEBUG_LEAF` and N==32: allocate `plan->buf` as scratch (128 bytes) early. Kept benign.
- src/codegen.c:
  - Reverted risky JIT debug prelude; no active JIT instrumentation remains.

## Evidence collected
- ARM32 (baseline) via `--dump-plan 32 -1`:
  - `plan.N=32 i0=1 i1=0 n_luts=2`
  - `ws_is[0..2): 0 4`
  - `offsets` first entries: `[(0,32), (16,48), (24,265), ...]`
  - `--l2 32 -1` ≈ 2.396272E-08 (good)
- ARM64:
  - N=8/16 now correct (L2 ~1e-8) after earlier small-kernel fix.
  - Full sweep in build script crashes; with `SKIP_QEMU_TEST=1`, targeted `--l2 32 -1` still segfaults.
  - Current `--dump-plan-32` direct run segfaulted under QEMU at startup (likely QEMU crash point unrelated to our printing). We will re-trigger via safer execution path in next steps.

## Notes
- Direct JIT-store attempts (x3..x10/x12/off0/off1) were too intrusive and caused QEMU instability. Reverted.
- We’ll proceed with C-only plan metadata comparisons first, then add a single, safe JIT store (x12 only) using existing emit helpers after verifying plan->buf exists.

## Next small steps
1) C-only parity checks (no JIT changes):
   - On ARM64, call `tests/test --dump-plan-32` immediately after startup (no executes). Confirm it prints and matches ARM32 baseline: `n_luts=2`, `ws_is=[0,4]`, first offsets `(0,32),(16,48),(24,265)`. If QEMU still crashes on startup, run `tests/test --dump-plan 32 -1` directly via `qemu-aarch64` (bypassing script) and capture output.
2) If plan metadata matches:
   - Add a minimal JIT prologue store using `ARM64_STR_X_UOFF` helpers to store `x12` to `plan->buf` (address loaded with `ARM64_LDRI_X` helper). No reads from memory, no changes to control flow. Guarded by `FFTS_DEBUG_LEAF` and `N==32`.
   - Add `--dump-leaf32` to execute once and print `x12` (expect equals `plan->offsets`).
3) If `x12` matches, extend by storing `x3` and `x5` only; verify they match `in` and `in + 2*stride` (stride=32*8=256).
4) Only after pointer parity is proven, load a single 32-bit offset from `[x12]` into `plan->buf` and verify equals 32 (first off2 value). This narrows fault domain without entering leaves.
5) If all above match, instrument just before first leaf branch to dump one computed destination address using `x0 + (off<<2)`, and compare against ARM32 expectations.

## Acceptance for next step
- Successful ARM64 print of plan metadata for N=32 that matches ARM32 (`n_luts=2`, `ws_is=[0,4]`, offsets starting `(0,32),(16,48),(24,265)`).
- If matched, one successful run of `--dump-leaf32` printing a non-zero `x12` equal to `plan->offsets`.

## Risks
- QEMU fragility on inline JIT instrumentation; keep emission minimal and use verified helpers only.
- Alignment/imm12 constraints on LDR/STR immediates; rely on `ARM64_LDRI_X` helper where possible. 

## New evidence (with FFTS_NOJIT)
- ARM64 `--dump-plan-32` under QEMU now prints with JIT disabled:
  - plan.N=32 i0=1 i1=0 n_luts=2
  - ws_is[0..2): 0 8
  - offsets first entries: (0,32), (16,48), (0,273), (0,32), (16,48), ...
- ARM32 baseline had ws_is: 0, 4 and offsets starting (0,32), (16,48), (24,265), …

Observations:
- ws_is diverges (ARM64 shows 8 vs ARM32’s 4) for the second LUT index at N=32. This likely explains divergent twiddle base offsets and may underlie the segfault when running JIT at N≥32.
- The third offset pair shows (0,273) on ARM64 vs (24,265) on ARM32, suggesting offset stream construction/parity differs when LUTs are laid out for AArch64 vs ARM32.

Hypothesis:
- Our LUT generation path for ARM64 uses the same code as non-ARM32 (`#else` branch), which packs re/im in split format with V4SF interleaving; ARM32 NEON path adjusts signs differently (`neg`). At N=32, the ws index scaling used later in codegen (`ws_is * 8` bytes) may not match how AArch64 `neon64_x8`/leafs expect to walk `x12`. The difference `ws_is[1]=8` vs `4` indicates a unit mismatch for the second stage LUT base.

## Next steps
1) Validate ws_is units and usage:
   - Audit where `ws_is` is consumed on ARM64: in `src/codegen.c`, `ws_is_bytes = 8 * p->ws_is[...]`. Confirm that AArch64 base-case and leaves expect this scaling at N=32. Compare to ARM32 usage.
2) Make a temporary diagnostic to print computed `ws_is[*]` raw and the byte offsets applied in ARM64 codegen for N=32; confirm mismatch source (generation vs consumption).
3) If the generation is at fault for AArch64, adjust `p->ws_is` computation path for AArch64 to mirror ARM32 semantics at N=32 (most likely halve the second `ws_is` entry when using the AArch64 LUT packing). Gate under `__aarch64__`.
4) After ws_is parity, re-run `--dump-plan-32` and compare offsets pairs again. Expect `(24,265)` to appear as third pair.
5) Only then re-enable JIT and attempt `--l2 32 -1`.

Acceptance for next step:
- ARM64 `--dump-plan-32` shows `ws_is[0..2): 0 4` and first offsets `(0,32),(16,48),(24,265)` matching ARM32. 

## Update after attempted ws_is correction
- Added an AArch64-only temporary correction in LUT generation to halve `ws_is[1]` for N=32, but `--dump-plan-32` still prints `ws_is: 0 8` on ARM64 (unchanged). This indicates either:
  - The correction is not in the right place for the N=32 LUT generation path; or
  - The displayed `ws_is` comes from a different code path/layout (e.g., alternative packing causing index to remain 8 while consumption expects halving during use).

## Next minimal test
- Instead of adjusting generation further, add a temporary ARM64-only consumption correction in codegen (bytes): for N=32, apply `ws_is_bytes = 4 * ws_is[i]` for the second LUT entry only, and re-check `--dump-plan-32` derived offsets by recomputing stage base addresses in a diagnostic print (no JIT). If parity is observed, then move the fix into generation for a permanent solution. 

## Temporary ARM64 consumption correction (runtime toggle)
- Implemented a guarded consumption correction in `src/codegen.c` for ARM64:
  - For N=32 and the second LUT index (ws_index==1), if `FFTS_WSIS_ALT4=1` is set in the environment, use `ws_is_bytes = 4 * ws_is[1]` instead of `8 * ws_is[1]`.
  - This does NOT affect `--dump-plan-32` (which does not run codegen) but allows testing during actual JIT execution.

### How to run the runtime test
- Build (scripts already set up):
  - `SKIP_QEMU_TEST=1 ./scripts/run_arm64_tests.sh` (this preserves `tests/test_arm64`)
- Execute with the toggle (JIT enabled, no FFTS_NOJIT):
  - `FFTS_WSIS_ALT4=1 qemu-aarch64 -cpu max -L /usr/aarch64-linux-gnu tests/test_arm64 --l2 32 -1`

### What to capture
- If the segfault persists:
  - Note crash point remains; the root cause may not be limited to `ws_is` scaling.
- If it runs further or completes:
  - Record L2 for N=32 with `FFTS_WSIS_ALT4=1`.
  - Then disable the toggle and confirm regression to the crash, establishing causality.

### Next (post-toggle) actions
- If the toggle fixes or mitigates the failure:
  - Move the correction into LUT generation (AArch64 path) to produce `ws_is[1]==4` at N=32, and revert codegen consumption to standard `8 * ws_is`.
  - Re-run `--dump-plan-32` (FFTS_NOJIT=1) to confirm `ws_is` parity (0,4) and offsets `(0,32),(16,48),(24,265)`.
  - Re-enable JIT and re-run `--l2 32 -1` without the toggle, expecting no crash and small L2.
- If the toggle does not help:
  - Inspect the offset stream parity (third pair `(24,265)` vs `(0,273)`) in generation code, and instrument codegen to dump the first few computed destination addresses before leaf entry (as previously planned), then compare against ARM32. 

## Latest findings (2025-08-11)

- C plan parity at N=32 is now confirmed on ARM64:
  - ws_is prints as `0 4` (matches ARM32).
  - `plan->offsets` printing corrected to show off2 stream; both ARM32 and ARM64 head is `[0, 32, 16, 48]`.
  - Added `FFTS_DEBUG_OFFSETS=1` to dump raw tmp pairs and final off2; ARM64 equals ARM32 for N=32.
- JIT prelude state verified with early-return diag (`FFTS_DEBUG_LEAF=1`, N=32):
  - Stored x3..x10 (stream pointers); mapping matches `neon64.s` ordering after ARM64 prologue fix.
  - Stored x12 (plan->offsets) and off0/off1; values are sane (off0=0, off1=32).
- Stage twiddle bases verified with `FFTS_DEBUG_STAGE_WS=1`:
  - stage_ws0 = plan.ws
  - stage_ws1 = plan.ws + 32 (ws_is[1]=4 with 8-byte scaling)
- Early-return probes around first leaves (N=32):
  - Before ee leaf: returns L2 = 1.000000E+00 (no crash).
  - After ee leaf: returns L2 ≈ 4.624378E+06 (large error, but no crash).
  - Before oe leaf: returns L2 ≈ 6.983931E+19 (very large error, but no crash).
  - Without guards: segfault persists.

Interpretation:
- C generation and ws_is consumption are correct now for N=32.
- JIT prelude is correct (stream pointers, offsets pointer, stage ws bases).
- Crash occurs within the leaf execution path, most likely at or after the first `oe` leaf. The huge errors when bailing before/after `oe` indicate incorrect math and/or addressing in oe/e* path even when not crashing.

Hypothesis refinement:
- The AArch64 `oe/eo` leaf blobs in `neon64.s` likely expect the LUT pointer in `x12` (as `neon64_x8` does), while current codegen loads LUT for `oe/eo` into `x11`. A mismatched twiddle pointer register could lead to incorrect `LD1`/`ST1` addressing or even segfaults.

New diagnostics and toggles added:
- `FFTS_DEBUG_LEAF=1`: store x3..x10, x12, off0/off1 to `plan->buf` and return early.
- `FFTS_DEBUG_STAGE_WS=1`: store stage0/1 twiddle base addresses at `buf+80`/`+96` and return early.
- `FFTS_RET_BEFORE_EE/FFTS_RET_AFTER_EE/FFTS_RET_BEFORE_OE`: return early around specific leaves to binary-search the failing region.
- `FFTS_DEBUG_EARLY_RETURN_X8T=1`: early return before first x8_t call (did not prevent crash earlier; failure likely earlier in the leaf path).
- New toggle planned/added: `FFTS_OE_WS_IN_X12=1` to mirror LUT pointer from `x11` to `x12` before calling `oe`/`eo` leaf for A/B testing.

Next steps
1) Validate LUT pointer register expectation for `oe`:
   - Under `FFTS_OE_WS_IN_X12=1`, copy `x11` (loaded with `oe_ws`/`eo_ws`) into `x12` immediately before invoking the corresponding leaf.
   - Run `--l2 32 -1` twice (with and without the toggle) and record segfault presence and L2.
2) If the toggle mitigates the crash or reduces the huge error:
   - Adopt `x12` as the LUT register for `oe/eo` leaves in ARM64 codegen permanently.
   - Re-test N=32 end-to-end. If fixed, expand tests to N=64/128.
3) If the toggle does not help:
   - Instrument entry of `oe` leaf (just before branch) to store `x0`/`x22` (data pointers), `x11`/`x12` (twiddle ptrs) and return. If sane, instrument the blob progressively (or wrap around call site) to find the first failing load/store.

Acceptance criteria for the next step
- With `FFTS_OE_WS_IN_X12=1`, ARM64 `--l2 32 -1` runs further or completes without segfault, and L2 significantly improves vs the huge errors observed when returning before/after oe.

--- 

## Findings and probes (2025-08-11, continuation)

- C-only plan parity at N=32 (ARM64 vs ARM32):
  - ws_is: 0 4 (matches ARM32)
  - plan->offsets off2 head: [0, 32, 16, 48]
  - Added `FFTS_DEBUG_OFFSETS=1`: ARM64 raw tmp pairs and final off2 match ARM32
- JIT prelude diagnostics (FFTS_DEBUG_LEAF=1, N=32):
  - x3..x10 stream pointers mapped correctly after prologue fix
  - x12 equals plan->offsets, off0=0, off1=32
- Stage twiddle bases (FFTS_DEBUG_STAGE_WS=1):
  - stage_ws0 = plan.ws
  - stage_ws1 = plan.ws + 32 (ws_is[1]=4, scaled by 8 bytes)
- Leaf boundary probes for N=32:
  - Early return before ee: L2 = 1.000000E+00 (no crash)
  - Early return right after ee: L2 ≈ 4.624378E+06 (large error)
  - Early return before oe: L2 ≈ 6.983931E+19 (very large error)
  - Full run (no early return): segfault persists
- neon64.s mappings (relevant excerpts):
  - neon64_ee: x2=twiddle (ee_ws), x11=loop counter, x12=offsets
  - neon64_oe: x11=twiddle (oe_ws), x12=offsets
- Combined pre-edge snapshots (FFTS_DUMP_PRE_EDGES=1):
  - A(before ee): x0/x22 valid, x12=plan->offsets; x11=4 (bad twiddle pointer)
  - B(before oe): x0=0 x22=0 x2=0 x11=0 x12=0 (registers zeroed)
- Additional attempts:
  - `FFTS_OE_WS_IN_X12=1` (mirror oe/eo LUT into x12): no change (still segfaults)
  - `FFTS_RESET_OFFSETS_X12=1` (reload x12 with plan->offsets pre-oe): no change
  - Post-ee guarded reload (`FFTS_RELOAD_AFTER_EE=1`) to re-establish x12, x11 (oe_ws), x22, stream pointers: B snapshot still zeros; segfault persists
  - After-ee checkpoints:
    - `FFTS_CHECK_AFTER_EE=1` (store marker and return immediately): in simple path, still printed zeros; indicates state loss right after ee
    - `FFTS_SNAP_AFTER_EE=1` (store x0/x22/x2/x11/x12 and return): combined run still shows A sane, B zeros

Interpretation:
- All C-side plan metadata and ARM64 JIT prelude (pointers, offsets, stage ws bases) are correct for N=32.
- The ee leaf execution likely clobbers GPR state beyond expectations (or control flow deviates), resulting in zeroed x0/x22/x2/x11/x12 before oe setup. This explains huge errors when bailing near oe and the segfault when continuing into oe.
- Also, just before ee, x11 was 4 (not a pointer); for oe, neon64.s expects x11 to be the twiddle pointer. We must ensure the proper LUT register is loaded at each call.

Toggles/diagnostics currently available:
- `FFTS_DEBUG_OFFSETS` (C plan offsets raw/final)
- `FFTS_DEBUG_LEAF` (x3..x10/x12/off0/off1 store + early return)
- `FFTS_DEBUG_STAGE_WS` (stage_ws0/stage_ws1 store + early return)
- `FFTS_RET_BEFORE_EE` / `FFTS_RET_AFTER_EE` / `FFTS_RET_BEFORE_OE` (early returns around leaves)
- `FFTS_DEBUG_EARLY_RETURN_X8T` (early return before first x8_t)
- `FFTS_DUMP_PRE_OE` (x0/x22/x2/x11/x12 store + early return before oe)
- `FFTS_DUMP_PRE_EDGES` (combined snapshots A(before ee) and B(before oe) + return)
- `FFTS_OE_WS_IN_X12` (test LUT in x12 for oe/eo)
- `FFTS_RESET_OFFSETS_X12` (reload x12=plan->offsets pre-oe)
- `FFTS_RELOAD_AFTER_EE` (attempt to re-establish regs after ee)
- `FFTS_CHECK_AFTER_EE` / `FFTS_SNAP_AFTER_EE` (post-ee checkpoints)

Refined next steps:
1) Enforce ABI/state across ee:
   - Immediately after `neon64_ee` returns, re-establish the full calling-convention state used by our codegen:
     - x19=plan (already preserved by prologue)
     - x0=out (restore from preserved temp at prologue or re-assign from known value)
     - x21=in base, x22=current in pointer; recompute stream pointers x3..x10 from x21 and N (as in prologue)
     - x12=plan->offsets (reload)
     - For oe: x11=oe_ws (load)
   - Verify with `--dump-pre-edges-32` that B(before oe) snapshot becomes non-zero and matches expectations; then run `--l2 32 -1`.
2) If registers still become zeroed:
   - Instrument `neon64_ee` entry/exit with minimal stores of a marker to `plan->buf` (guarded) to confirm entry/exit reachability and check if the blob itself clears GPRs or deviates control flow (requires careful, minimal edits in neon64.s or only at call sites).
3) Once oe pre-state is sane, ensure x11 twiddle pointer and x12 offsets are valid just before `neon64_oe` and try `--l2 32 -1`.

Acceptance criteria:
- B(before oe) snapshot shows valid, non-zero x0/x22/x2 and correct x11 (oe_ws) and x12 (plan->offsets); then `--l2 32 -1` runs without segfault and yields small L2 (≈1e-8).

--- 

## Assembly macro comparison and ee-trace (2025-08-11)

Findings from incremental ee tracing at N=32 on ARM64:
- EE markers via `neon64.s`:
  - entry=0x1, mid1=0x11, mid2=0x0, exit=0x0 → execution enters ee, progresses past initial LD2/compute, but fails before or at the first ST2 pair.
- A(before ee) snapshot is sane; B(before oe) zeros persist if we let ee return, indicating state loss or fault inside ee.

Likely fault location in `neon64_ee`:
- AArch64 ST2 constraints were violated in the original port near the first stores:
  - ST2 on AArch64 requires consecutive vector registers in the list.
  - ST2 with [reg, #imm] form is not supported; use [reg] with post-index, or precompute the target address in a register.
- The ARM32 `neon_ee` uses `vst2.32 {q0,q1}` / `{q2,q3}` followed by `{q4,q5}` / `{q6,q7}` to two base addresses with post-increment. These are consecutive register pairs and legal addressing.

Adjustments applied in `neon64_ee` (AArch64):
- Ensured consecutive register pairs for ST2 by moving results so that stores use `{v0,v1}`, `{v4,v5}`, `{v8,v9}`, `{v12,v13}`.
- Precomputed x18 = x16 + 32 and x19 = x17 + 32 and used `[x18]`, `[x19]` for the second store pair (no `[reg, #imm]`).
- Kept offsets consumption semantics identical to ARM32: load two 32-bit offsets, compute `addr1 = x0 + off0<<2`, `addr2 = x0 + off1<<2`, then perform two ST2 pairs to those streams per loop iteration.

Reference (ARM32 ee stores):
```395:402:src/neon.s
  vst2.32  {q0, q1}, [r2, :64]!
  vst2.32  {q2, q3}, [lr, :64]!
  vtrn.32  q4,  q6
  vtrn.32  q5,  q7
  vst2.32  {q4, q5}, [r2, :64]!
  vst2.32  {q6, q7}, [lr, :64]!
```

Reference (AArch64 ee stores after fix):
```682:717:src/neon64.s
  mov   v1.16b,  v2.16b
  st2   {v0.4s,  v1.4s},  [x16]
  mov   v5.16b,  v6.16b
  st2   {v4.4s,  v5.4s},  [x17]
  add   x18, x16, #32
  add   x19, x17, #32
  mov   v9.16b,  v10.16b
  st2   {v8.4s,  v9.4s},  [x18]
  mov   v13.16b, v14.16b
  st2   {v12.4s, v13.4s}, [x19]
```

Other notes from comparison:
- Twiddle loads: ARM32 `vld1.32 {d16,d17}, [r2]` vs ARM64 `ld1 {v8.4s}, [x2]` are consistent (v8.2s ≡ d16/d17 lanes).
- Offset handling: both consume two 32-bit offsets per iteration and compute two base addresses from `x0`/`r0`.
- Transpose (vtrn) usage: replicated with TRN1/TRN2 pairs and explicit moves to match ARM32 packing prior to ST2.

Next micro-step:
- Rebuild and re-check ee trace markers; if mid2/exit markers appear, re-run `--l2 32 -1`. If not, add one more trace right before each ST2 and confirm exact faulting store. 

## EE offsets pointer investigation (2025-08-11)

What we changed
- In `src/neon64.s` (`neon64_ee`): load both twiddle halves with `ldp d8, d9, [x2]` (was only loading v8).
- Added minimal, guarded diagnostics inside `neon64_ee`:
  - entry marker (buf+0), mid1 (buf+16), mid2 (buf+24), exit (buf+8)
  - store computed dest addrs x16/x17 to buf+32/+40
  - store loaded `off0/off1` to buf+64/+68
  - snapshot inner x12/x0/x2 to buf+72/+80/+88
  - snapshot entry-time x12 to buf+96
  - peek memory at `[x12]` and `[x12,#4]` into buf+112/+116 right before `ldr w16/w17`

Evidence (N=32, sign=-1)
- Markers: entry=0x1, mid1=0x11, mid2=0, exit=0 → ee enters and progresses, but fails before/at first ST2 pair.
- Computed dest addrs: addr1=addr2=0x400000b003c0 (sane and equal).
- off0/off1 (as loaded by `ldr w16/w17`): 0 / 0.
- Peeked memory at x12 before loads: 0 / 0.
- Inner GPR snapshot (inside ee just before offsets load):
  - inner x12 (offsets ptr) = 0x400000b00ba0
  - plan->offsets (from plan dump) = 0x400000b008c0
  - Δ = 0x2e0 bytes (736), i.e., x12 is advanced by 184 32-bit entries into the offsets stream.
  - inner x0 (out) = 0x400000b003c0, inner x2 (twiddle) non-zero.
- S(after ee) combined snapshot (taken after return path) still zeros, consistent with control/state loss after the fault point.

Interpretation
- Twiddle usage fixed; math progression reaches the offsets-load point.
- The offsets pointer used by ee (`x12`) is advanced to the wrong slice for N=32. The first two 32-bit entries at that slice are 0/0, so both initial stores target the same location (addr1==addr2). This explains the divergence and likely contributes to the segfault.
- ARM32 `neon_ee` expects the offsets head to start with 0 and 32 at N=32; our AArch64 ee is consuming a later slice that begins 0/0.

Next micro-step (runtime A/B confirmation)
- Temporarily reset `x12 = plan->offsets` immediately before calling `neon64_ee` in the ARM64 codegen for N=32 (guarded env toggle, e.g., `FFTS_RESET_OFFSETS_X12=1`).
- Acceptance for this probe:
  - After-ee dump shows peek0/peek1 = 0 / 32 and off0/off1 = 0 / 32.
  - Mid2/exit markers start appearing (ee completes its first stores).
  - `--l2 32 -1` no longer segfaults or shows significantly reduced error.

If confirmed
- Set the correct offsets pointer for ee in `src/codegen.c` AArch64 path (N=32) permanently (align with ARM32 semantics), remove the toggle, and re-test N=32, then N=64/128.

Open items
- Once ee uses the correct offsets slice, re-validate oe/eo entry state and L2. If further issues persist, continue binary search with existing guards around oe. 

## EE offsets pointer investigation (2025-08-12)

What changed since 2025-08-11
- ARM64 JIT callsite (`src/codegen.c`):
  - Reload `x12` from `plan->offsets` immediately before the `ee` leaf (unconditionally).
  - Tried N=32-specific biases for `x12` (-48, -736 bytes) and a dynamic scan for the first `(0,32)` pair; reverted to plain `plan->offsets` after proving these did not select the correct slice reliably.
- `src/neon64.s`:
  - `neon64_ee`:
    - Load both twiddle halves with `ldp d8, d9, [x2]`.
    - Ensure `x12 = plan->offsets` immediately before consuming offsets; move this reload right above the `ldr w16,[x12],#4`/`ldr w17,[x12],#4` pair to eliminate any intervening clobber.
    - Use 32-bit offset loads (`w16`/`w17`) with post-increment by 4 bytes each.
    - Compute second store addresses in GPRs (`add x18, x16, #32`, `add x21, x17, #32`) to avoid `[reg,#imm]` forms that AArch64 `st2` does not support.
    - Ensure stores use consecutive vector regs for `st2` pairs by moving results into `{v0,v1}`, `{v4,v5}`, `{v8,v9}`, `{v12,v13}`.
  - `neon64_oe`:
    - Switch offset loads to 32-bit (`ldr w2,[x12],#4`, `ldr w16,[x12],#4`) and compute addresses with `add x2,x0,w2,uxtw #2` and `add x16,x0,w16,uxtw #2`.
- Tests/diagnostics:
  - Added `--probe-ee32` and `--dump-ee-buf32` CLI paths in `tests/test.c`.
  - `FFTS_DEBUG_BUF=1` now allocates `plan->buf` without altering control flow.

Struct layout verification (AArch64)
- Verified `_ffts_plan_t` layout from `src/ffts_internal.h` (64-bit pointers):
  - `offsets` @ +0 (x19+0) — correct for `ldr x12, [x19]`.
  - `buf` @ +176 bytes (0xB0) — NOT at +256.
- Implication for instrumentation: any `ldr x20, [x19, #256]` used to fetch `buf` inside `neon64.s` is incorrect and risks reading past the struct. For correctness and safety, use `offsetof(struct _ffts_plan_t, buf)` (176) when accessing `plan->buf` from assembly during diagnostics.

Evidence (N=32, sign=-1)
- Plan parity (no JIT): `--dump-plan-32` matches ARM32 after earlier fixes
  - `ws_is: 0 4`, offsets head `[0, 32, 16, 48]`.
- EE-only early-return diagnostics (`--dump-ee-buf32`):
  - With `x12` reload just before the offset loads: peek0/peek1 = 0/0; off0/off1 = 0/0; computed `addr1 == addr2`.
  - With earlier entry-time `x12` (no inner reload), observed peek/off as 48/0; `addr1 = base+0x120`, `addr2 = base`.
  - Combined snapshots still show state loss after ee in the failing path: the pre-`oe` snapshot had zeroed `x0/x22/x2/x11/x12`.
- Twiddle bases validated with `FFTS_DEBUG_STAGE_WS=1`: stage0 = `plan.ws`; stage1 = `plan.ws + 32` (consistent with `ws_is[1]=4` and 8-byte scaling).

Interpretation
- The offsets stream used inside `ee` was provably wrong in earlier runs (advanced by 736 bytes), yielding 0/0 at the slice head or 48/0 depending on where `x12` was reloaded. The correct off2 head for N=32 is `[0, 32, 16, 48]`.
- Forcing `x12 = plan->offsets` immediately before the loads produces 0/0 consumed values, which indicates a mismatch between the expected slice and the immediate reload point, or another pre-load interaction that still disturbs the pointer/stream semantics.
- The `oe` pre-state appears corrupted (registers zeroed) if we let `ee` run to its failing point, consistent with an in-leaf fault or ABI/state clobber inside `ee`.
- Additionally, we confirmed a separate issue in the diagnostic paths: some assembly diagnostics referenced `plan->buf` at +256, which is incorrect on AArch64 (actual is +176). This can invalidate toggles or cause unintended memory writes during diag.

Conclusions
- `ldr x12, [x19]` is correct for `plan->offsets`.
- Some `neon64.s` diagnostics must switch to `buf` at +176 to be trustworthy.
- The AArch64 `ee`/`oe` port remains suspect around offset consumption and store address computation, even after fixing `st2` constraints and offset width/scale.
- Pre-`oe` state loss strongly suggests `ee` still clobbers GPRs or faults mid-store.

Next steps
1) Fix diagnostics to use the correct `buf` offset (+176) in `neon64.s` (guarded) to avoid reading past the struct and to make toggles reliable.
2) Immediately re-validate `--dump-ee-buf32` with the corrected `buf` offset:
   - Expect peek/off = 0/32 and `addr1 != addr2` when `x12` is properly aligned to the off2 head.
3) Enforce and verify full calling-convention state across `ee` before setting up `oe`:
   - Restore `x0/x22/x2`, reload `x12 = plan->offsets`, and load `x11 = oe_ws` after `ee` returns.
   - Confirm with a `before-oe` snapshot that these are non-zero and correct.
4) If pre-`oe` state is sane, re-run `--l2 32 -1`. If crash persists, instrument the first `st2` sites in `ee` to pinpoint the exact failing store.

Acceptance
- Diagnostics access `plan->buf` via +176 and produce consistent dumps.
- `before-oe` snapshot shows valid `x0/x22/x2/x11/x12`.
- `--l2 32 -1` for N=32 completes without segfault and returns small L2 (≈1e-8). 