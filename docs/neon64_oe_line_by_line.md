### AArch64 Instruction-by-Instruction Analysis: `neon64_oe` in `src/neon64.s`

This document provides a precise, line-by-line explanation of every assembler directive, label, and instruction from the entry of `neon64_oe` up to (but not including) the `neon64_end` label. Explanations are based solely on AArch64 instruction semantics; in-source comments are not used as ground truth.

Scope of analysis: lines 1336–1706 in `src/neon64.s` (current revision).

---

#### Calling-context assumptions (deduced from usage)

- General-purpose registers:
  - **x0**: base output pointer used to compute two output stream pointers via offsets.
  - **x12**: pointer to a 32-bit offsets stream; two 32-bit elements are consumed with post-increment.
  - **x11**: pointer to a table of twiddle factors (loaded as 64-bit halves, then replicated).
  - **x2**: becomes the first computed output pointer (`x0 + ((uint32_t)off0 << 2)`); used as a store cursor.
  - **x14**: becomes the second computed output pointer (`x0 + ((uint32_t)off1 << 2)`); used as a store cursor.
  - **x3, x4, x5, x6, x7, x8, x9, x10**: input stream pointers read via vector loads; advanced by post-increment.

- SIMD/FP registers:
  - **v0–v31** are used. Notable conventions within this routine:
    - v22/v23, v26/v27, v30/v31, and later v0/v1, v26/v27, v28/v29 are populated by `ld2` (deinterleaving) loads.
    - v8, v10 are populated by `ldr q...` loads (16-byte loads).
    - v24, v25 are loaded as `d` scalars and replicated across lanes; used as twiddle constants.
    - **v31** is repeatedly used as a scratch (temporary) vector for copies/swaps/transposes.

---

### Line-by-line

- 1336: `.align 4`
  - Aligns subsequent code on a 16-byte boundary. No runtime effect.

- 1338–1343: symbol export and label
  - `.globl _neon64_oe` / `.globl neon64_oe` and the corresponding label (`_neon64_oe:` or `neon64_oe:`) define the externally visible entry point depending on platform macros.

- 1344: `brk #0x0E00`
  - Synchronous breakpoint. If executed, raises a debug exception; no data-path updates.

- 1346–1347: `brk #0x0E01`
  - Another synchronous breakpoint. No architectural state changes besides exception.

- 1355: `ldr q8, [x5], #16`
  - Loads 16 bytes from memory at `x5` into `v8` (full 128-bit register; upper lanes are architecturally defined as loaded). Post-increment `x5 += 16`.
  - Inputs: x5 (address). Outputs: v8, x5.

- 1358: `ldr q10, [x6], #16`
  - Loads 16 bytes at `x6` into `v10`. Post-increment `x6 += 16`.
  - Inputs: x6. Outputs: v10, x6.

- 1361: `ld2 {v22.4s, v23.4s}, [x4], #32`
  - Loads 32 bytes as 4 interleaved 32-bit pairs and deinterleaves into two vectors: even-indexed 32-bit elements into `v22.4s`, odd-indexed into `v23.4s`. Post-increment `x4 += 32`.
  - Inputs: x4. Outputs: v22, v23, x4.

- 1366: `ld2 {v26.4s, v27.4s}, [x3], #32`
  - Same semantics as above. Post-increment `x3 += 32`.
  - Inputs: x3. Outputs: v26, v27, x3.

- 1371: `ld2 {v30.4s, v31.4s}, [x10], #32`
  - Same semantics as above. Post-increment `x10 += 32`.
  - Inputs: x10. Outputs: v30, v31, x10.

- 1376: `brk #0x0E02`
  - Breakpoint. No data-path effect.

- 1386: `mov v16.d[0], v10.d[0]`
  - Copies the low 64-bit lane of `v10` into the low 64-bit lane of `v16`.
  - Inputs: v10. Outputs: v16.d[0].

