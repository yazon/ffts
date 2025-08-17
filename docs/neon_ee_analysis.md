@@ -1,1 +1,151 @@
# Detailed Analysis of ARM32 NEON 'neon_ee' Macro

## Overview
The `neon_ee` macro implements a highly optimized radix-8 FFT butterfly operation using ARM32 NEON SIMD instructions. This analysis provides comprehensive details about the algorithm, register usage, and memory access patterns to facilitate porting to ARM64.

## 1. Function Interface and Register Allocation

### Input Parameters
- **r0**: Output data pointer (base address for storing results)
- **r1**: Input data pointer (marked with ? in comments, possibly unused in this macro)
- **r2**: Initially holds address of twiddle factors, later reused as temporary register
- **r3-r10**: Eight data pointers for accessing different FFT data blocks
- **r11**: Loop iteration counter (decremented each iteration)
- **r12**: Offset table pointer (for calculating output addresses)
- **lr**: Temporary register for output address calculation

### NEON Register Usage
- **q8 (d16, d17)**: Twiddle factors (d16 = real parts, d17 = imaginary parts)
- **q0-q15**: Used for data processing and intermediate results
- **d0-d31**: Individual double-word registers within q0-q15

## 2. Memory Layout and Data Format

### Input Data Format
The FFT data is stored in interleaved complex number format:
```
Memory: [Re0, Im0, Re1, Im1, Re2, Im2, Re3, Im3, ...]
```

### vld2.32 Instruction Behavior
The `vld2.32` instruction performs deinterleaved loading:
- Separates real and imaginary parts into different registers
- Example: `vld2.32 {q15}, [r10, :128]!`
  - d30 = [Re0, Re1, Re2, Re3] (real parts)
  - d31 = [Im0, Im1, Im2, Im3] (imaginary parts)

## 3. Algorithm Flow

### 3.1 Initial Setup
```assembly
vld1.32  {d16, d17}, [r2, :128]  @ Load twiddle factors
```

### 3.2 Data Loading Phase
Eight `vld2.32` instructions load complex data from memory addresses pointed to by r3-r10:
```assembly
vld2.32  {q15}, [r10, :128]!  @ Load 4 complex numbers from r10
vld2.32  {q13}, [r8, :128]!   @ Load 4 complex numbers from r8
vld2.32  {q14}, [r7, :128]!   @ Load 4 complex numbers from r7
vld2.32  {q9},  [r4, :128]!   @ Load 4 complex numbers from r4
vld2.32  {q10}, [r3, :128]!   @ Load 4 complex numbers from r3
vld2.32  {q11}, [r6, :128]!   @ Load 4 complex numbers from r6
vld2.32  {q12}, [r5, :128]!   @ Load 4 complex numbers from r5
vld2.32  {q0},  [r9, :128]!   @ Load 4 complex numbers from r9
```

### 3.3 Butterfly Computations

#### Stage 1: Initial Butterflies
```assembly
vsub.f32 q1, q14, q13    @ Difference operations
vsub.f32 q2, q0, q15
vadd.f32 q0, q0, q15     @ Sum operations
```

#### Stage 2: Complex Multiplication with Twiddle Factors
The complex multiplication (a bi) × (c di) = (ac - bd) (ad bc)i is implemented as:
```assembly
vmul.f32 d10, d2, d17    @ Imaginary × Imaginary products
vmul.f32 d11, d3, d16    @ Real × Real products
vmul.f32 d12, d3, d17    @ Real × Imaginary products
vmul.f32 d13, d2, d16    @ Imaginary × Real products
```

#### Stage 3: Combining Results
```assembly
vsub.f32 d7, d7, d6      @ Complete complex multiplication
vadd.f32 d11, d11, d10   @ by combining products
```

### 3.4 Output Preparation

#### Transpose Operations
Before storing, data is transposed to prepare for interleaved storage:
```assembly
vtrn.32  q1, q3          @ Transpose 32-bit elements
vtrn.32  q0, q2          @ between register pairs
```

#### Address Calculation
Output addresses are calculated using offsets from the table:
```assembly
ldr      r2, [r12], #4    @ Load offset from table
add      r2, r0, r2, lsl #2  @ Calculate address: base offset*4
```

### 3.5 Data Storage
Results are stored back in interleaved format using `vst2.32`:
```assembly
vst2.32  {q0, q1}, [r2, :128]!  @ Store 8 complex numbers
vst2.32  {q2, q3}, [lr, :128]!  @ Store 8 complex numbers
```

## 4. Key Optimizations

1. **Register Reuse**: Careful register allocation minimizes loads/stores
2. **Instruction Scheduling**: Interleaved operations to hide latencies
3. **SIMD Parallelism**: Processes 4 complex numbers simultaneously
4. **Memory Access**: Aligned 128-bit accesses for optimal performance
5. **Post-increment Addressing**: Efficient pointer updates

## 5. Modified Registers

### Registers Modified During Execution
- **r2, lr**: Overwritten with output addresses from offset table
- **r3-r10**: Post-incremented by vld2.32 instructions
- **r11**: Decremented (loop counter)
- **r12**: Post-incremented by ldr instructions
- **q0-q15**: All NEON registers are modified during computation

### Registers Preserved
- **r0**: Output base pointer (unchanged)
- **r1**: Input pointer (unused in this macro)

## 6. Loop Structure

The macro implements a loop that:
1. Processes 32 complex numbers per iteration (4 from each of 8 pointers)
2. Continues while r11 != 0 (controlled by calling code)
3. Outputs results to addresses determined by offset table

## 7. ARM64 Porting Considerations

When porting to ARM64, consider:
1. **Register Names**: q0-q15 → v0-v15 (with q0-q31 available)
2. **More Registers**: ARM64 has 32 NEON registers vs 16 in ARM32
3. **Addressing Modes**: Different post-increment syntax
4. **Instruction Differences**: Some instructions have different mnemonics
5. **64-bit Pointers**: Address calculations need adjustment
6. **Calling Convention**: Different register usage conventions

## 8. Performance Characteristics

- **Memory Bandwidth**: 8 loads 4 stores per iteration
- **Arithmetic Intensity**: ~50 floating-point operations per iteration
- **Pipeline Friendly**: Well-scheduled to avoid stalls
- **Cache Friendly**: Sequential memory access patterns

## Summary

The `neon_ee` macro is a highly optimized implementation of a radix-8 FFT butterfly operation that efficiently uses ARM32 NEON SIMD capabilities. It processes 32 complex numbers per iteration through careful register allocation, efficient memory access patterns, and optimized instruction scheduling. The deinterleaved load/store approach with vld2/vst2 instructions is particularly well-suited for complex number FFT operations.
