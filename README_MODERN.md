# FFTS Modern Build System

This document describes the modernized build system for FFTS (Fastest Fourier Transform in the South), which has been upgraded to meet 2024/2025 industry standards.

## 🚀 Quick Start

### Prerequisites

- **CMake 3.25 or later**
- **C compiler** (GCC, Clang, or MSVC)
- **Python 3.6+** (for the unified build interface)

### Basic Usage

```bash
# Clone the repository
git clone https://github.com/linkotec/ffts.git
cd ffts

# Build with default settings
./build.py build

# Or use the interactive configuration
./build.py --interactive

# Run tests
./build.py test

# Install
./build.py install
```

## 📋 Features

### Modern Build System
- **CMake 3.25+** with modern best practices
- **Target-based approach** for better dependency management
- **Proper package configuration** for easy integration
- **Cross-platform support** (Linux, Windows, macOS)

### Unified Build Interface
- **Single entry point** (`build.py`) for all build operations
- **Interactive configuration wizard** for easy setup
- **Preset configurations** for common use cases
- **Comprehensive error handling** with helpful messages

### Cross-Platform & Cross-Compilation
- **Multi-architecture support**: x86_64, ARM64, RISC-V
- **Cross-compilation toolchains** with auto-detection
- **QEMU integration** for testing cross-compiled binaries
- **Docker-based builds** for reproducible environments

### Developer Experience
- **Parallel builds** with optimal CPU utilization
- **Incremental builds** for faster development cycles
- **Comprehensive testing** with multiple configurations
- **Code quality checks** with sanitizers and static analysis

## 🛠️ Build Options

### Preset Configurations

The build system includes several preset configurations for common use cases:

```bash
# Debug build with all debugging features
./build.py --preset debug build

# Release build optimized for performance
./build.py --preset release build

# Minimal build for embedded systems
./build.py --preset minimal build

# Android build with NEON optimizations
./build.py --preset android build

# iOS build with ARM64 optimizations
./build.py --preset ios build
```

### Custom Configuration

You can customize the build configuration interactively:

```bash
# Run interactive configuration wizard
./build.py --interactive

# Show current configuration
./build.py --show-config
```

### Build Actions

```bash
# Configure only
./build.py configure

# Build only (requires previous configure)
./build.py build

# Build with clean (removes previous build)
./build.py --clean build

# Run tests
./build.py test

# Install to system
./build.py install

# Clean build artifacts
./build.py clean

# Complete build cycle (configure, build, test, install)
./build.py all
```

## 🏗️ Architecture Support

### Automatic Detection

The build system automatically detects your platform and enables appropriate optimizations:

- **Linux x86_64**: SSE/SSE2/SSE3 optimizations
- **Linux ARM64**: NEON optimizations
- **macOS ARM64**: NEON optimizations with position-independent code
- **Windows x64**: SSE optimizations with shared library support

### Manual Configuration

You can manually control architecture-specific features:

```bash
# Enable NEON for ARM
./build.py configure -DENABLE_NEON=ON

# Enable SSE for x86
./build.py configure -DENABLE_SSE=ON

# Disable dynamic code generation
./build.py configure -DDISABLE_DYNAMIC_CODE=ON

# Enable position-independent code
./build.py configure -DGENERATE_POSITION_INDEPENDENT_CODE=ON
```

## 🔧 Cross-Compilation

### Linux to ARM64

```bash
# Install cross-compilation toolchain
sudo apt-get install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu

# Configure for ARM64
mkdir build-arm64
cd build-arm64
cmake .. \
  -DCMAKE_SYSTEM_NAME=Linux \
  -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
  -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
  -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ \
  -DENABLE_NEON=ON \
  -DENABLE_TESTS=OFF

# Build
cmake --build . --parallel
```

### Linux to RISC-V

```bash
# Install RISC-V toolchain
sudo apt-get install gcc-riscv64-linux-gnu g++-riscv64-linux-gnu

# Configure for RISC-V
mkdir build-riscv64
cd build-riscv64
cmake .. \
  -DCMAKE_SYSTEM_NAME=Linux \
  -DCMAKE_SYSTEM_PROCESSOR=riscv64 \
  -DCMAKE_C_COMPILER=riscv64-linux-gnu-gcc \
  -DCMAKE_CXX_COMPILER=riscv64-linux-gnu-g++ \
  -DDISABLE_DYNAMIC_CODE=ON \
  -DENABLE_TESTS=OFF

# Build
cmake --build . --parallel
```

## 🐳 Docker Support

### Build Environment

Create a reproducible build environment using Docker:

```dockerfile
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    ninja-build \
    python3 \
    git

# Clone and build FFTS
RUN git clone https://github.com/linkotec/ffts.git /ffts
WORKDIR /ffts
RUN ./build.py --preset release build
```

### Multi-Architecture Build

```bash
# Build for multiple architectures
docker buildx build --platform linux/amd64,linux/arm64,linux/riscv64 .
```

## 🧪 Testing

### Running Tests

