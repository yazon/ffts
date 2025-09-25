# NEON_X8 Register Flow and Data Movement Analysis

## Register Flow Diagram

### Stage 1: Initial Data Loading and First Butterfly (Lines 104-127)

```
MEMORY LOADS:
[r12] → q2, q3     (Twiddle factors W)
[r6]  → q14, q15   (data[3] - complex pairs)
[r5]  → q10, q11   (data[2] - complex pairs)

COMPLEX MULTIPLICATION (data[3] * W):
q15 * q2 → q12     (data[3].im * W.re)
q14 * q3 → q8      (data[3].re * W.im)
q14 * q2 → q13     (data[3].re * W.re)
q15 * q3 → q15     (data[3].im * W.im)

COMPLEX MULTIPLICATION (data[2] * W):
q10 * q3 → q9      (data[2].re * W.im)
q10 * q2 → q1      (data[2].re * W.re)
q11 * q2 → q0      (data[2].im * W.re)
q11 * q3 → q14     (data[2].im * W.im)

BUTTERFLY OPERATIONS:
q12 - q8  → q10    (Im: d3.im*W.re - d3.re*W.im)
q0  + q9  → q11    (Im: d2.im*W.re + d2.re*W.im)
q15 + q13 → q8     (Re: d3.im*W.im + d3.re*W.re)
q1  - q14 → q9     (Re: d2.re*W.re - d2.im*W.im)

MEMORY LOAD:
[r4] → q12, q13    (data[1])

FURTHER BUTTERFLIES:
q11 - q10 → q15    (Butterfly Im difference)
q9  - q8  → q14    (Butterfly Re difference)
q12 - q15 → q4     (data[1].re - butterfly)
q12 + q15 → q6     (data[1].re + butterfly)
q13 + q14 → q5     (data[1].im + butterfly)
q13 - q14 → q7     (data[1].im - butterfly)

MEMORY STORES:
q4, q5 → [r4]      (Updated data[1])
q6, q7 → [r6]      (Updated data[3])
```

### Stage 2: Second Set of Butterflies (Lines 128-174)

```
MEMORY LOADS:
[r9]  → q14, q15   (data[6])
[r7]  → q12, q13   (data[4])
[r12] → q2, q3     (Next twiddle factors)

COMPLEX MULTIPLICATION (data[6] * W):
q14 * q2 → q1      
q14 * q3 → q0      
q15 * q3 → q14     
q15 * q2 → q4      

REGISTER REUSE:
q9 + q8 → q15      (Combine previous results)

COMPLEX MULTIPLICATION (data[4] * W):
q12 * q3 → q8      
q13 * q3 → q5      
q12 * q2 → q12     
q13 * q2 → q9      

BUTTERFLY OPERATIONS:
q14 + q1  → q14    
q4  - q0  → q13    
q9  + q8  → q0     

MEMORY LOAD:
[r3] → q8, q9      (data[0])

MORE BUTTERFLIES:
q11 + q10 → q1     
q12 - q5  → q12    
q8  + q15 → q11    (data[0] + result)
q8  - q15 → q8     (data[0] - result)
q12 + q14 → q2     
q0  - q13 → q10    
q0  + q13 → q15    
q9  + q1  → q13    
q9  - q1  → q9     
q12 - q14 → q12    

FINAL COMBINATIONS:
q11 + q2  → q0     
q13 + q15 → q1     
q11 - q2  → q4     
q8  - q10 → q2     
q9  + q12 → q3     

MEMORY STORES:
q0, q1 → [r3]!     (data[0], auto-increment)
q2, q3 → [r5]!     (data[2], auto-increment)
```

### Stage 3: Final Butterflies and Storage (Lines 162-199)

