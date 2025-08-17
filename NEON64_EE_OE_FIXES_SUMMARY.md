# NEON64 EE/OE Fixes Summary

## Problem Fixed
The ARM64 port of `neon64_ee` and `neon64_oe` functions had a critical bug where 2-lane (64-bit) operations were mixed with 4-lane (128-bit) operations, causing uninitialized upper lanes to be written to memory. This resulted in huge L2 errors for N=32 FFT operations.

## Root Cause
- **Loads**: Used `.2s` (2-lane) loads that only loaded 16 bytes (2 complex numbers)
- **Arithmetic**: Performed with `.2s` operations on lower 64 bits only
- **Stores**: Used `.4s` (4-lane) stores that wrote 32 bytes, including uninitialized upper lanes

## Fixes Applied

### 1. neon64_ee Function Fixes

#### Arithmetic Operations (Lines 847-848, 925-926)
```asm
// BEFORE:
fadd  v0.4s, v22.4s, v20.4s       // q0 real: q11_real + q10_real
fadd  v1.4s, v23.4s, v21.4s       // q0 imag: q11_imag + q10_imag

// AFTER:
fadd  v0.2s, v22.2s, v20.2s       // q0 real: q11_real + q10_real
fadd  v1.2s, v23.2s, v21.2s       // q0 imag: q11_imag + q10_imag
```

#### Store Operations (Lines 945-950, 986-991)
```asm
// BEFORE:
st2   {v0.4s, v1.4s}, [x2], #32   // Store q0 interleaved (32 bytes)
st2   {v2.4s, v3.4s}, [x2], #32   // Store q1 interleaved (32 bytes)

// AFTER:
st2   {v0.2s, v1.2s}, [x2], #16   // Store q0 interleaved (2 complex numbers)
st2   {v2.2s, v3.2s}, [x2], #16   // Store q1 interleaved (2 complex numbers)
```

### 2. neon64_oe Function Fixes

#### Load Operations (Lines 1423-1429, 1575, 1582-1585)
```asm
// BEFORE:
ld2   {v22.4s, v23.4s}, [x4], #32 // Incorrect 32-byte load

// AFTER:
ld2   {v22.2s, v23.2s}, [x4], #16 // Correct 16-byte load (2 complex)
```

#### Arithmetic Operations (Lines 1458-1463, 1500-1515, etc.)
```asm
// BEFORE:
fsub  v18.4s, v26.4s, v22.4s      // Using .4s
fadd  v22.4s, v26.4s, v22.4s      // Using .4s

// AFTER:
fsub  v18.2s, v26.2s, v22.2s      // Using .2s
fadd  v22.2s, v26.2s, v22.2s      // Using .2s
```

#### Store Operations (Lines 1564, 1737-1738)
```asm
// BEFORE:
stp   q0, q1, [x2], #32           // Store 32 bytes
stp   q4, q5, [x14], #32          // Store 32 bytes

// AFTER:
str   q0, [x2], #16               // Store 16 bytes (2 complex numbers)
str   q4, [x14], #16              // Store 16 bytes per register
```

#### Transpose Operations (Lines 1543-1553)
```asm
// BEFORE:
trn1  v16.4s, v0.4s, v12.4s       // 4-lane transpose
mov   v0.16b, v16.16b             // Full register move

// AFTER:
trn1  v16.2s, v0.2s, v12.2s       // 2-lane transpose
mov   v0.d[0], v16.d[0]           // Move only lower 64 bits
```

## Key Principles Applied

1. **Consistent Lane Usage**: All operations now use `.2s` (2-lane) to match the data size being processed (2 complex numbers = 16 bytes)

2. **Matching Store Sizes**: Store operations now write exactly the same amount of data that was loaded and processed

3. **Proper Register Construction**: When building full q-registers from d-registers, only the initialized portions are used

4. **Transpose Adjustments**: Transpose operations adjusted to work with 2-lane data

## Expected Results

These fixes should:
- Eliminate the huge L2 errors seen with N=32 FFT operations
- Ensure no uninitialized data is written to memory
- Make the ARM64 implementation functionally equivalent to the ARM32 version
- Improve numerical stability and accuracy