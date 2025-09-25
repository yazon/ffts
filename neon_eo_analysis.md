# Detailed Analysis of ARM32 NEON `neon_eo` Macro

## Overview
The `neon_eo` macro is a critical component of the FFTS (Fastest Fourier Transform in the South) library, implementing a specialized FFT butterfly computation using ARM32 NEON SIMD instructions. This analysis provides a comprehensive breakdown for porting to ARM64.

## Register Setup and Input Parameters

### Register Mapping at Entry
- **r0**: Output buffer pointer (destination for FFT results)
- **r2**: Temporary register (loaded from offset table)
- **r3-r10**: Data pointers to different FFT input sections
  - r3: data[0] pointer
  - r4: data[1] pointer  
  - r5: data[2] pointer
  - r6: data[3] pointer
  - r7: data[4] pointer
  - r8: data[5] pointer
  - r9: data[6] pointer
  - r10: data[7] pointer
- **r11**: Pointer to twiddle factors (complex exponentials)
- **r12**: Offset table pointer (for output addressing)
- **lr**: Temporary register (loaded from offset table)

### Data Layout
- Uses `vld2.32` instructions for deinterleaved complex number loading
- Real and imaginary parts are loaded into separate lanes
- 128-bit alignment is enforced (`:128` suffix)

## Detailed Operation Analysis

### Phase 1: First Butterfly Block (Lines 476-499)

#### Data Loading
```assembly
476:  vld2.32  {q9},  [r5, :128]!   // Load complex data from data[2]
477:  vld2.32  {q13}, [r3, :128]!   // Load complex data from data[0]
478:  vld2.32  {q12}, [r4, :128]!   // Load complex data from data[1]
479:  vld2.32  {q0},  [r7, :128]!   // Load complex data from data[4]
481:  vld2.32  {q8},  [r6, :128]!   // Load complex data from data[3]
```

After `vld2.32`:
- Even lanes (d16, d18, d20, ...) contain real parts
- Odd lanes (d17, d19, d21, ...) contain imaginary parts

#### Butterfly Computations
```assembly
480:  vsub.f32 q11, q13, q12  // q11 = data[0] - data[1] (complex subtract)
482:  vadd.f32 q12, q13, q12  // q12 = data[0] + data[1] (complex add)
483:  vsub.f32 q10, q9,  q8   // q10 = data[2] - data[3] (complex subtract)
484:  vadd.f32 q8,  q9,  q8   // q8  = data[2] + data[3] (complex add)
```

#### Further Butterfly Operations
```assembly
485:  vadd.f32 q9,  q12, q8   // q9 = (data[0]+data[1]) + (data[2]+data[3])
488:  vsub.f32 q8,  q12, q8   // q8 = (data[0]+data[1]) - (data[2]+data[3])
```

#### Special Lane Operations
```assembly
486:  vadd.f32 d9,  d23, d20  // d9  = q11.imag + q10.real
487:  vsub.f32 d11, d23, d20  // d11 = q11.imag - q10.real  
489:  vsub.f32 d8,  d22, d21  // d8  = q11.real - q10.imag
490:  vadd.f32 d10, d22, d21  // d10 = q11.real + q10.imag
```

This creates:
- q4 = {d8, d9} = complex result from q11 and q10 butterfly
- q5 = {d10, d11} = another complex result

#### Output Address Calculation
```assembly
491:  ldr      r2,  [r12], #4     // Load offset from table
493:  ldr      lr,  [r12], #4     // Load next offset
495:  add      r2,  r0, r2, lsl #2  // Calculate output address 1
497:  add      lr,  r0, lr, lsl #2  // Calculate output address 2
```

#### Data Reorganization and Storage
```assembly
494:  vtrn.32  q9,  q4   // Transpose 32-bit elements
496:  vtrn.32  q8,  q5   // Transpose 32-bit elements
498:  vswp     d9,  d10  // Swap double registers
499:  vst1.32  {d8, d9, d10, d11}, [lr, :128]!  // Store 4 doubles
```

### Phase 2: Second Butterfly Block (Lines 500-516)

#### Data Loading
```assembly
500:  vld2.32  {q13}, [r10, :128]!  // Load from data[7]
501:  vld2.32  {q15}, [r9,  :128]!  // Load from data[6]
502:  vld2.32  {q11}, [r8,  :128]!  // Load from data[5]
```

#### Butterfly Computations
```assembly
503:  vsub.f32 q14, q15, q13  // q14 = data[6] - data[7]
504:  vsub.f32 q12, q0,  q11  // q12 = data[4] - data[5]
505:  vadd.f32 q11, q0,  q11  // q11 = data[4] + data[5]
506:  vadd.f32 q13, q15, q13  // q13 = data[6] + data[7]
```

#### Complex Operations on Lanes
```assembly
507:  vadd.f32 d13, d29, d24  // Imaginary parts operation
509:  vsub.f32 d12, d28, d25  // Real/imaginary cross operation
510:  vsub.f32 d15, d29, d24  // Imaginary parts operation
511:  vadd.f32 d14, d28, d25  // Real/imaginary cross operation
```

