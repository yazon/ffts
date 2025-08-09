# ARM64 Debugging Session Plan

This document outlines the systematic approach for identifying and fixing the **SIGSEGV** observed when running `tests/test` under QEMU after migrating the ARM64 code-generation path to use the hand-written NEON64 assembly blobs.

---

## 1. Reproduce & Capture the Crash

1. Build the ARM64 artefacts (already succeeds):
   ```bash
   ./build_arm64.sh
   ```
2. Re-run the failing test under GDB:  
   ```bash
   gdb --args qemu-aarch64 -cpu max -L /usr/aarch64-linux-gnu tests/test
   (gdb) run
   ```
3. On `SIGSEGV` record:
   * Program Counter (PC)
   * Back-trace (``bt``)
   * A few instructions around PC (``x/8i $pc-8``).

---

## 2. Map the PC to a Blob

1. Dump symbol addresses in the final binary:
   ```bash
   readelf -s build/arm64/tests/test | grep neon64_
   ```
2. Create a table of blob ranges:

   | Symbol           | Start Addr | End Addr | Notes |
   |------------------|------------|----------|-------|
   | `neon64_x4`      |            |          | size-4 kernel |
   | `neon64_x8`      |            |          | size-8 kernel |
   | `neon64_x8_t`    |            |          | 8-pt (twiddle) |
   | `neon64_ee`      |            |          | even-even leaf |
   | `neon64_eo`      |            |          | even-odd leaf  |
   | `neon64_oe`      |            |          | odd-even leaf  |
   | `neon64_oo`      |            |          | odd-odd leaf   |
   | `neon64_end`     |            |          | sentinel |

3. Check which range contains the crashing PC.

---

## 3. Verify Copy Lengths & Alignment

* For each blob copied with `arm64_copy_blob()` ensure:
  * `bytes == symbol_end − symbol_start`.
  * `(*p)` remains **8-byte aligned** after increment (AArch64 ABI).
* Print the pointer before/after each copy (temporary ``printf``) if needed.

---

## 4. Validate Sign-Patch Indices

1. Immediately after patching, dump first ~120 dwords of the blob and make sure bit-21 is toggled only on FCMLA/FMLS instructions.
2. If indices are off:
   * Re-disassemble the blob to find correct instruction positions.
   * Update arrays in `codegen_arm64_macros.h`.

---

## 5. Constants / Register Setup

* Ensure prologue still sets X2 (or other expected regs) to constants/twiddle base.
* Disassemble start of generated transform function, looking for incorrect ADRP/ADD pairs or MOV mishaps.

---

## 6. Callee-Saved Registers

* Verify blobs don’t clobber X19-X30 or callee-saved V8-V15 without saving.
* If they do, extend prologue/epilogue to push/pop affected registers.

---

## 7. Isolate Minimal Failing Size

Run the test with individual FFT sizes to see first failure:
```bash
qemu-aarch64 … tests/test 8
qemu-aarch64 … tests/test 16
```
This narrows focus to the first faulty kernel.

---

## 8. Use QEMU Instruction Trace

```bash
qemu-aarch64 -d in_asm,cpu … tests/test > /tmp/trace.log 2>&1
```
Analyse flow around the faulting address to identify unexpected jumps.

---

## 9. Fix & Iterate

* Apply corrections (copy size, patch indices, extra pushes, etc.).
* Rebuild `./build_arm64.sh`.
* Rerun tests until **all sizes pass** with machine-precision error.

---

## 10. Documentation & Cleanup

* Record root cause and fix in **CHANGELOG.md**.
* Tick related items in **TASKS.md**.
* Remove any temporary debug prints.

---

_This plan should guide the systematic debugging of the current segmentation fault on ARM64._ 