- 1387: `mov v17.d[0], v8.d[1]`
  - Copies the high 64-bit lane of `v8` into the low 64-bit lane of `v17` (other lanes of v17 unaffected).
  - Inputs: v8. Outputs: v17.d[0].

- 1389: `trn1 v18.2s, v16.2s, v17.2s`
  - Transpose-interleave of the low 64 bits of `v16` and `v17` at 32-bit granularity, writing the low 64 bits of `v18` (only `.2s` lanes). Upper 64 bits of `v18` are unchanged.
  - Inputs: v16 (low 64), v17 (low 64). Outputs: v18 (low 64).

- 1390: `trn2 v19.2s, v16.2s, v17.2s`
  - Complement transpose-interleave at 32-bit granularity, writing the low 64 bits of `v19`.
  - Inputs: v16 (low 64), v17 (low 64). Outputs: v19 (low 64).

- 1391: `mov v12.d[0], v18.d[0]`
  - Builds low 64-bit half of `v12` from `v18`.
  - Inputs: v18.d[0]. Outputs: v12.d[0].

- 1392: `mov v12.d[1], v19.d[0]`
  - Builds high 64-bit half of `v12` from `v19` low lane.
  - Inputs: v19.d[0]. Outputs: v12.d[1].

- 1395: `mov v16.d[0], v8.d[0]`
  - Low 64-bit copy from `v8` to `v16`.
  - Inputs: v8.d[0]. Outputs: v16.d[0].

- 1396: `mov v17.d[0], v10.d[1]`
  - Copies high 64-bit lane of `v10` into `v17.d[0]`.
  - Inputs: v10.d[1]. Outputs: v17.d[0].

- 1397: `trn1 v18.2s, v16.2s, v17.2s`
  - As above, produces the interleaved low 64 bits in `v18`.

- 1398: `trn2 v19.2s, v16.2s, v17.2s`
  - Complement interleave for the low 64 bits in `v19`.

- 1399: `mov v10.d[0], v18.d[0]`
  - Overwrites low 64-bit lane of `v10` with `v18.d[0]`.

- 1400: `mov v10.d[1], v19.d[0]`
  - Overwrites high 64-bit lane of `v10` with `v19.d[0]`.

- 1408: `fsub v18.4s, v26.4s, v22.4s`
  - Lane-wise single-precision subtraction: `v18.s[i] = v26.s[i] - v22.s[i]` for i=0..3.
  - Inputs: v26, v22. Outputs: v18.

- 1409: `fsub v19.4s, v27.4s, v23.4s`
  - Lane-wise subtraction: `v19 = v27 - v23`.

- 1412: `fadd v22.4s, v26.4s, v22.4s`
  - Lane-wise addition: `v22 = v26 + v22` (overwrites v22).

- 1413: `fadd v23.4s, v27.4s, v23.4s`
  - Lane-wise addition: `v23 = v27 + v23` (overwrites v23).

- 1421: `ldr w2, [x12], #4`
  - Loads a 32-bit little-endian word into `w2` from `x12` and post-increments `x12 += 4`. High 32 bits of `x2` are zeroed when `w2` is written (architectural effect of writing a W-register).
  - Inputs: x12. Outputs: w2/x2, x12.

- 1422: `brk #0x0E10`
  - Breakpoint. No data-path effect.

- 1427: `ldr w14, [x12], #4`
  - Loads a second 32-bit word into `w14`; post-increment `x12 += 4`. High 32 bits of `x14` are zeroed.
  - Inputs: x12. Outputs: w14/x14, x12.

- 1431: `add x2, x0, w2, uxtw #2`
  - Computes `x2 = x0 + ((uint64_t)(uint32_t)w2 << 2)`. Zero-extends `w2` to 64-bit and left-shifts by 2 before addition.
  - Inputs: x0, w2. Outputs: x2.

- 1436: `fsub v16.4s, v10.4s, v12.4s`
  - Lane-wise subtraction: `v16 = v10 - v12`.

