# FFTS Architecture Documentation

## Project Overview

**FFTS (The Fastest Fourier Transform in the South)** is a high-performance, optimized Fast Fourier Transform (FFT) library written in C. The library is designed to provide exceptional performance across multiple platforms through platform-specific optimizations and runtime code generation.

- **Version**: 0.9.0 (CMake) / 0.7 (Autotools)
- **Primary Author**: Anthony M. Blake <amb@anthonix.com>
- **Institution**: University of Waikato
- **License**: BSD 3-Clause
- **Contributors**: Michael Zucchi (JNI/Android), Michael Cree (Architecture-specific optimizations)

## Key Features

- **Dynamic Code Generation**: Runtime optimization for maximum performance
- **Multi-Platform Support**: x86/x64, ARM 32-bit (NEON/VFP), ARM 64-bit (AArch64 NEON), MIPS, PowerPC, SPARC, Alpha, and more
- **SIMD Optimizations**: SSE, SSE2, SSE3, ARM64 Advanced NEON, ARM32 NEON, VFP, AltiVec support
- **Multiple Precision**: Single and double precision floating-point
- **Real & Complex FFTs**: 1D, 2D, and N-dimensional transforms
- **Mobile Platform Support**: Android and iOS build scripts included
- **JNI Bindings**: Java Native Interface support for Android/Java integration

## Build Systems & Configuration

### CMake Build System (Primary)
- **File**: `CMakeLists.txt` (553 lines)
- **Features**:
  - Cross-platform compilation
  - Automatic SIMD detection
  - Static/shared library generation
  - Position-independent code support
  - Package config generation

### Autotools Build System (Secondary)
- **Files**: `configure.ac`, `Makefile.am`, `Makefile.in`
- **Features**:
  - Traditional Unix build system
  - Platform detection and configuration
  - Flexible compiler flag management

### Platform-Specific Build Scripts
- **Android**: `build_android.sh` - NDK-based Android library compilation
- **iOS**: `build_iphone.sh` - Xcode toolchain iOS library compilation

## Architecture & Directory Structure

```
ffts/
├── include/                    # Public API headers
│   └── ffts.h                 # Main library interface
├── src/                       # Core implementation
│   ├── ffts.c                 # Main library implementation
│   ├── ffts_*.{c,h}          # Core algorithms (real, ND, transpose, etc.)
│   ├── macros*.h             # Platform-specific SIMD macros
│   ├── codegen*.{c,h}        # Dynamic code generation
│   ├── patterns.h            # FFT algorithm patterns
│   ├── arch/                 # Architecture-specific code
│   │   ├── arm/              # ARM 32-bit assembly and codegen
│   │   ├── arm64/            # ARM 64-bit (AArch64) codegen and optimizations
│   │   ├── x86/              # x86 optimizations
│   │   ├── x64/              # x86-64 optimizations
│   │   ├── mips/             # MIPS optimizations
│   │   ├── ppc/              # PowerPC optimizations
│   │   └── ...               # Other architectures
│   ├── neon.s                # ARM 32-bit NEON assembly
│   ├── neon64.s              # ARM 64-bit AArch64 NEON assembly
│   ├── vfp.s                 # ARM VFP assembly
│   ├── neon_static.s         # Static NEON implementations
│   ├── macros-neon64.h       # ARM64 NEON SIMD macros
│   ├── ffts_runtime_arm64.{c,h} # ARM64 runtime CPU feature detection
│   └── codegen_arm64.h       # ARM64 dynamic code generation
├── tests/                     # Test suite
├── java/                      # JNI bindings
│   ├── android/              # Android-specific JNI
│   ├── jni/                  # Generic JNI implementation
│   └── src/                  # Java wrapper classes
├── m4/                       # Autotools macros
└── build_*.sh               # Platform build scripts
```

## Supported Platforms & Architectures

### Primary Platforms
- **Linux**: x86, x86-64, ARM, MIPS, PowerPC
- **Windows**: x86, x86-64 (Visual Studio, MinGW)
- **macOS**: x86-64, ARM64 (Apple Silicon)
- **Android**: ARM (NEON), x86, MIPS
- **iOS**: ARM (NEON), ARM64

### SIMD Instruction Sets
- **x86/x64**: SSE, SSE2, SSE3
- **ARM 32-bit**: NEON, VFP
- **ARM 64-bit (AArch64)**: Advanced NEON 128-bit operations with runtime CPU feature detection
- **PowerPC**: AltiVec
- **Alpha**: Architecture-specific optimizations

### Precision Support
- **Single Precision** (32-bit float): Primary focus, optimized
- **Double Precision** (64-bit double): Supported

## Core Components

### 1. Main API (`include/ffts.h`)
```c
// 1D, 2D, and N-dimensional FFT planning
ffts_plan_t* ffts_init_1d(size_t N, int sign);
ffts_plan_t* ffts_init_2d(size_t N1, size_t N2, int sign);
ffts_plan_t* ffts_init_nd(int rank, size_t *Ns, int sign);

// Real FFT variants
ffts_plan_t* ffts_init_1d_real(size_t N, int sign);
ffts_plan_t* ffts_init_2d_real(size_t N1, size_t N2, int sign);
ffts_plan_t* ffts_init_nd_real(int rank, size_t *Ns, int sign);

// Execution and cleanup
void ffts_execute(ffts_plan_t *p, const void *input, void *output);
void ffts_free(ffts_plan_t *p);
```

