# ARM32 NEON neon_x8 to ARM64 Porting Summary

## Executive Summary

The `neon_x8` function implements an 8-point FFT using ARM32 NEON SIMD instructions. It's a highly optimized in-place algorithm that processes complex numbers stored in an interleaved format (real, imaginary pairs). The function uses a radix-8 decomposition implemented as three stages of radix-2 butterflies.

## Key Algorithm Characteristics

### 1. **FFT Type**
- 8-point Decimation-In-Time (DIT) FFT
- In-place computation
- Complex-to-complex transform
- Three butterfly stages

### 2. **Data Layout**
- Complex numbers stored as interleaved real/imaginary pairs
- Each NEON q register holds 2 complex numbers (4 floats)
- Data accessed with stride to support larger transforms

### 3. **Computational Pattern**
```
Stage 1: Butterflies on (data[2], data[3]) with (data[0], data[1])
Stage 2: Butterflies on (data[4], data[5], data[6], data[7])
Stage 3: Final combinations of all 8 points
```

## Register Allocation Strategy

### NEON Registers (q0-q15)
- **q0-q1**: Temporary computation registers
- **q2-q3**: Twiddle factors from LUT
- **q4-q7**: Butterfly results for storage
- **q8-q15**: Data values and intermediate results

### ARM Registers (r0-r12)
- **r0-r2**: Function parameters (data, stride, LUT)
- **r3-r10**: Pointers to 8 data elements
- **r11**: Loop counter
- **r12**: Current LUT pointer

## Critical Implementation Details

### 1. **Loop Structure**
- Loop count = -(stride >> 5), increments to zero
- Processes multiple 8-point FFTs in sequence
- Auto-increment addressing for efficiency

### 2. **Complex Multiplication**
```
(a + bi) * (c + di) = (ac - bd) + (ad + bc)i
```
Implemented using 4 real multiplications per complex multiply

### 3. **Memory Access Pattern**
- Initial loads from all 8 locations
- Intermediate stores after each butterfly stage
- Pointer auto-increment prepares for next iteration

### 4. **Twiddle Factor Loading**
- Pre-computed twiddle factors in LUT
- Loaded sequentially with auto-increment
- Two q registers per twiddle set (4 complex values)

## ARM64 Porting Considerations

### 1. **Instruction Mapping**
| ARM32 | ARM64 |
|-------|-------|
| `vld1.32 {q0,q1}, [r0, :128]!` | `ld1 {v0.4s, v1.4s}, [x0], #32` |
| `vst1.32 {q0,q1}, [r0, :128]` | `st1 {v0.4s, v1.4s}, [x0]` |
| `vmul.f32 q0, q1, q2` | `fmul v0.4s, v1.4s, v2.4s` |
| `vadd.f32 q0, q1, q2` | `fadd v0.4s, v1.4s, v2.4s` |
| `vsub.f32 q0, q1, q2` | `fsub v0.4s, v1.4s, v2.4s` |

### 2. **Register Mapping**
| ARM32 | ARM64 |
|-------|-------|
| r0-r12 | x0-x12 (64-bit) or w0-w12 (32-bit) |
| q0-q15 | v0-v15 (128-bit vectors) |

### 3. **Addressing Modes**
- ARM64 supports similar aligned loads with post-increment
- Syntax: `[x0], #32` for 32-byte post-increment
- Alignment hints: `:128` becomes implicit in ARM64

### 4. **Optimization Opportunities**
- ARM64 has 32 NEON registers (v0-v31) vs 16 in ARM32
- Can reduce register pressure and memory accesses
- Potential for better instruction scheduling
- Consider using paired loads (ldp) where beneficial

## Performance Critical Paths

### 1. **Data Dependencies**
```
Load → Complex Multiply → Butterfly → Store
   ↓
Next stage butterflies depend on previous results
```

### 2. **Latency Hiding**
- Early loads to hide memory latency
- Interleaved arithmetic operations
- Register reuse minimizes loads

### 3. **Throughput Optimization**
- SIMD processes 4 complex numbers per loop iteration
- Aligned 128-bit loads/stores
- Minimal memory traffic through in-place operation

## Implementation Strategy for ARM64

### 1. **Direct Translation**
- Start with 1:1 instruction mapping
- Maintain same register allocation strategy
- Preserve memory access pattern

### 2. **ARM64-Specific Optimizations**
- Utilize additional v16-v31 registers
- Consider SVE/SVE2 for scalable vectors
- Explore fused multiply-add (fmla) opportunities
- Use paired load/store where beneficial

### 3. **Testing Considerations**
- Verify bit-exact results with ARM32 version
- Test with various stride values
- Validate alignment requirements
- Performance comparison on target hardware

## Summary of Key Findings

1. **Algorithm**: Three-stage radix-2 butterfly implementation of 8-point FFT
2. **Data Format**: Interleaved complex numbers, 2 per NEON register
3. **Memory Pattern**: In-place with specific butterfly groupings
4. **Twiddle Factors**: Pre-computed, loaded from LUT
5. **Loop Structure**: Processes multiple 8-point FFTs based on stride
6. **Critical Path**: Load → Multiply → Butterfly → Store chain
7. **Register Usage**: Near-optimal use of available NEON registers
8. **Optimization**: Careful instruction scheduling for latency hiding

This analysis provides the foundation for accurate ARM64 porting while maintaining the performance characteristics of the original ARM32 implementation.