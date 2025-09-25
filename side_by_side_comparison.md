# Side-by-Side Comparison: Critical Sections

## Store Instruction Comparison

### Intermediate Stores (Mid-computation)

| Line | ARM32 | ARM64 | Correct? |
|------|-------|-------|----------|
| Store to data[1] | `vst1.32  {q4,  q5},  [r4, :64]` | `st1      {v4.4s,  v5.4s},  [x4], #32` | ❌ NO |
| Store to data[3] | `vst1.32  {q6,  q7},  [r6, :64]` | `st1      {v6.4s,  v7.4s},  [x6], #32` | ❌ NO |

**Problem:** ARM32 does NOT increment the pointer (no `!`), but ARM64 DOES increment (`], #32`)

### Final Transpose Stores

| Line | ARM32 | ARM64 | Correct? |
|------|-------|-------|----------|
| Store to data[0] | `vst2.32  {q0,  q1},  [r3, :64]!` | `st2      {v0.4s,  v1.4s},  [x3], #32` | ✅ YES |
| Store to data[2] | `vst2.32  {q2,  q3},  [r5, :64]!` | `st2      {v2.4s,  v3.4s},  [x5], #32` | ✅ YES |
| Store to data[4] | `vst2.32  {q4,  q5},  [r7, :64]!` | `st2      {v4.4s,  v5.4s},  [x7], #32` | ✅ YES |
| Store to data[6] | `vst2.32  {q6,  q7},  [r9, :64]!` | `st2      {v6.4s,  v7.4s},  [x9], #32` | ✅ YES |
| Store to data[1] | `vst2.32  {q0,  q1},  [r4, :64]!` | `st2      {v0.4s,  v1.4s},  [x4], #32` | ✅ YES |
| Store to data[3] | `vst2.32  {q2,  q3},  [r6, :64]!` | `st2      {v2.4s,  v3.4s},  [x6], #32` | ✅ YES |
| Store to data[5] | `vst2.32  {q4,  q5},  [r8, :64]!` | `st2      {v4.4s,  v5.4s},  [x8], #32` | ✅ YES |
| Store to data[7] | `vst2.32  {q6,  q7},  [r10, :64]!` | `st2      {v6.4s,  v7.4s},  [x10], #32` | ✅ YES |

## Memory Access Pattern Impact

### Expected Behavior (ARM32)
```
Iteration 1: data[1] stored at x4 + 0
Iteration 2: data[1] stored at x4 + 0  (same location - temporary storage)
Iteration 3: data[1] stored at x4 + 0  (same location - temporary storage)
...
Final st2 increments x4 for next set of data
```

### Buggy Behavior (ARM64)
```
Iteration 1: data[1] stored at x4 + 0,  x4 += 32  ❌
Iteration 2: data[1] stored at x4 + 32, x4 += 32  ❌ (wrong location!)
Iteration 3: data[1] stored at x4 + 64, x4 += 32  ❌ (wrong location!)
...
```

## The Critical Fix

```diff
ARM64 Implementation - Lines to Fix:

- st1      {v4.4s,  v5.4s},  [x4], #32
+ st1      {v4.4s,  v5.4s},  [x4]

- st1      {v6.4s,  v7.4s},  [x6], #32  
+ st1      {v6.4s,  v7.4s},  [x6]
```

## Why This Matters

The intermediate stores are writing temporary results that will be read back in the next phase of the computation. If the pointers are incorrectly incremented:

1. **Iteration 1**: Works correctly (first time through)
2. **Iteration 2+**: Reads from wrong memory location, computes with garbage data
3. **Result**: Completely incorrect FFT output after first iteration

This is not a performance issue - it's a **correctness issue** that will produce wrong results.