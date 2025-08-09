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
    - `generate_size8_base_case_arm64` previously copied [neon64_x8 .. neon64_ee), which includes extra blobs beyond x8_t; risk of falling into unmapped code or patch mismatch.
    - Fixed x8 copy to [neon64_x8 .. neon64_ee) with explicit patching of x8_t, but we will tighten to [neon64_x8 .. neon64_x8_t) for correctness in next edit.
    - ARM64 prologue currently saves regs but DOES NOT set x3..x10, x12 (offsets), x0 (out), x2 (twiddle), x11 (loop). This explains bogus results for small sizes and crash when branching into leafs.

- Findings/hypotheses:
  - Wrong registers passed to blobs (ee/oo/e o/oe) likely cause large errors (N=8/16) and crash at first larger recursive call (N=32).
  - Sign flip indices exist for ARM64 in `codegen_arm64_macros.h`, but correctness depends on copying the exact intended range.

- Next actions:
  1) Edit `arm64-codegen.c`:
     - x8 base-case: copy [neon64_x8 .. neon64_x8_t) and then independently patch x8_t when used (or adjust caller to place x8_t immediately after and branch safely).
     - Implement a fuller ARM64 prologue in `generate_prologue_arm64` or in `codegen_arm64.h` `generate_prologue_arm64` wrapper: compute x3..x10 from x1 and N; set x12 to plan->offsets; move x2→x0 (out); keep plan in x19; set up x11 loop for leafs.
  2) Edit `codegen.c` ARM64 path to actually materialize the above register setup before emitting leaf blobs (mirroring the ARM32 prologue ADDI/MOVI/LDRI flow).
  3) Re-run tests N=8,16 to check L2 error.

---

Checklist
- [ ] Tighten x8 blob range and patch
- [ ] Implement ARM64 prologue register setup parity
- [ ] Ensure x11 loop counter correctness
- [ ] Verify offsets (x12) base loaded from plan
- [ ] Verify x2 points to correct ws per leaf stage
- [ ] Re-test N=8/16 → L2 error small
- [ ] Re-test N>=32 → no SIGSEGV 