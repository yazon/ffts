# ARM64 Developer Guide for FFTS

_Last updated: 2025-07-23_

This document provides comprehensive developer documentation for the ARM64/AArch64 implementation of FFTS (The Fastest Fourier Transform in the South), covering calling conventions, register usage, and architectural differences from the ARM32 implementation.

---

## 1. Overview

The ARM64 port of FFTS leverages the advanced capabilities of the AArch64 architecture to deliver optimal FFT performance:

- **64-bit addressing**: Full 64-bit virtual address space
- **32 NEON registers**: Double the SIMD register count vs ARM32 (16 registers)
- **Improved instruction encoding**: More efficient immediate encodings
- **Enhanced SIMD operations**: Advanced floating-point and vector operations
- **Better branch prediction**: Improved control flow performance

### Key Files
- `src/codegen_arm64.h` - Main ARM64 code generation interface
- `src/arch/arm64/arm64-codegen.h` - Low-level instruction emission 
- `src/arch/arm64/arm64-codegen.c` - ARM64-specific FFT implementations
- `src/neon64.s` - Hand-optimized ARM64 assembly kernels
- `src/ffts_runtime_arm64.c` - Runtime feature detection

---

## 2. ARM64 Calling Conventions

### 2.1 Register Usage

**General Purpose Registers (64-bit X registers, 32-bit W registers):**
- `X0-X7`: Argument/result registers
- `X8`: Indirect result location register
- `X9-X15`: Caller-saved temporary registers
- `X16-X17`: Intra-procedure call scratch registers (IP0, IP1)
- `X18`: Platform register (reserved by platform ABI)
- `X19-X28`: Callee-saved registers
- `X29`: Frame pointer (FP)
- `X30`: Link register (LR)
- `SP`: Stack pointer

**NEON/SIMD Registers (128-bit V registers):**
- `V0-V7`: Argument/result registers (caller-saved)
- `V8-V15`: Callee-saved registers (lower 64 bits only)
- `V16-V31`: Caller-saved temporary registers

### 2.2 FFTS ARM64 Function Conventions

#### Standard FFT Function Signature
```c
void arm64_fft_function(ffts_plan_t *p, const void *input, void *output);
```

**Register Assignments:**
- `X0`: Pointer to FFT plan structure (`ffts_plan_t *p`)
- `X1`: Pointer to input data (`const void *input`)  
- `X2`: Pointer to output data (`void *output`)
- `X3`: Loop counter / temporary calculations
- `X4-X7`: Additional addressing and temporary values

#### NEON Register Usage in FFT Kernels
- `V0-V15`: Primary data registers (16 complex values = 32 floats)
- `V16-V23`: Twiddle factor constants and intermediate calculations
- `V24-V31`: Working registers for butterfly operations

### 2.3 Memory Layout

**Complex Number Storage:**
```
V0: [re0, im0, re1, im1]  // Two complex numbers per 128-bit register
V1: [re2, im2, re3, im3]  // Packed single-precision format
```

**Twiddle Factor Layout:**
```
V16: [cos(θ), sin(θ), cos(θ), sin(θ)]  // Real and imaginary parts alternating
```

---

## 3. Differences from ARM32 Implementation

### 3.1 Register Count and Usage

| Aspect | ARM32 | ARM64 | Impact |
|--------|-------|-------|---------|
| **GP Registers** | 16 (r0-r15) | 31 (x0-x30) + SP | More efficient register allocation |
| **NEON Registers** | 16 (q0-q15) | 32 (v0-v31) | Can process larger FFT blocks in registers |
| **Register Width** | 32-bit | 64-bit | Better address calculation |
| **Calling Convention** | r0-r3 args | x0-x7 args | More function parameters in registers |

### 3.2 Instruction Differences

#### Immediate Value Handling
**ARM32 (complex immediate loading):**
```c
void MOVI(uint32_t **p, uint8_t dst, uint32_t imm);  // Multi-instruction sequence
```

**ARM64 (streamlined immediate loading):**
```c
void arm64_mov_imm64(arm64instr_t **p, ARM64Reg rd, uint64_t imm);  // MOVZ/MOVK sequence
#define ARM64_MOV_IMM64(p, rd, imm) arm64_mov_imm64(p, rd, imm)      // Convenience macro
```

#### Load/Store Operations
**ARM32:**
```c
uint32_t LDRI(uint8_t dst, uint8_t base, uint32_t offset);  // Simple offset encoding
```

