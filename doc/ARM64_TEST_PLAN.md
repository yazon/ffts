# ARM64 FFTS Testing and Validation Plan

_Last updated: 2025-07-23_

This document outlines the comprehensive testing strategy for validating the ARM64/AArch64 implementation of FFTS, ensuring correctness, performance, and compatibility across different ARM64 hardware configurations.

---

## 1. Test Categories

### 1.1 Correctness Tests
- **Numerical accuracy validation**
- **Cross-platform consistency checks**  
- **Edge case and boundary condition testing**
- **Forward/inverse transform round-trip verification**

### 1.2 Performance Tests
- **Throughput benchmarking across FFT sizes**
- **Memory bandwidth utilization analysis**
- **Instruction cache efficiency measurement**
- **ARM64 vs ARM32 performance comparison**

### 1.3 Compatibility Tests
- **Hardware feature detection validation**
- **Different ARM64 CPU core testing**
- **Operating system compatibility verification**
- **Compiler toolchain validation**

---

## 2. Test Infrastructure

### 2.1 Test Harness Structure
```
tests/
├── arm64/
│   ├── correctness/
│   │   ├── accuracy_test.c          # Numerical accuracy validation
│   │   ├── roundtrip_test.c         # Forward/inverse round-trip
│   │   ├── reference_compare.c      # Compare against FFTW/reference
│   │   └── edge_cases_test.c        # Boundary conditions
│   ├── performance/
│   │   ├── benchmark_suite.c        # Performance measurement
│   │   ├── memory_bandwidth.c       # Memory usage analysis  
│   │   ├── register_pressure.c      # Register utilization
│   │   └── cache_efficiency.c       # Cache behavior analysis
│   ├── compatibility/
│   │   ├── cpu_detection_test.c     # Feature detection validation
│   │   ├── cross_platform_test.c    # Platform consistency
│   │   └── toolchain_test.c         # Compiler compatibility
│   └── integration/
│       ├── build_test.sh            # Build system validation
│       ├── install_test.sh          # Installation verification
│       └── api_compatibility.c      # API backward compatibility
```

### 2.2 Test Data Generation

#### Reference Data Sources
- **FFTW3**: Industry standard reference implementation
- **Analytical solutions**: Known mathematical results for specific inputs
- **Cross-validation**: ARM32 implementation comparison
- **Published test vectors**: IEEE and academic reference data

#### Test Signal Types
```c
typedef enum {
    TEST_SIGNAL_IMPULSE,        // δ[n] - impulse response
    TEST_SIGNAL_SINE,           // Pure sinusoid
    TEST_SIGNAL_CHIRP,          // Frequency sweep
    TEST_SIGNAL_NOISE,          // White/pink noise
    TEST_SIGNAL_COMPLEX_EXP,    // Complex exponential
    TEST_SIGNAL_RANDOM,         // Pseudorandom sequences
    TEST_SIGNAL_PATHOLOGICAL    // Edge cases (NaN, inf, denorms)
} test_signal_type_t;
```

---

## 3. Correctness Validation

### 3.1 Numerical Accuracy Tests

#### Single-Precision Accuracy Targets
- **Forward FFT error**: < 1e-5 relative error
- **Inverse FFT error**: < 1e-5 relative error  
- **Round-trip error**: < 1e-4 relative error
- **Scaling consistency**: Verify proper normalization

#### Test Implementation
```c
// Accuracy test for ARM64 FFT implementation
float test_fft_accuracy(size_t N, test_signal_type_t signal_type) {
    float *input = generate_test_signal(N, signal_type);
    float *expected = compute_reference_fft(input, N);
    float *actual = compute_arm64_fft(input, N);
    
    float max_error = 0.0f;
    for (size_t i = 0; i < N; i++) {
        float error = fabsf(actual[i] - expected[i]) / fabsf(expected[i]);
        max_error = fmaxf(max_error, error);
    }
    
    return max_error;
}
```

### 3.2 Size Coverage Matrix

