# FFTS Build System Migration Guide

This guide helps you migrate from the old FFTS build system to the new modern build system that meets 2024/2025 industry standards.

## 🚀 Quick Migration

### For Users

If you just want to build FFTS, the migration is simple:

```bash
# Old way (autotools)
./configure --enable-sse --enable-single --prefix=/usr/local
make
make install

# New way (modern build system)
./build.py --preset release build
./build.py install
```

### For Developers

If you're developing FFTS or integrating it into your project:

```bash
# Old way (CMake)
mkdir build && cd build
cmake ..  # Required CMake 2.8.12
make

# New way (modern build system)
./build.py build  # Requires CMake 3.25+
```

## 📋 What's Changed

### Build System Upgrades

| Component | Old Version | New Version | Impact |
|-----------|-------------|-------------|---------|
| CMake | 2.8.12 (2012) | 3.25+ (2024) | Modern features, better performance |
| Autotools | configure.ac | Deprecated | Replaced by unified CMake system |
| Build Interface | Multiple scripts | Single `build.py` | Simplified workflow |
| CI/CD | Travis CI | GitHub Actions | Modern CI/CD with multi-platform support |

### New Features

- **Unified build interface** with `build.py`
- **Interactive configuration wizard**
- **Preset configurations** for common use cases
- **Cross-compilation support** for ARM64, RISC-V
- **Containerized builds** with Docker
- **Modern CI/CD** with GitHub Actions
- **Better error handling** and diagnostics

## 🔄 Step-by-Step Migration

### Step 1: Update Prerequisites

**Old requirements:**
- CMake 2.8.12+
- Autotools (autoconf, automake, libtool)
- Platform-specific toolchains

**New requirements:**
- CMake 3.25+
- Python 3.6+ (for build interface)
- Modern C compiler (GCC 7+, Clang 10+, or MSVC 2019+)

```bash
# Install new prerequisites
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install cmake python3 build-essential

# macOS
brew install cmake python3

# Windows
# Download CMake 3.25+ from cmake.org
# Install Python 3.6+ from python.org
```

### Step 2: Update Build Commands

#### Basic Build

**Old autotools:**
```bash
./configure --enable-sse --enable-single --prefix=/usr/local
make
make install
```

**New build system:**
```bash
./build.py --preset release build
./build.py install
```

#### Debug Build

**Old autotools:**
```bash
./configure --enable-sse --enable-single --prefix=/usr/local CFLAGS="-g -O0"
make
```

**New build system:**
```bash
./build.py --preset debug build
```

#### Cross-compilation

**Old autotools:**
```bash
./configure --host=aarch64-linux-gnu --enable-neon --prefix=/usr/local
make
```

**New build system:**
```bash
mkdir build-arm64
cd build-arm64
cmake .. \
  -DCMAKE_SYSTEM_NAME=Linux \
  -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
  -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
  -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ \
  -DENABLE_NEON=ON
cmake --build . --parallel
```

### Step 3: Update Integration

#### CMake Integration

**Old way:**
```cmake
# Find FFTS manually
find_path(FFTS_INCLUDE_DIR ffts.h)
find_library(FFTS_LIBRARY ffts)

if(FFTS_INCLUDE_DIR AND FFTS_LIBRARY)
    set(FFTS_FOUND TRUE)
    set(FFTS_LIBRARIES ${FFTS_LIBRARY})
    set(FFTS_INCLUDE_DIRS ${FFTS_INCLUDE_DIR})
endif()
```

**New way:**
```cmake
# Use modern CMake package
find_package(ffts REQUIRED)
target_link_libraries(your_target ffts::ffts)
```

#### pkg-config Integration

**Old way:**
```bash
gcc -o myapp myapp.c -lffts
```

**New way:**
```bash
gcc -o myapp myapp.c $(pkg-config --cflags --libs ffts)
```

### Step 4: Update CI/CD

#### Travis CI to GitHub Actions

**Old Travis CI (.travis.yml):**
```yaml
language: c
os:
  - linux
  - osx
script:
  - mkdir build && cd build && cmake .. && cmake --build .
```

**New GitHub Actions (.github/workflows/build.yml):**
```yaml
name: Build and Test
on: [push, pull_request]
jobs:
  linux-x64:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - run: ./build.py build
    - run: ./build.py test
```

## 🗺️ Configuration Mapping

### Autotools to CMake Options

| Autotools Option | CMake Option | Notes |
|------------------|--------------|-------|
| `--enable-sse` | `-DENABLE_SSE=ON` | Now auto-detected |
| `--enable-neon` | `-DENABLE_NEON=ON` | Now auto-detected |
| `--enable-vfp` | `-DENABLE_VFP=ON` | Now auto-detected |
| `--disable-dynamic-code` | `-DDISABLE_DYNAMIC_CODE=ON` | Same behavior |
| `--enable-shared` | `-DENABLE_SHARED=ON` | Default: OFF |
| `--enable-static` | `-DENABLE_STATIC=ON` | Default: ON |
| `--enable-single` | `-DFFTS_PREC_SINGLE=ON` | Precision control |
| `--prefix=/path` | `-DCMAKE_INSTALL_PREFIX=/path` | Installation prefix |