```
CONTINUED OPERATIONS:
q13 - q15 → q5     
q9  - q12 → q7     

MEMORY LOADS:
[r10] → q14, q15   (data[7])
[r8]  → q12, q13   (data[5])
[r12] → q2, q3     (Next twiddle factors)

REGISTER COMBINATION:
q8 + q10 → q6      

MEMORY STORES:
q4, q5 → [r7]!     (data[4], auto-increment)
q6, q7 → [r9]!     (data[6], auto-increment)

COMPLEX MULTIPLICATION (data[7] * W):
q14 * q2 → q8      
q15 * q3 → q10     
q14 * q3 → q14     
q15 * q2 → q15     

COMPLEX MULTIPLICATION (data[5] * W):
q13 * q3 → q9      
q12 * q2 → q11     
q12 * q3 → q12     
q13 * q2 → q13     

BUTTERFLY OPERATIONS:
q10 + q8  → q10    
q11 - q9  → q11    

MEMORY LOADS:
[r4] → q8, q9      (Updated data[1])
[r6] → q10, q11    (Updated data[3])

FINAL OPERATIONS:
q15 - q14 → q14    
q13 + q12 → q15    
q11 + q10 → q13    
q15 + q14 → q12    
q15 - q14 → q15    
q11 - q10 → q14    

FINAL BUTTERFLIES:
q8  + q13 → q0     
q9  + q12 → q1     
q10 - q15 → q2     
q11 + q14 → q3     
q8  - q13 → q4     
q9  - q12 → q5     
q10 + q15 → q6     
q11 - q14 → q7     

FINAL MEMORY STORES:
q0, q1 → [r4]!     (data[1], auto-increment)
q2, q3 → [r6]!     (data[3], auto-increment)
q4, q5 → [r8]!     (data[5], auto-increment)
q6, q7 → [r10]!    (data[7], auto-increment)
```

## Register Usage Summary

### NEON Registers (128-bit)
- **q0-q1**: Temporary for complex multiplication results
- **q2-q3**: Twiddle factors (loaded from LUT)
- **q4-q7**: Butterfly operation results, then stored
- **q8-q9**: Data values and intermediate results
- **q10-q11**: Data values and intermediate results
- **q12-q13**: Data values and intermediate results
- **q14-q15**: Data values and intermediate results

### ARM Registers
- **r0**: Base data pointer (input parameter)
- **r1**: Stride value (input parameter)
- **r2**: Twiddle factor LUT pointer (input parameter)
- **r3**: data[0] pointer
- **r4**: data[1] pointer
- **r5**: data[2] pointer
- **r6**: data[3] pointer
- **r7**: data[4] pointer
- **r8**: data[5] pointer
- **r9**: data[6] pointer
- **r10**: data[7] pointer
- **r11**: Loop counter
- **r12**: Current LUT pointer (advances through loop)

## Complex Number Format

Each NEON q register contains 4 float32 values organized as:
```
q register = [Re0, Im0, Re1, Im1]
```

Two consecutive q registers hold 4 complex numbers:
```
q_even = [Re0, Im0, Re1, Im1]
q_odd  = [Re2, Im2, Re3, Im3]
```

## Twiddle Factor Application

Complex multiplication (a + bi) * (c + di) = (ac - bd) + (ad + bc)i

Implemented as:
```
Real part:    a*c - b*d
Imaginary part: a*d + b*c
```

Using 4 real multiplications:
- a*c (real * real)
- b*d (imag * imag)
- a*d (real * imag)
- b*c (imag * real)

## Memory Access Pattern

The function processes data in-place with a specific access pattern:
1. Initial loads from all 8 data locations
2. Intermediate stores to some locations
3. Reloads from updated locations
4. Final stores to all locations with pointer increment

The auto-increment addressing (!) moves pointers forward by 32 bytes (8 floats) after each store, preparing for the next iteration of the outer loop.

## Critical Performance Features

1. **Register Reuse**: Minimizes memory loads by reusing registers
2. **Instruction Interleaving**: Loads are placed early to hide latency
3. **SIMD Efficiency**: Processes 4 complex numbers (8 floats) per instruction
4. **In-place Operation**: Reduces memory bandwidth requirements
5. **Aligned Access**: Uses 128-bit aligned loads/stores for maximum throughput