### 2. Dynamic Code Generation (`src/codegen.c`, `src/codegen_*.h`)
- **Runtime Optimization**: Generates optimized machine code at runtime
- **Platform-Specific**: SSE codegen for x86-64, ARM codegen for ARM platforms
- **Memory Management**: Uses virtual memory allocation with execute permissions
- **Cache Management**: Instruction cache invalidation for generated code

### 3. Static Implementations (`src/ffts_static.c`, `src/ffts_static.h`)
- **Fallback Option**: When dynamic code generation is disabled
- **Small FFTs**: Optimized implementations for common small sizes (2, 4, 8, 16)
- **Platform Coverage**: Works on all platforms without codegen requirements

### 4. SIMD Optimizations
- **Macro System**: Platform-specific SIMD macros in `src/macros-*.h`
- **Assembly Code**: Hand-optimized assembly for ARM NEON and VFP
- **Compiler Intrinsics**: SSE intrinsics for x86 platforms
- **Runtime Detection**: Automatic SIMD capability detection

## Configuration Options

### CMake Options
```cmake
ENABLE_NEON                    # Enable ARM NEON instructions
ENABLE_VFP                     # Enable ARM VFP instructions  
DISABLE_DYNAMIC_CODE           # Disable runtime code generation
GENERATE_POSITION_INDEPENDENT_CODE  # Generate PIC code
ENABLE_SHARED                  # Build shared library
ENABLE_STATIC                  # Build static library
```

### Autotools Options
```bash
--enable-sse                   # Enable SSE optimizations
--enable-single                # Compile single-precision library
--enable-neon                  # Enable NEON optimizations
--enable-vfp                   # Enable VFP optimizations
--enable-jni                   # Enable JNI bindings
--disable-dynamic-code         # Disable dynamic code generation
--with-float-abi=[hard|softfp] # Set ARM float ABI
```

## Performance Features

### 1. Algorithm Optimizations
- **Split-Radix FFT**: High-performance core algorithm
- **Cache-Friendly**: Memory access patterns optimized for cache hierarchy
- **Loop Unrolling**: Aggressive optimization for small FFT sizes
- **SIMD Vectorization**: Platform-specific vectorized operations

### 2. Memory Management
- **Aligned Memory**: 16-byte alignment requirements for SIMD operations
- **Virtual Memory**: Code generation uses virtual memory allocation
- **Memory Pool**: Efficient workspace allocation for intermediate results

### 3. Runtime Optimization
- **Dynamic Dispatch**: Optimal function selection based on problem size
- **Code Generation**: Runtime compilation for maximum performance
- **Lookup Tables**: Pre-computed trigonometric values

## Mobile Platform Support

### Android Integration
- **NDK Support**: Native Development Kit compilation
- **JNI Interface**: Java bindings for Android applications
- **Library Project**: Ready-to-use Android library project
- **Multi-Architecture**: ARM, x86, MIPS support

### iOS Integration  
- **Xcode Integration**: Compatible with iOS development toolchain
- **ARM Optimization**: NEON-optimized for iOS devices
- **Static Library**: Easy integration into iOS projects

## Testing & Validation

### Test Suite (`tests/`)
- **Accuracy Tests**: Numerical accuracy validation
- **Performance Benchmarks**: Speed comparison testing
- **Platform Coverage**: Tests across all supported platforms
- **Regression Testing**: Continuous integration with Travis CI

### Quality Assurance
- **Memory Safety**: Proper memory management and bounds checking
- **Thread Safety**: Concurrent execution support
- **Error Handling**: Robust error detection and reporting

## Development & Contribution

### Code Organization
- **Modular Design**: Clear separation of concerns
- **Platform Abstraction**: Clean separation of platform-specific code
- **Documentation**: Comprehensive inline documentation
- **Consistent Style**: Unified coding standards

### Build Requirements
- **C Compiler**: GCC, Clang, MSVC support
- **Assembly**: Platform-specific assembler support
- **CMake**: Version 2.8.12 or higher
- **Optional**: JDK for JNI bindings, Android NDK for mobile

## License & Distribution

- **License**: BSD 3-Clause License
- **Commercial Use**: Permitted
- **Distribution**: Source and binary distribution allowed
- **Attribution**: Original copyright notice required
- **Patents**: No patent restrictions

## Future Considerations

### Potential Enhancements
- **AVX/AVX2 Support**: Modern x86 SIMD extensions
- **GPU Acceleration**: CUDA/OpenCL implementations
- **ARM64 Optimization**: Apple Silicon and AArch64 improvements
- **Memory Bandwidth**: Further memory access optimizations

### Maintenance Notes
- **Active Forks**: More recent development occurs in linkotec and ValveSoftware forks
- **Original Repo**: No longer actively maintained by original author
- **Community**: Active community development continues in forks 