#### Further Butterflies
```assembly
508:  vadd.f32 q15, q13, q11  // q15 = (data[6]+data[7]) + (data[4]+data[5])
513:  vsub.f32 q15, q13, q11  // q15 = (data[6]+data[7]) - (data[4]+data[5])
```

#### Data Organization and Storage
```assembly
512:  vtrn.32  q15, q6   // Transpose with q6 (from phase 1)
514:  vtrn.32  q15, q7   // Transpose with q7
515:  vswp     d13, d14  // Swap for proper ordering
516:  vst1.32  {d12, d13, d14, d15}, [lr, :128]!
```

### Phase 3: Twiddle Factor Multiplication (Lines 517-530)

#### Data Preparation
```assembly
492:  vld1.32  {d20, d21}, [r11, :128]  // Load twiddle factors (W)
517:  vtrn.32  q13, q14   // Prepare data for multiplication
518:  vtrn.32  q11, q12
```

After transpose:
- q13, q14 contain reorganized data from second butterfly
- q11, q12 contain reorganized data for multiplication

#### Complex Multiplication
The complex multiplication (a + bi) * (c + di) = (ac - bd) + (ad + bc)i

```assembly
519:  vmul.f32 d24, d26, d21  // d24 = q13.real * W.imag
520:  vmul.f32 d28, d27, d20  // d28 = q13.imag * W.real
521:  vmul.f32 d25, d26, d20  // d25 = q13.real * W.real
522:  vmul.f32 d26, d27, d21  // d26 = q13.imag * W.imag

523:  vmul.f32 d27, d22, d21  // d27 = q11.real * W.imag  
524:  vmul.f32 d30, d23, d20  // d30 = q11.imag * W.real
525:  vmul.f32 d29, d23, d21  // d29 = q11.imag * W.imag
526:  vmul.f32 d22, d22, d20  // d22 = q11.real * W.real
```

#### Complex Results Assembly
```assembly
527:  vsub.f32 d21, d28, d24  // d21 = imag(q13*W) = ac - bd
528:  vadd.f32 d20, d26, d25  // d20 = real(q13*W) = ad + bc
529:  vadd.f32 d25, d30, d27  // d25 = real(q11*W)
530:  vsub.f32 d24, d22, d29  // d24 = imag(q11*W)
```

Result: q10 = {d20, d21} and q12 = {d24, d25} contain twiddle-multiplied values

### Phase 4: Final Butterfly and Output (Lines 531-541)

#### Final Butterfly Stage
```assembly
531:  vadd.f32 q11, q12, q10  // q11 = final butterfly add
532:  vsub.f32 q10, q12, q10  // q10 = final butterfly subtract
533:  vadd.f32 q0,  q9,  q11  // q0 = combine with phase 1 results
534:  vsub.f32 q2,  q9,  q11  // q2 = combine with phase 1 results
```

#### Final Lane Operations
```assembly
535:  vadd.f32 d3,  d17, d20  // d3 = q8.imag + q10.real
536:  vsub.f32 d7,  d17, d20  // d7 = q8.imag - q10.real
537:  vsub.f32 d2,  d16, d21  // d2 = q8.real - q10.imag
538:  vadd.f32 d6,  d16, d21  // d6 = q8.real + q10.imag
```

#### Final Data Swapping
```assembly
539:  vswp     d1,  d2   // Swap for correct output ordering
540:  vswp     d5,  d6   // Swap for correct output ordering
```

#### Output Storage
```assembly
541:  vstmia   r2!, {q0-q3}  // Store 4 quad registers (8 complex numbers)
```

## Key Observations for ARM64 Porting

### 1. Register Usage
- ARM32 uses q0-q15 (128-bit), d0-d31 (64-bit)
- ARM64 has v0-v31 (128-bit) with more flexibility
- No need for separate d-register addressing in ARM64

### 2. Instruction Differences
- `vld2.32` → `ld2 {v0.4s, v1.4s}, [x0]`
- `vtrn.32` → `trn1/trn2` instructions
- `vswp` → Use `mov` or `ins` instructions
- `vstmia` → Multiple `st1/st2` instructions

### 3. Addressing Modes
- ARM32 post-increment `[r0, :128]!` → ARM64 `[x0], #32`
- Shift operations in address calculation remain similar

### 4. Complex Number Handling
- Maintains deinterleaved format throughout
- Efficient use of SIMD lanes for parallel processing
- Twiddle factor multiplication follows standard complex multiply

### 5. Memory Alignment
- 128-bit alignment hints (`:128`) important for performance
- Consider using `ld2` with proper alignment specifiers

### 6. Pipeline Optimization
- Interleaved loads and arithmetic operations
- Minimal data dependencies between consecutive instructions
- Efficient use of NEON pipeline

## Summary
The `neon_eo` macro implements an 8-point FFT kernel with integrated twiddle factor multiplication. It processes 8 complex input values through multiple butterfly stages, applies twiddle factors, and stores the results. The implementation is highly optimized for ARM32 NEON, using deinterleaved complex number representation and efficient SIMD operations throughout.