| FFT Size | Base Case | Algorithm | Priority | Test Signals |
|----------|-----------|-----------|----------|--------------|
| **4** | ✓ Direct | Radix-2 | High | All types |
| **8** | ✓ Direct | Radix-2 | High | All types |
| **16** | ✓ Optimized | Radix-4 | Critical | All types |
| **32** | Composite | Radix-2 | High | Sine, Noise |
| **64** | Composite | Radix-2 | High | Sine, Noise |
| **128** | Composite | Mixed | Medium | Sine, Random |
| **256** | Composite | Mixed | Medium | Sine, Random |
| **512** | Composite | Mixed | Medium | Chirp, Random |
| **1024** | Composite | Mixed | High | All types |
| **2048** | Composite | Mixed | Medium | Sine, Noise |
| **4096** | Composite | Mixed | Low | Sine, Noise |

### 3.3 Round-Trip Validation
```c
// Verify F^-1(F(x)) ≈ x for all test cases
bool test_roundtrip_accuracy(size_t N) {
    float *original = generate_test_signal(N, TEST_SIGNAL_RANDOM);
    float *workspace = aligned_alloc(64, N * 2 * sizeof(float));
    
    // Forward transform
    ffts_plan_t *forward = ffts_init_1d(N, FFTS_FORWARD);
    ffts_execute(forward, original, workspace);
    
    // Inverse transform  
    ffts_plan_t *inverse = ffts_init_1d(N, FFTS_BACKWARD);
    ffts_execute(inverse, workspace, workspace);
    
    // Check accuracy (accounting for scaling)
    float max_error = 0.0f;
    for (size_t i = 0; i < N * 2; i++) {
        float error = fabsf(workspace[i] - original[i] * N) / fabsf(original[i] * N);
        max_error = fmaxf(max_error, error);
    }
    
    ffts_free(forward);
    ffts_free(inverse);
    free(workspace);
    
    return max_error < 1e-4f;
}
```

---

## 4. Performance Benchmarking

### 4.1 Throughput Measurement

#### Performance Metrics
- **MFLOPS**: Million floating-point operations per second
- **Samples/sec**: Transform throughput
- **Cycles/sample**: CPU efficiency metric
- **Memory BW**: Data transfer efficiency

#### Benchmark Implementation
```c
typedef struct {
    size_t size;
    double mflops;
    double samples_per_sec;
    double cycles_per_sample;
    double memory_bandwidth_gbps;
} benchmark_result_t;

benchmark_result_t benchmark_arm64_fft(size_t N, int iterations) {
    ffts_plan_t *plan = ffts_init_1d(N, FFTS_FORWARD);
    float *input = aligned_alloc(64, N * 2 * sizeof(float));
    float *output = aligned_alloc(64, N * 2 * sizeof(float));
    
    // Warm-up
    for (int i = 0; i < 10; i++) {
        ffts_execute(plan, input, output);
    }
    
    // Timed measurement
    uint64_t start_cycles = read_cycles();
    auto start_time = high_resolution_clock::now();
    
    for (int i = 0; i < iterations; i++) {
        ffts_execute(plan, input, output);
    }
    
    uint64_t end_cycles = read_cycles();
    auto end_time = high_resolution_clock::now();
    
    double elapsed_sec = duration_cast<microseconds>(end_time - start_time).count() / 1e6;
    double cycles = (double)(end_cycles - start_cycles) / iterations;
    
    benchmark_result_t result = {
        .size = N,
        .mflops = (5.0 * N * log2(N) * iterations) / (elapsed_sec * 1e6),
        .samples_per_sec = (N * iterations) / elapsed_sec,
        .cycles_per_sample = cycles / N,
        .memory_bandwidth_gbps = (N * 2 * sizeof(float) * iterations) / (elapsed_sec * 1e9)
    };
    
    ffts_free(plan);
    free(input);
    free(output);
    
    return result;
}
```

### 4.2 Performance Targets

#### ARM64 vs ARM32 Improvement Targets
| FFT Size | ARM32 Baseline | ARM64 Target | Expected Improvement |
|----------|----------------|--------------|----------------------|
| **16** | Generic impl. | Optimized radix-4 | **40%** faster |
| **64** | NEON optimized | Enhanced NEON | **20%** faster |
| **256** | Cache-friendly | Better cache usage | **15%** faster |
| **1024** | Memory-bound | Prefetch optimization | **10%** faster |