- 1437: `fsub v17.4s, v10.4s, v12.4s`
  - Duplicates the same subtraction into `v17` (independent copy).

- 1440: `add x14, x0, w14, uxtw #2`
  - Computes `x14 = x0 + ((uint64_t)(uint32_t)w14 << 2)`.
  - Inputs: x0, w14. Outputs: x14.

- 1441: `brk #0x0E11`
  - Breakpoint. No data-path effect.

- 1450: `fadd v20.4s, v10.4s, v12.4s`
  - Lane-wise addition: `v20 = v10 + v12`.

- 1451: `fadd v21.4s, v10.4s, v12.4s`
  - Duplicate lane-wise addition into `v21`.

- 1454: `fadd v0.4s, v22.4s, v20.4s`
  - Lane-wise addition: `v0 = v22 + v20`.

- 1455: `fadd v1.4s, v23.4s, v21.4s`
  - Lane-wise addition: `v1 = v23 + v21`.

- 1458: `fsub v2.4s, v22.4s, v20.4s`
  - Lane-wise subtraction: `v2 = v22 - v20`.

- 1459: `fsub v3.4s, v23.4s, v21.4s`
  - Lane-wise subtraction: `v3 = v23 - v21`.

- 1463: `fadd v25.4s, v19.4s, v16.4s`
  - Lane-wise addition: `v25 = v19 + v16`.

- 1464: `fsub v27.4s, v19.4s, v16.4s`
  - Lane-wise subtraction: `v27 = v19 - v16`.

- 1467: `fsub v24.4s, v18.4s, v17.4s`
  - Lane-wise subtraction: `v24 = v18 - v17`.

- 1468: `fadd v26.4s, v18.4s, v17.4s`
  - Lane-wise addition: `v26 = v18 + v17`.

- 1476: `mov v12.d[0], v24.d[0]`
  - Overwrites low 64-bit lane of `v12` with `v24.d[0]`.

- 1478: `mov v12.d[1], v25.d[0]`
  - Overwrites high 64-bit lane of `v12` with `v25.d[0]`.

- 1479: `brk #0x0E20`
  - Breakpoint.

- 1480: `trn1 v16.4s, v0.4s, v12.4s`
  - 128-bit transpose-interleave at 32-bit granularity of `v0` and `v12`; writes lower alternating lanes into `v16`.
  - Inputs: v0, v12. Outputs: v16.

- 1481: `trn2 v12.4s, v0.4s, v12.4s`
  - Complement transpose-interleave of `v0` and `v12`; overwrites `v12` with the other interleaved lanes.
  - Inputs: v0, v12 (old). Outputs: v12 (new).

- 1482: `mov v0.d[0], v16.d[0]`
  - Copies low 64-bit lane of `v16` back to `v0.d[0]`. (High 64-bit lane of `v0` remains from prior value.)

- 1486: `mov v13.d[0], v26.d[0]`
  - Copies low 64-bit lane of `v26` to `v13.d[0]`.

- 1487: `mov v13.d[1], v27.d[0]`
  - Copies low 64-bit lane of `v27` to `v13.d[1]`.

- 1489: `brk #0x0E21`
  - Breakpoint.

- 1490: `trn1 v16.4s, v1.4s, v13.4s`
  - 128-bit transpose-interleave at 32-bit granularity of `v1` and `v13` into `v16`.

- 1491: `trn2 v13.4s, v1.4s, v13.4s`
  - Complement interleave; overwrites `v13`.

- 1492: `mov v1.d[0], v16.d[0]`
  - Copies `v16.d[0]` into `v1.d[0]`.

- 1494: `ldp d24, d25, [x11]`
  - Loads two 64-bit values into `v24.d[0]` and `v25.d[0]` without post-increment `[x11]` (no write-back). Upper 64 bits of `v24`/`v25` are unaffected by this instruction.
  - Inputs: x11. Outputs: v24.d[0], v25.d[0].

