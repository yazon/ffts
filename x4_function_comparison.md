# ARM32 vs ARM64 x4 Function Detailed Comparison

## Function Signatures
**ARM32**: `neon_static_x4_f(float* data, float* ws)`
**ARM64**: `neon64_static_x4_f(ffts_plan_t* p, const void* input, void* output)` ⚠️ **WRONG**

## Memory Layout Analysis

### ARM32 x4 Algorithm:
```asm
  add       r3, r0, #64         ; r3 = data + 64 bytes (points to data[4])
  vpush     {q4-q7}

  vld1.32   {q2,  q3},  [r1, :128]      ; Load twiddle factors from ws
  vld1.32   {q12, q13}, [r3, :128]!     ; Load data[4:7] complex pairs
  mov       r2, r0                       ; Save original data pointer
  
  ; Complex twiddle multiplication...
  vmul.f32  q0,  q13, q3                ; imaginary × imaginary  
  vld1.32   {q14, q15}, [r3, :128]      ; Load data[8:11] complex pairs
  vmul.f32  q5,  q12, q2                ; real × real
  vld1.32   {q8,  q9},  [r0, :128]!     ; Load data[0:3] complex pairs
  ; ... complex multiply continues
  
  ; Final butterfly and store results:
  vst1.32   {q0, q1}, [r2, :128]!       ; Store result[0:3]
  vst1.32   {q2, q3}, [r2, :128]!       ; Store result[4:7] 
  vst1.32   {q4, q5}, [r2, :128]!       ; Store result[8:11]
  vst1.32   {q6, q7}, [r2, :128]        ; Store result[12:15]
```

### ARM64 x4 Algorithm (Current - BROKEN):
```asm
  ; ❌ WRONG: Expects (plan, input, output) but should be (data, ws)
  ld1     {v16.4s, v17.4s}, [x1]        ; ❌ Loads from x1 (input) expecting twiddle
  ld2     {v0.4s, v1.4s}, [x0]          ; ❌ Loads from x0 (plan) expecting data
  
  ; ❌ WRONG: Complex algorithm that doesn't match ARM32
  ; Uses DUP operations and scalar extraction instead of vector operations
  dup     v16.4s, v0.s[0]               ; ❌ Inefficient scalar duplication
  ; ... broken butterfly algorithm
  
  st2     {v4.4s, v5.4s}, [x0]          ; ❌ Stores to x0 (plan) instead of data
```

## Key Issues Found:

### 1. **Wrong Function Signature**
- ARM32: `x4(data_ptr, twiddle_ptr)` 
- ARM64: `x4(plan_ptr, input_ptr, output_ptr)` ⚠️ **MISMATCH**

### 2. **Wrong Memory Access Pattern**
- ARM32: `data[0], data[64], data[128]` (64-byte offsets for complex pairs)
- ARM64: Trying to access plan structure members instead of data

### 3. **Broken Algorithm**
- ARM32: Efficient vector complex multiplication  
- ARM64: Inefficient scalar DUP operations + wrong butterfly math

### 4. **Wrong Data Layout Assumption**
- ARM32: Processes 16 complex numbers (64 floats) as 4×4 matrix
- ARM64: Assumes different data organization

## Required Fixes:

1. **Fix function signature**: Change to match ARM32 `(data, ws)`
2. **Fix memory layout**: Use proper 64-byte offsets for complex data
3. **Fix algorithm**: Implement proper radix-4 FFT butterfly
4. **Fix data access**: Use vld1/vst1 like ARM32, not ld2/st2 