#### Hardware-Specific Targets
- **Cortex-A78**: > 2.5 GFLOPS for 1024-point FFT
- **Cortex-X1**: > 3.0 GFLOPS for 1024-point FFT  
- **Apple M1**: > 4.0 GFLOPS for 1024-point FFT
- **Graviton3**: > 2.8 GFLOPS for 1024-point FFT

---

## 5. Compatibility Testing

### 5.1 CPU Feature Detection
```c
// Test ARM64 feature detection accuracy
bool test_cpu_feature_detection(void) {
    bool neon_detected = ffts_cpu_support_arm64_neon();
    bool asimd_detected = ffts_cpu_support_arm64_asimd();
    
    // Verify against system capabilities
    FILE *cpuinfo = fopen("/proc/cpuinfo", "r");
    char line[256];
    bool neon_in_cpuinfo = false;
    bool asimd_in_cpuinfo = false;
    
    while (fgets(line, sizeof(line), cpuinfo)) {
        if (strstr(line, "neon")) neon_in_cpuinfo = true;
        if (strstr(line, "asimd")) asimd_in_cpuinfo = true;
    }
    
    fclose(cpuinfo);
    
    return (neon_detected == neon_in_cpuinfo) && 
           (asimd_detected == asimd_in_cpuinfo);
}
```

### 5.2 Cross-Platform Validation

#### Target Platforms
- **Linux ARM64**: Ubuntu 20.04+, CentOS 8+, Alpine Linux
- **Android ARM64**: API levels 21+ (Android 5.0+)
- **macOS ARM64**: macOS 11+ (Apple Silicon)
- **Windows ARM64**: Windows 10+ on ARM

#### Compiler Compatibility
- **GCC**: 8.0+ with `-march=armv8-a+simd`
- **Clang**: 10.0+ with ARM64 target support
- **MSVC**: Visual Studio 2019+ ARM64 compiler
- **Cross-compilers**: aarch64-linux-gnu-gcc, Android NDK

---

## 6. Test Execution Framework

### 6.1 Automated Test Scripts

#### Master Test Runner
```bash
#!/bin/bash
# ARM64 FFTS Test Suite Runner

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/../build/arm64"
TEST_RESULTS="$SCRIPT_DIR/results"

# Test configuration
FFT_SIZES=(4 8 16 32 64 128 256 512 1024 2048 4096)
ITERATIONS=1000
TOLERANCE=1e-5

echo "ARM64 FFTS Test Suite"
echo "===================="
echo "Build dir: $BUILD_DIR"
echo "Test sizes: ${FFT_SIZES[*]}"
echo "Iterations: $ITERATIONS"
echo

mkdir -p "$TEST_RESULTS"

# Run correctness tests
echo "Running correctness tests..."
for size in "${FFT_SIZES[@]}"; do
    echo -n "  Size $size: "
    if "$BUILD_DIR/tests/accuracy_test" --size="$size" --tolerance="$TOLERANCE"; then
        echo "PASS"
    else
        echo "FAIL"
        exit 1
    fi
done

# Run performance benchmarks  
echo
echo "Running performance benchmarks..."
"$BUILD_DIR/tests/benchmark_suite" --iterations="$ITERATIONS" --output="$TEST_RESULTS/benchmark.json"

# Generate test report
echo
echo "Generating test report..."
python3 "$SCRIPT_DIR/generate_report.py" --results="$TEST_RESULTS" --output="$TEST_RESULTS/arm64_test_report.html"

echo
echo "All tests completed successfully!"
echo "Report available at: $TEST_RESULTS/arm64_test_report.html"
```

### 6.2 Continuous Integration

#### GitHub Actions Workflow
```yaml
name: ARM64 FFTS Tests

on: [push, pull_request]

jobs:
  arm64-tests:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Install ARM64 cross-compilation tools
      run: |
        sudo apt-get update
        sudo apt-get install -y gcc-aarch64-linux-gnu qemu-user-static
        
    - name: Build ARM64 FFTS
      run: |
        ./build_arm64.sh aarch64-linux-gnu ./build/arm64
        
    - name: Run emulated ARM64 tests
      run: |
        cd tests/arm64
        qemu-aarch64-static -L /usr/aarch64-linux-gnu ./run_tests.sh
        
    - name: Upload test results
      uses: actions/upload-artifact@v3
      with:
        name: arm64-test-results
        path: tests/results/
```

---

## 7. Hardware Test Matrix