- 1498: `dup v24.2d, v24.d[0]`
  - Duplicates `v24.d[0]` into both 64-bit lanes of `v24` (fills the entire 128-bit register with the replicated 64-bit value).

- 1499: `dup v25.2d, v25.d[0]`
  - Same duplication for `v25`.

- 1500: `brk #0x0E23`
  - Breakpoint.

- 1503: `orr v31.16b, v0.16b, v0.16b`
  - Bitwise OR of `v0` with itself; effectively `v31 := v0` (copy). Used as a temporary.

- 1504: `mov v0.d[1], v1.d[0]`
  - Moves `v1` low 64-bit lane into `v0` high 64-bit lane.

- 1505: `mov v1.d[0], v31.d[1]`
  - Moves original `v0` high 64-bit lane (saved in `v31`) into `v1` low 64-bit lane. Net effect: swap `v0.d[1]` and `v1.d[0]`.

- 1508: `st2 {v0.4s, v1.4s}, [x2], #32`
  - Stores 32 bytes interleaving 32-bit elements from `v0` and `v1` to memory at `x2`; post-increment `x2 += 32`.
  - Inputs: v0, v1, x2. Outputs: memory, x2.

- 1511: `brk #0x0E14`
  - Breakpoint.

- 1519: `ld2 {v0.4s, v1.4s}, [x9], #32`
  - Deinterleaving load from `x9`; post-increment `x9 += 32`.
  - Inputs: x9. Outputs: v0, v1, x9.

- 1525: `fadd v2.4s, v0.4s, v30.4s`
  - Lane-wise add: `v2 = v0 + v30`.

- 1526: `fadd v3.4s, v1.4s, v31.4s`
  - Lane-wise add: `v3 = v1 + v31`.

- 1529: `ld2 {v26.4s, v27.4s}, [x8], #32`
  - Deinterleaving load from `x8`; post-increment `x8 += 32`.

- 1535: `ld2 {v28.4s, v29.4s}, [x7], #32`
  - Deinterleaving load from `x7`; post-increment `x7 += 32`.

- 1546: `fsub v30.4s, v0.4s, v30.4s`
  - Lane-wise subtract: `v30 = v0 - v30` (destructive to previous `v30`).

- 1547: `fsub v31.4s, v1.4s, v31.4s`
  - Lane-wise subtract: `v31 = v1 - v31`.

- 1550: `fsub v0.4s, v28.4s, v26.4s`
  - Lane-wise subtract: `v0 = v28 - v26`.

- 1551: `fsub v1.4s, v29.4s, v27.4s`
  - Lane-wise subtract: `v1 = v29 - v27`.

- 1554: `fadd v6.4s, v28.4s, v26.4s`
  - Lane-wise add: `v6 = v28 + v26`.

- 1555: `fadd v7.4s, v29.4s, v27.4s`
  - Lane-wise add: `v7 = v29 + v27`.

- 1558: `fadd v4.4s, v6.4s, v2.4s`
  - Lane-wise add: `v4 = v6 + v2`.

- 1559: `fadd v5.4s, v7.4s, v3.4s`
  - Lane-wise add: `v5 = v7 + v3`.

- 1563: `fadd v29.4s, v1.4s, v30.4s`
  - Lane-wise add: `v29 = v1 + v30`.

- 1564: `fsub v27.4s, v1.4s, v30.4s`
  - Lane-wise subtract: `v27 = v1 - v30`.

- 1567: `fsub v6.4s, v6.4s, v2.4s`
  - Lane-wise subtract: `v6 = v6 - v2` (in-place update).

- 1568: `fsub v7.4s, v7.4s, v3.4s`
  - Lane-wise subtract: `v7 = v7 - v3`.

- 1571: `fsub v28.4s, v0.4s, v31.4s`
  - Lane-wise subtract: `v28 = v0 - v31`.

- 1572: `fadd v26.4s, v0.4s, v31.4s`
  - Lane-wise add: `v26 = v0 + v31`.