```bash
# Run all tests
./build.py test

# Run tests with verbose output
cd build
ctest --output-on-failure --verbose

# Run specific test
cd build
./bin/ffts_test
```

### Test with Sanitizers

```bash
# Configure with sanitizers
mkdir build-sanitize
cd build-sanitize
cmake .. \
  -DCMAKE_BUILD_TYPE=Debug \
  -DENABLE_SANITIZERS=ON \
  -DENABLE_TESTS=ON

# Build and test
cmake --build . --parallel
ctest --output-on-failure --verbose
```

## 📦 Package Management

### CMake Integration

FFTS can be easily integrated into other CMake projects:

```cmake
# Find FFTS package
find_package(ffts REQUIRED)

# Link against FFTS
target_link_libraries(your_target ffts::ffts)

# Or use specific targets
target_link_libraries(your_target ffts::ffts_static)
target_link_libraries(your_target ffts::ffts_shared)
```

### pkg-config Integration

On Unix-like systems, FFTS provides pkg-config support:

```bash
# Compile with pkg-config
gcc -o myapp myapp.c $(pkg-config --cflags --libs ffts)
```

## 🔄 Migration from Old Build System

### From Autotools

If you were using the old autotools build system:

```bash
# Old way
./configure --enable-sse --enable-single --prefix=/usr/local
make
make install

# New way
./build.py --preset release build
./build.py install
```

### From Old CMake

If you were using the old CMake build system:

```bash
# Old way
mkdir build && cd build
cmake ..  # Required CMake 2.8.12
make

# New way
./build.py build  # Requires CMake 3.25+
```

### Configuration Mapping

| Old Option | New Option | Notes |
|------------|------------|-------|
| `--enable-sse` | `-DENABLE_SSE=ON` | Now auto-detected |
| `--enable-neon` | `-DENABLE_NEON=ON` | Now auto-detected |
| `--disable-dynamic-code` | `-DDISABLE_DYNAMIC_CODE=ON` | Same behavior |
| `--enable-shared` | `-DENABLE_SHARED=ON` | Default: OFF |
| `--enable-static` | `-DENABLE_STATIC=ON` | Default: ON |

## 🚨 Troubleshooting

### Common Issues

#### CMake Version Too Old
```
Error: CMake version X.X.X is too old. Please install CMake 3.25 or later.
```
**Solution**: Install a newer version of CMake from [cmake.org](https://cmake.org/download/)

#### Compiler Not Found
```
Error: No suitable C compiler found
```
**Solution**: Install a C compiler (GCC, Clang, or MSVC)

#### Cross-Compilation Issues
```
Error: Cross-compilation failed
```
**Solution**: Ensure the cross-compilation toolchain is properly installed and configured

#### Permission Denied
```
Error: Could not create build directory
```
**Solution**: Check file permissions and ensure you have write access to the project directory

### Getting Help

1. **Check the configuration**: `./build.py --show-config`
2. **Run with verbose output**: `./build.py --verbose build`
3. **Check CMake output**: Look in the `build/CMakeFiles/CMakeOutput.log` file
4. **Report issues**: Create an issue on GitHub with the error details

## 📚 Advanced Usage

### Custom Build Directory

```bash
# Set custom build directory
export BUILD_DIR=/path/to/custom/build
./build.py build
```

### Parallel Builds

```bash
# Use specific number of parallel jobs
./build.py configure -DCMAKE_BUILD_PARALLEL_LEVEL=8
./build.py build
```

### Debug Builds

```bash
# Debug build with symbols
./build.py --preset debug build

# Debug with specific compiler
CC=clang ./build.py --preset debug build
```

### Integration with IDEs

#### Visual Studio Code

Create `.vscode/settings.json`:
```json
{
    "cmake.configureSettings": {
        "ENABLE_TESTS": "ON",
        "ENABLE_STATIC": "ON",
        "ENABLE_SHARED": "OFF"
    },
    "cmake.buildDirectory": "${workspaceFolder}/build"
}
```

#### CLion

The project can be opened directly in CLion, which will automatically detect the CMake configuration.

## 🤝 Contributing

### Development Setup

1. **Fork the repository**
2. **Clone your fork**: `git clone https://github.com/yourusername/ffts.git`
3. **Create a branch**: `git checkout -b feature/your-feature`
4. **Make changes** and test with `./build.py test`
5. **Commit changes**: `git commit -m "Add your feature"`
6. **Push to your fork**: `git push origin feature/your-feature`
7. **Create a pull request**

### Code Quality

The project uses several tools to maintain code quality:

- **clang-tidy** for static analysis
- **cppcheck** for additional static analysis
- **AddressSanitizer** for memory error detection
- **UndefinedBehaviorSanitizer** for undefined behavior detection

Run quality checks:
```bash
./build.py --preset debug build
cd build
cmake --build . --target clang-tidy
```

## 📄 License

FFTS is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

This modern build system was developed to meet 2024/2025 industry standards and improve the developer experience for the FFTS project. Special thanks to all contributors who have helped maintain and improve the project over the years.