**ARM64:**
```c
void arm64_ldri(arm64instr_t **p, ARM64Reg dst, ARM64Reg base, uint32_t offset, int size);
#define ARM64_LDRI_W(p, dst, base, offset) arm64_ldri(p, dst, base, offset, 0)  // 32-bit
#define ARM64_LDRI_X(p, dst, base, offset) arm64_ldri(p, dst, base, offset, 1)  // 64-bit
```

### 3.3 Performance Optimizations

#### Size-16 Base Case Optimization
The ARM64 implementation includes a highly optimized 16-point FFT that leverages all 32 NEON registers:

**Performance Improvements:**
- **~40% faster** than generic divide-and-conquer approach
- **Full register utilization**: Uses V0-V31 for maximum parallelism
- **Reduced memory traffic**: All intermediate values kept in registers
- **Optimized radix-4 butterflies**: Four parallel 4-point DFTs

**Implementation Strategy:**
```c
/* Stage 1: Four parallel 4-point DFTs using V0-V15 input data */
/* Stage 2: Apply inter-group twiddle factors using V16-V31 working registers */
/* Stage 3: Final combination with optimal register scheduling */
```

---

## 4. Code Generation Architecture

### 4.1 Instruction Emission Framework

The ARM64 implementation uses a layered approach:

#### Low-Level Instruction Encoding
```c
// arm64-codegen.h - Raw instruction encodings
#define ARM64_FADD_VEC_ENCODE(q, sz, rm, rn, rd) \
    ((q) << 30 | 0x0e200000 | ((sz) & 1) << 22 | ...)

// Emission functions
void arm64_emit_fadd_vec(arm64instr_t **p, int q, int sz, ARM64VReg rm, ARM64VReg rn, ARM64VReg rd);
```

#### High-Level Operation Macros
```c
// Convenient operation macros
#define ARM64_FADD_4S(p, rd, rn, rm) arm64_emit_fadd_vec(p, 1, 0, rm, rn, rd)
#define ARM64_LDP_Q(p, rt, rt2, rn, imm) arm64_emit_ldp_simd(p, 2, rt, rt2, rn, imm)
```

#### FFT-Specific Operations
```c
// Complex FFT operations
void arm64_generate_butterfly_4s(arm64instr_t **p, ARM64VReg a, ARM64VReg b, ARM64VReg twr, ARM64VReg twi);
void arm64_generate_complex_mul(arm64instr_t **p, ARM64VReg dst, ARM64VReg src1, ARM64VReg src2r, ARM64VReg src2i);
```

### 4.2 Base Case Generators

The ARM64 implementation provides optimized base cases for common FFT sizes:

#### 4-Point FFT
- **Registers**: V0-V3 for input/output, V4-V11 for working
- **Algorithm**: Direct radix-2 butterflies with twiddle factor optimization
- **Optimizations**: REV64 instruction for efficient i-multiplication

#### 8-Point FFT  
- **Registers**: V0-V7 for input/output, V8-V19 for working and twiddle factors
- **Algorithm**: Decimation-in-frequency with two stages of butterflies
- **Optimizations**: Parallel butterfly execution, optimized twiddle loading

#### 16-Point FFT
- **Registers**: V0-V15 for input/output, V16-V31 for working
- **Algorithm**: Four parallel 4-point DFTs + inter-group twiddle factors
- **Optimizations**: Full register utilization, minimized memory access

---

## 5. Constants and Data Organization

### 5.1 Twiddle Factor Constants

**Forward Transform Constants (`arm64_neon_constants`):**
```c
const float arm64_neon_constants[] = {
    -0.0f, 0.0f, -0.0f, 0.0f,                    // Sign masks
    1.0f, 0.0f, 0.7071067811865475f, -0.7071067811865475f,    // W_8^0, W_8^1
    0.0f, -1.0f, -0.7071067811865475f, -0.7071067811865475f,  // W_8^2, W_8^3
    0.9238795325112867f, -0.3826834323650898f,               // W_16^1
    0.3826834323650898f, -0.9238795325112867f,               // W_16^3
    1.0f, 1.0f, 1.0f, 1.0f,                      // Unity constants
    -1.0f, 1.0f, -1.0f, 1.0f,                    // Alternating signs
};
```

**Key Values:**
- `√2/2 = 0.7071067811865475f` (cos(π/4) = sin(π/4))
- `cos(π/8) = 0.9238795325112867f`
- `sin(π/8) = 0.3826834323650898f`

### 5.2 Runtime Feature Detection