- 1577: `mov v14.d[0], v28.d[0]`
  - Sets `v14.d[0]` from `v28.d[0]`.

- 1578: `mov v14.d[1], v29.d[0]`
  - Sets `v14.d[1]` from `v29.d[0]`.

- 1579: `brk #0x0E22`
  - Breakpoint.

- 1580: `trn1 v16.4s, v4.4s, v14.4s`
  - 128-bit transpose-interleave at 32-bit granularity of `v4` and `v14` into `v16`.

- 1581: `trn2 v14.4s, v4.4s, v14.4s`
  - Complement interleave; overwrites `v14`.

- 1582: `mov v4.16b, v16.16b`
  - Full 128-bit copy back into `v4`.

- 1585: `mov v13.d[0], v26.d[0]`
  - Sets `v13.d[0]` from `v26.d[0]`.

- 1586: `mov v13.d[1], v27.d[0]`
  - Sets `v13.d[1]` from `v27.d[0]`.

- 1587: `trn1 v16.4s, v5.4s, v13.4s`
  - 128-bit transpose-interleave at 32-bit granularity of `v5` and `v13` into `v16`.

- 1588: `trn2 v13.4s, v5.4s, v13.4s`
  - Complement interleave; overwrites `v13`.

- 1589: `mov v5.16b, v16.16b`
  - Full 128-bit copy back into `v5`.

- 1592: `orr v31.16b, v2.16b, v2.16b`
  - Copies `v2` to scratch `v31`.

- 1593: `mov v2.d[1], v3.d[0]`
  - Moves `v3.d[0]` into `v2.d[1]`.

- 1594: `mov v3.d[0], v31.d[1]`
  - Moves original `v2.d[1]` (saved in `v31.d[1]`) into `v3.d[0]`. Net effect: swap `v2.d[1]` <-> `v3.d[0]`.

- 1597: `st2 {v2.4s, v3.4s}, [x2], #32`
  - Interleaved store of `v2` and `v3` at `x2`; post-increment `x2 += 32`.

- 1599: `brk #0x0E1E`
  - Breakpoint.

- 1608: `trn1 v31.4s, v22.4s, v18.4s`
  - Interleave lower lanes of `v22` and `v18` into `v31`.

- 1609: `trn2 v22.4s, v22.4s, v18.4s`
  - Complement interleave; overwrites `v22`.

- 1611: `mov v18.16b, v31.16b`
  - Copies `v31` result into `v18`.

- 1612: `trn1 v31.4s, v23.4s, v19.4s`
  - Interleave of `v23` and `v19` into `v31`.

- 1613: `trn2 v23.4s, v23.4s, v19.4s`
  - Complement interleave; overwrites `v23`.

- 1614: `mov v19.16b, v31.16b`
  - Copies `v31` to `v19`.

- 1615: `trn1 v31.4s, v20.4s, v16.4s`
  - Interleave of `v20` and `v16` into `v31`.

- 1616: `trn2 v20.4s, v20.4s, v16.4s`
  - Complement interleave; overwrites `v20`.

- 1617: `mov v16.16b, v31.16b`
  - Copies `v31` to `v16`.

- 1618: `trn1 v31.4s, v21.4s, v17.4s`
  - Interleave of `v21` and `v17` into `v31`.

- 1619: `trn2 v21.4s, v21.4s, v17.4s`
  - Complement interleave; overwrites `v21`.

- 1620: `mov v17.16b, v31.16b`
  - Copies `v31` to `v17`.

- 1621: `brk #0x0E24`
  - Breakpoint.

- 1625: `fmul v20.4s, v6.4s, v25.4s`
  - Lane-wise multiply: `v20 = v6 * v25`.

- 1626: `fmul v22.4s, v7.4s, v24.4s`
  - Lane-wise multiply: `v22 = v7 * v24`.

- 1629: `fmul v21.4s, v7.4s, v25.4s`
  - Lane-wise multiply: `v21 = v7 * v25`.