### Environment Variables

| Old Variable | New Variable | Notes |
|--------------|--------------|-------|
| `CC` | `CMAKE_C_COMPILER` | Compiler selection |
| `CXX` | `CMAKE_CXX_COMPILER` | C++ compiler selection |
| `CFLAGS` | `CMAKE_C_FLAGS` | C compiler flags |
| `CXXFLAGS` | `CMAKE_CXX_FLAGS` | C++ compiler flags |
| `LDFLAGS` | `CMAKE_EXE_LINKER_FLAGS` | Linker flags |

## 🐳 Docker Migration

### Old Docker Approach

**Old Dockerfile:**
```dockerfile
FROM ubuntu:20.04
RUN apt-get update && apt-get install -y build-essential autoconf automake libtool
COPY . /ffts
WORKDIR /ffts
RUN ./configure --enable-sse && make && make install
```

### New Docker Approach

**New Dockerfile:**
```dockerfile
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y build-essential cmake python3
COPY . /ffts
WORKDIR /ffts
RUN ./build.py --preset release build
```

## 🔧 Advanced Migration

### Custom Build Scripts

If you have custom build scripts, update them to use the new interface:

**Old script:**
```bash
#!/bin/bash
./configure --enable-sse --enable-single --prefix=/usr/local
make -j$(nproc)
make install
```

**New script:**
```bash
#!/bin/bash
./build.py --preset release build
./build.py install
```

### IDE Integration

#### Visual Studio Code

**Old settings:**
```json
{
    "cmake.configureSettings": {
        "CMAKE_BUILD_TYPE": "Release"
    }
}
```

**New settings:**
```json
{
    "cmake.configureSettings": {
        "CMAKE_BUILD_TYPE": "Release",
        "ENABLE_TESTS": "ON",
        "ENABLE_STATIC": "ON",
        "ENABLE_SHARED": "OFF"
    },
    "cmake.buildDirectory": "${workspaceFolder}/build"
}
```

#### CLion

The project can be opened directly in CLion without changes, as it will automatically detect the new CMake configuration.

## 🚨 Common Migration Issues

### CMake Version Too Old

**Error:**
```
CMake 3.25 or later is required
```

**Solution:**
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install cmake

# macOS
brew install cmake

# Windows
# Download from cmake.org
```

### Missing Python

**Error:**
```
python3: command not found
```

**Solution:**
```bash
# Ubuntu/Debian
sudo apt-get install python3

# macOS
brew install python3

# Windows
# Download from python.org
```

### Build Script Not Executable

**Error:**
```
Permission denied: ./build.py
```

**Solution:**
```bash
chmod +x build.py
```

### Cross-compilation Issues

**Error:**
```
Cross-compilation toolchain not found
```

**Solution:**
```bash
# Install cross-compilation toolchains
sudo apt-get install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu
```

## 📚 Migration Checklist

### For End Users

- [ ] Install CMake 3.25+
- [ ] Install Python 3.6+
- [ ] Replace `./configure && make` with `./build.py build`
- [ ] Update any custom build scripts
- [ ] Test the new build system

### For Developers

- [ ] Update CI/CD pipelines
- [ ] Update Docker configurations
- [ ] Update IDE settings
- [ ] Update documentation
- [ ] Test cross-compilation
- [ ] Verify all build configurations work

### For Integrators

- [ ] Update CMake integration code
- [ ] Update pkg-config usage
- [ ] Test with new package configuration
- [ ] Update dependency management
- [ ] Verify compatibility

## 🆘 Getting Help

### Documentation

- [README_MODERN.md](README_MODERN.md) - Complete documentation for the new build system
- [BUILD_PLAN.md](BUILD_PLAN.md) - Technical details of the modernization

### Support

1. **Check the configuration**: `./build.py --show-config`
2. **Run with verbose output**: `./build.py --verbose build`
3. **Use interactive mode**: `./build.py --interactive`
4. **Report issues**: Create an issue on GitHub

### Rollback

If you need to use the old build system temporarily:

```bash
# Autotools (if still available)
./configure --enable-sse --enable-single --prefix=/usr/local
make
make install

# Old CMake (if CMake 2.8.12+ is available)
mkdir build-old && cd build-old
cmake .. -DCMAKE_MINIMUM_REQUIRED_VERSION=2.8.12
make
```

## 🎉 Migration Benefits

After migration, you'll have access to:

- **Faster builds** with modern CMake
- **Better error messages** and diagnostics
- **Cross-platform support** with unified interface
- **Modern CI/CD** with GitHub Actions
- **Containerized builds** for reproducibility
- **Better IDE integration** with modern tooling
- **Comprehensive testing** with multiple configurations
- **Future-proof architecture** that meets 2024/2025 standards

The migration represents a significant improvement in developer experience and build system capabilities while maintaining backward compatibility where possible.