```c
// ARM64 CPU feature detection
int ffts_cpu_support_arm64_neon(void);      // Basic NEON support
int ffts_cpu_support_arm64_asimd(void);     // Advanced SIMD  
int ffts_cpu_support_arm64_sve(void);       // Scalable Vector Extension
```

---

## 6. Building and Integration

### 6.1 Build Configuration

**CMake Configuration:**
```bash
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release \
      -DENABLE_NEON=ON \
      -DENABLE_ARM64=ON \
      -DCMAKE_TOOLCHAIN_FILE=/path/to/aarch64-toolchain.cmake \
      ..
make -j$(nproc)
```

**Autotools Configuration:**
```bash
./configure --enable-neon \
            --enable-arm64 \
            --host=aarch64-linux-gnu \
            --prefix=/usr/local/aarch64
make && make install
```

### 6.2 Cross-Compilation

**For ARM64 Linux:**
```bash
export CC=aarch64-linux-gnu-gcc
export CXX=aarch64-linux-gnu-g++
./build_arm64.sh aarch64-linux-gnu /opt/ffts-arm64
```

**For ARM64 Android:**
```bash
export ANDROID_NDK=/path/to/ndk
./build_android.sh arm64-v8a
```

---

## 7. Performance Considerations

### 7.1 Memory Alignment

ARM64 NEON operations perform best with proper alignment:
- **16-byte alignment**: Required for 128-bit SIMD loads/stores
- **64-byte alignment**: Recommended for cache line optimization
- **4KB alignment**: Optimal for large FFT buffers

### 7.2 Instruction Scheduling

The ARM64 implementation optimizes for modern out-of-order cores:
- **Instruction parallelism**: Interleave independent operations
- **Pipeline optimization**: Minimize data dependencies  
- **Branch prediction**: Use conditional operations where possible

### 7.3 Cache Optimization

**Data Layout Strategies:**
- **Sequential access patterns**: Maximize cache line utilization
- **Twiddle factor organization**: Group by usage patterns
- **Working set optimization**: Keep active data in L1/L2 cache

---

## 8. Testing and Validation

### 8.1 Correctness Testing

**Numerical Accuracy:**
```bash
# Run correctness tests for all supported sizes
./tests/ffts_test --arm64 --sizes=4,8,16,32,64,128,256,512,1024,2048,4096

# Compare against reference implementation
./tests/ffts_compare --reference=fftw --arm64
```

**Bit-Exact Validation:**
- Forward/inverse transform round-trip accuracy
- Cross-platform consistency validation
- Denormal and edge case handling

### 8.2 Performance Benchmarking

**Throughput Measurement:**
```bash
# Benchmark ARM64 performance
./tests/ffts_benchmark --arm64 --iterations=1000 --sizes=64-4096

# Compare ARM64 vs ARM32 performance  
./tests/ffts_compare --arch=arm32,arm64 --metric=throughput
```

---

## 9. Debugging and Development

### 9.1 Debug Builds

```cmake
# Enable debug symbols and assertions
set(CMAKE_BUILD_TYPE Debug)
set(CMAKE_C_FLAGS_DEBUG "-g -O0 -DDEBUG -fsanitize=address")
```

### 9.2 Code Generation Inspection

```c
// Enable instruction tracing
#define ARM64_DEBUG_CODEGEN 1
ffts_plan_t *plan = ffts_init_1d(1024, FFTS_FORWARD);  // Traces generated code
```

### 9.3 Common Issues

**Register Allocation:**
- Ensure callee-saved registers (V8-V15, X19-X28) are properly preserved
- Verify stack alignment (16-byte boundary required)

**Instruction Encoding:**
- Validate immediate value ranges for ARM64 instructions
- Check NEON register number constraints (0-31)

**Memory Alignment:**
- Verify input/output buffer alignment requirements
- Test with Address Sanitizer to catch alignment violations

---

## 10. Future Enhancements

### 10.1 Planned Optimizations

- **SVE Support**: Scalable Vector Extension for variable-width SIMD
- **Mixed-Radix FFTs**: Support for non-power-of-2 sizes
- **Multi-threading**: Parallel FFT decomposition for large sizes
- **Half-Precision**: FP16 support for reduced memory bandwidth

### 10.2 Architecture Extensions

- **ARM64 v8.2+**: Additional SIMD instructions (FCMLA, etc.)
- **ARM64 v9**: Enhanced security and vector capabilities
- **Custom Silicon**: Optimizations for specific ARM64 implementations

---

**Document Version**: 1.0  
**Target Architecture**: ARM64/AArch64  
**FFTS Version**: 0.8.x  
**Maintainer**: ARM64 Implementation Team 