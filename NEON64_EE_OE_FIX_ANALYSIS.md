# NEON64 EE/OE 2-Lane/4-Lane Mixing Issue Analysis

## Problem Summary

The ARM64 port of `neon_ee` and `neon_oe` functions has a critical bug where 2-lane (64-bit) arithmetic operations are mixed with 4-lane (128-bit) store operations, resulting in uninitialized upper lanes being written to memory. This causes the N=32 FFT to produce huge L2 errors with random values.

## Root Cause Analysis

### ARM32 Original Behavior (neon_ee/neon_oe)
- Uses `vld2.32 {q15}, [r10, :64]!` which loads **2 complex numbers** (16 bytes)
- Performs arithmetic on d-registers (64-bit, 2 lanes)
- Reconstructs full q-registers before storing
- Uses `vst2.32 {q0, q1}, [r2, :64]!` to store properly formed 128-bit vectors

### ARM64 Buggy Port (neon64_ee/neon64_oe)
- Uses `ld2 {v30.2s, v31.2s}, [x10], #16` which loads **2 complex numbers** (16 bytes)
- Performs arithmetic with `.2s` operations (64-bit, 2 lanes)
- **BUG**: Uses `st2 {v0.4s, v1.4s}, [x2], #32` which stores **4 complex numbers** (32 bytes)
- The upper 64 bits of the vectors are uninitialized/garbage

## Specific Issues Found

### In neon64_ee (lines 659-950):
1. **Line 677**: `ld2 {v30.2s, v31.2s}, [x10], #16` - loads only 2 lanes
2. **Lines 695-796**: All arithmetic uses `.2s` operations (2 lanes)
3. **Line 847-848**: Suddenly switches to `.4s` operations:
   ```
   fadd  v0.4s, v22.4s, v20.4s
   fadd  v1.4s, v23.4s, v21.4s
   ```
4. **Line 945-950**: Stores use `.4s` (4 lanes) with uninitialized upper lanes:
   ```
   st2   {v0.4s, v1.4s}, [x2], #32
   st2   {v2.4s, v3.4s}, [x2], #32
   ```

### In neon64_oe (lines 1404-1737):
1. **Line 1575**: `ld2 {v0.4s, v1.4s}, [x9], #32` - correctly loads 4 lanes
2. **Lines 1527-1533**: Mixed `.2s` operations for d-register manipulation
3. **Lines 1518-1523**: Uses `.4s` operations
4. **Lines 1564, 1736-1737**: Stores are inconsistent - some use `stp` (correct), others might use `.4s` stores

## Solution Options

### Option 1: Strict 2-Lane Pipeline (Recommended)
- Keep all loads as `.2s` (16 bytes)
- Keep all arithmetic as `.2s`
- Change all stores to `.2s` with 16-byte increments
- This mirrors the ARM32 behavior exactly

### Option 2: Full 4-Lane Reconstruction
- Keep loads as `.2s`
- Before any `.4s` operation or store, properly initialize upper lanes
- Use `mov v?.d[1], v?.d[0]` or zero out upper lanes
- More complex and error-prone

## Implementation Plan

1. For neon64_ee:
   - Replace all `.4s` arithmetic with `.2s`
   - Replace all `st2 {v?.4s, v?.4s}, [x?], #32` with `st2 {v?.2s, v?.2s}, [x?], #16`
   - Ensure address increment matches data size

2. For neon64_oe:
   - Audit all loads to ensure consistency
   - Replace mixed `.4s` operations with `.2s` where appropriate
   - Fix all stores to match the load size

3. Verification:
   - The fix should eliminate the huge L2 errors at N=32
   - Output should match ARM32 implementation