- 1630: `fmul v18.4s, v6.4s, v24.4s`
  - Lane-wise multiply: `v18 = v6 * v24`.

- 1633: `fmul v19.4s, v4.4s, v25.4s`
  - Lane-wise multiply: `v19 = v4 * v25`.

- 1634: `fmul v30.4s, v5.4s, v24.4s`
  - Lane-wise multiply: `v30 = v5 * v24`.

- 1637: `fmul v23.4s, v4.4s, v24.4s`
  - Lane-wise multiply: `v23 = v4 * v24`.

- 1638: `fmul v24.4s, v5.4s, v25.4s`
  - Lane-wise multiply: `v24 = v5 * v25` (overwriting previous `v24`).

- 1642: `fadd v17.4s, v22.4s, v20.4s`
  - Lane-wise add: `v17 = v22 + v20`.

- 1643: `fsub v16.4s, v18.4s, v21.4s`
  - Lane-wise subtract: `v16 = v18 - v21`.

- 1646: `fsub v21.4s, v30.4s, v19.4s`
  - Lane-wise subtract: `v21 = v30 - v19`.

- 1647: `fadd v20.4s, v24.4s, v23.4s`
  - Lane-wise add: `v20 = v24 + v23`.

- 1661: `fadd v18.4s, v16.4s, v20.4s`
  - Lane-wise add: `v18 = v16 + v20`.

- 1662: `fadd v19.4s, v17.4s, v21.4s`
  - Lane-wise add: `v19 = v17 + v21`.

- 1663: `fsub v16.4s, v16.4s, v20.4s`
  - Lane-wise subtract: `v16 = v16 - v20`.

- 1664: `fsub v17.4s, v17.4s, v21.4s`
  - Lane-wise subtract: `v17 = v17 - v21`.

- 1668: `fadd v8.4s, v14.4s, v18.4s`
  - Lane-wise add: `v8 = v14 + v18`.

- 1669: `fadd v9.4s, v15.4s, v19.4s`
  - Lane-wise add: `v9 = v15 + v19`.

- 1670: `fsub v12.4s, v14.4s, v18.4s`
  - Lane-wise subtract: `v12 = v14 - v18`.

- 1671: `fsub v13.4s, v15.4s, v19.4s`
  - Lane-wise subtract: `v13 = v15 - v19`.

- 1675: `fadd v11.4s, v27.4s, v16.4s`
  - Lane-wise add: `v11 = v27 + v16`.

- 1676: `fsub v15.4s, v27.4s, v16.4s`
  - Lane-wise subtract: `v15 = v27 - v16`.

- 1679: `fsub v10.4s, v26.4s, v17.4s`
  - Lane-wise subtract: `v10 = v26 - v17`.

- 1680: `fadd v14.4s, v26.4s, v17.4s`
  - Lane-wise add: `v14 = v26 + v17`.

- 1691: `st2 {v8.4s,  v9.4s},  [x14], #32`
  - Interleaved store of `v8` and `v9` at `x14`; post-increment `x14 += 32`.

- 1693: `orr v31.16b, v10.16b, v10.16b`
  - Copy `v10` into `v31` (scratch).

- 1694: `mov v10.16b,  v11.16b`
  - Full register copy: `v10 := v11`.

- 1695: `mov v11.16b,  v31.16b`
  - Full register copy: `v11 := original v10` (swap `v10` and `v11`).

- 1696: `st2 {v10.4s, v11.4s}, [x14], #32`
  - Interleaved store of `v10` and `v11` at `x14`; post-increment `x14 += 32`.

- 1698: `st2 {v12.4s, v13.4s}, [x14], #32`
  - Interleaved store of `v12` and `v13` at `x14`; post-increment.

- 1700: `orr v31.16b, v14.16b, v14.16b`
  - Copy `v14` into `v31`.

- 1701: `mov v14.16b,  v15.16b`
  - Full register copy: `v14 := v15`.