### 7.1 Target Hardware Configurations

#### Development Boards
- **Raspberry Pi 4**: Cortex-A72, 4GB RAM, Raspbian OS
- **NVIDIA Jetson Nano**: Cortex-A57, 4GB RAM, Ubuntu 18.04
- **Rock Pi 4**: Cortex-A72/A53, 4GB RAM, Debian
- **Pine64**: Cortex-A53, 2GB RAM, Linux

#### Cloud Instances
- **AWS Graviton3**: c7g.large, Amazon Linux 2
- **Azure Ampere**: Standard_D2ps_v5, Ubuntu 20.04  
- **Google Cloud T2A**: t2a-standard-2, Ubuntu 20.04
- **Oracle Ampere**: VM.Standard.A1.Flex, Oracle Linux 8

#### Consumer Devices
- **Apple M1 MacBooks**: macOS Big Sur+
- **Microsoft Surface Pro X**: Windows 11 ARM64
- **Samsung Galaxy S21**: Android 11, Snapdragon 888
- **Qualcomm DevKit**: Snapdragon 8cx Gen 3

### 7.2 Test Coverage Requirements

#### Minimum Test Coverage
- **At least 2 different ARM64 CPU architectures** (e.g., Cortex-A78 + Apple M1)
- **At least 2 different operating systems** (e.g., Linux + macOS)
- **At least 2 different compiler toolchains** (e.g., GCC + Clang)

#### Validation Criteria for Hardware Certification
1. **All correctness tests pass** with tolerance < 1e-5
2. **Performance meets targets** for respective hardware class
3. **Round-trip accuracy** within 1e-4 relative error
4. **No crashes or memory violations** under stress testing
5. **Feature detection** correctly identifies hardware capabilities

---

## 8. Expected Results and Success Criteria

### 8.1 Correctness Success Criteria
- **100% pass rate** on all accuracy tests for sizes 4-4096
- **Round-trip error < 1e-4** for all test signal types
- **Cross-platform consistency** within floating-point precision limits
- **Reference comparison error < 1e-5** vs FFTW3 results

### 8.2 Performance Success Criteria  
- **ARM64 16-point FFT ≥ 40% faster** than ARM32 baseline
- **Overall throughput improvement ≥ 15%** across all sizes
- **Memory bandwidth utilization ≥ 80%** of theoretical peak
- **Instruction cache efficiency ≥ 95%** (minimal cache misses)

### 8.3 Compatibility Success Criteria
- **Build success** on all target toolchains
- **Runtime compatibility** across all target platforms  
- **Feature detection accuracy** 100% for supported hardware
- **API backward compatibility** with existing FFTS applications

---

## 9. Risk Mitigation

### 9.1 Potential Issues and Mitigations

#### Numerical Accuracy Issues
- **Risk**: Precision loss in optimized implementations
- **Mitigation**: Extensive reference comparison testing
- **Fallback**: Graceful degradation to reference implementation

#### Performance Regression  
- **Risk**: Optimizations may not perform as expected on all hardware
- **Mitigation**: Hardware-specific performance profiling
- **Fallback**: Runtime algorithm selection based on benchmarking

#### Hardware Compatibility
- **Risk**: Code may not work on all ARM64 variants
- **Mitigation**: Conservative feature detection and graceful fallbacks
- **Fallback**: Generic ARM64 implementation for unsupported features

### 9.2 Test Data Management
- **Reference datasets**: Version-controlled reference results
- **Reproducibility**: Fixed random seeds for deterministic tests
- **Archival**: Long-term storage of test results for regression analysis

---

## 10. Future Test Enhancements

### 10.1 Advanced Testing Scenarios
- **Multi-threaded FFT testing** for parallel implementations
- **Memory pressure testing** under constrained memory conditions
- **Thermal throttling behavior** under sustained workloads
- **Power consumption analysis** for mobile/embedded applications

### 10.2 Extended Validation
- **Fuzzing integration** for robustness testing
- **Static analysis** with tools like Clang Static Analyzer
- **Dynamic analysis** with AddressSanitizer and Valgrind
- **Formal verification** of critical algorithm components

---

**Document Version**: 1.0  
**Target Architecture**: ARM64/AArch64  
**Test Framework**: Custom + Standard Tools  
**Validation Level**: Production Ready 