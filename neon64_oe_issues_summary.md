# neon64_oe ARM64 Implementation Issues and Fixes

## Summary of Issues Found

Based on the analysis of the ARM32 `neon_oe` implementation and the ARM64 `neon64_oe` port, the following critical issues were identified that cause the L2 error of ~2 instead of the expected ~2e-8:

### 1. **Incorrect Offset Loading Increment (CRITICAL)**
**Issue**: The ARM64 code incorrectly advances the offset pointer by 8 bytes instead of 4 bytes.
```asm
// ARM64 (WRONG):
ldr     w2, [x12], #8   // Should be #4
ldr     w14, [x12], #8  // Should be #4

// ARM32 (CORRECT):
ldr      r2,  [r12], #4
ldr      lr,  [r12], #4
```
**Impact**: This causes the code to skip every other offset value, leading to incorrect memory access patterns.

### 2. **Missing Q12 Register Construction (CRITICAL)**
**Issue**: The ARM64 code does not properly build q12 (v12) from parts of q8 and q10 as the ARM32 code does.

**ARM32 implementation**:
```asm
vorr     d25, d17, d17  // d25 = high half of q8
vorr     d24, d20, d20  // d24 = low half of q10
vorr     d20, d16, d16  // d20 gets low half of q8 (updates q10)
```
This creates q12 with: low half from q10, high half from q8.

**ARM64 fix needed**:
```asm
// Save halves before building q12
mov     v24.d[0], v10.d[0]   // d24 = low half of q10
mov     v25.d[0], v8.d[1]    // d25 = high half of q8

// Build q12
mov     v12.d[0], v24.d[0]   // q12 low = q10 low
mov     v12.d[1], v25.d[0]   // q12 high = q8 high

// Update q10
mov     v10.d[0], v8.d[0]    // q10 low = q8 low
```

### 3. **Missing DUP Instructions for 4-Lane Operations**
**Issue**: The ARM64 code has commented out critical `dup` instructions that are needed to duplicate the lower 64 bits to the upper 64 bits for proper 4-lane operations.

```asm
// These should be active:
dup v22.2d, v22.d[0]
dup v23.2d, v23.d[0]
dup v26.2d, v26.d[0]
dup v27.2d, v27.d[0]
dup v30.2d, v30.d[0]
dup v31.2d, v31.d[0]
```

### 4. **Incorrect Use of v24/v25 Registers**
**Issue**: The registers v24 and v25 are overloaded - they're used both for building q12 and later for twiddle factors, causing data corruption.

### 5. **Missing d21 Extraction Before Transpose**
**Issue**: Before the transpose operation `vtrn.32 d20, d21`, the ARM64 code doesn't extract d21 (high half of q10).

**Fix needed**:
```asm
ext     v21.16b, v10.16b, v10.16b, #8  // Extract high half of q10
```

### 6. **Incorrect Twiddle Multiplication Source Registers**
**Issue**: The twiddle multiplication uses wrong source registers (v4-v7) instead of the transposed results from q8-q11.

### 7. **Butterfly Operation Errors**
**Issue**: Some butterfly operations incorrectly duplicate results:
```asm
// Wrong:
fsub    v16.4s, v10.4s, v12.4s
fsub    v17.4s, v10.4s, v12.4s  // Same operation!

// Should perform different operations for real/imag parts
```

## Root Cause
The primary root cause is the missing q12 register setup combined with the incorrect offset increment. These two issues compound to create completely incorrect data flow through the FFT butterfly operations, resulting in the large L2 error.

## Verification from Debug Logs
From the debug session output, we can see:
- Initial loads show all zeros in many registers, indicating incorrect data flow
- The twiddle factors are loaded correctly (0.707107, etc.)
- But the final stores show completely wrong values (e.g., 1.477705, 1.602068) instead of expected small values

## Fix Priority
1. **Fix offset increment** (#8 → #4)
2. **Add q12 construction** from q8/q10 halves
3. **Enable dup instructions**
4. **Fix register usage conflicts**
5. **Add missing d21 extraction**
6. **Correct twiddle multiplication**