- 1702: `mov v15.16b,  v31.16b`
  - Full register copy: `v15 := original v14` (swap `v14` and `v15`).

- 1703: `st2 {v14.4s, v15.4s}, [x14], #32`
  - Interleaved store of `v14` and `v15` at `x14`; post-increment.

- 1706: `brk #0x0E15`
  - Breakpoint.

---

### Dataflow highlights and register roles

- **Input stream pointers**: `x3, x4, x5, x6, x7, x8, x9, x10` feed `ld2`/`ldr` instructions and are advanced locally by post-increment. They are treated as inputs into this routine, not initialized here.

- **Offsets pointer**: `x12` supplies two 32-bit offsets via `ldr w2, [x12], #4` and `ldr w14, [x12], #4`, then contributes to two computed output cursors `x2` and `x14` using `add x?, x0, w?, uxtw #2` (zero-extend and left shift by 2 before add).

- **Twiddles pointer**: `x11` supplies two 64-bit values loaded into `v24.d[0]` and `v25.d[0]`, then replicated to fill the full 128-bit vectors via `dup v24.2d` and `dup v25.2d`.

- **Intermediate vector usage** (selected):
  - `v16, v17, v18, v19, v20, v21`: transient accumulators for sums/differences and products.
  - `v22/v23`, `v26/v27`, `v30/v31` and later `v0/v1`, `v28/v29`: deinterleaved load outputs serving as real/imag lane groups.
  - `v12, v13, v14, v15`: reconstructed vectors by mixing halves or results; later used for stores.
  - `v31`: scratch temporary for safe swaps and transient `trn1` results.

- **Swaps and transposes**:
  - `mov vX.d[1], vY.d[0]` plus a saved copy in `v31` implements 64-bit half swaps between vectors.
  - `trn1/trn2` with `.4s` or `.2s` combine/split 32-bit lanes across vectors for re-pairing of data.

- **Arithmetic**:
  - `fadd/fsub` perform lane-wise single-precision operations across four lanes.
  - `fmul` multiplies lane-wise using replicated twiddle values.

- **Stores**:
  - `st2 {vA.4s, vB.4s}, [x?], #32` interleaves and writes paired 32-bit lanes (`vA.s[i], vB.s[i]`) to memory, advancing the output cursor by 32 bytes each store.

---

### Notes on lane addressing and TRN semantics

- Writes of `wN` zero the upper half of `xN`. Subsequent use of `x2`/`x14` includes zero-extension via `uxtw` explicitly.
- `mov vX.d[n], vY.d[m]` copies only a single 64-bit lane; the other lane(s) of the destination remain unchanged.
- `trn1 vD.2s, vA.2s, vB.2s` and `trn2 vD.2s, vA.2s, vB.2s` operate on the low 64-bit halves, leaving upper halves of `vD` unchanged. The later `mov vZ.d[k], vD.d[0]` consolidates those results into full vectors as needed.
- `trn1/trn2 vD.4s, vA.4s, vB.4s` operate across the full 128-bit vectors, producing interleaved 32-bit lanes spanning both 64-bit halves.

---

### Inputs/outputs summary (within this routine)

- Inputs consumed:
  - Memory pointed by `x5`, `x6` (16-byte loads), `x4`, `x3`, `x10`, `x9`, `x8`, `x7` (32-byte deinterleaving loads).
  - Two 32-bit offsets from `[x12]`.
  - Two 64-bit twiddle values from `[x11]`.

- Outputs produced:
  - Interleaved stores to `[x2]` (two `st2` stores) and to `[x14]` (four `st2` stores). Both pointers are advanced by `#32` per store.

- Temporaries:
  - `v31` is used as a scratch for safe 64-bit-lane swaps and as a holding register for `trn1` results; various `v16–v21` act as intermediate accumulators.

---

This concludes the exact, instruction-by-instruction analysis of `neon64_oe` in `src/neon64.s`.

