#!/bin/bash
# FFTS ARM64/AArch64 Cross-compilation Script
# Supports common ARM64 cross-compilation toolchains
# 
# Usage:
#   ./build_arm64.sh [toolchain] [install_dir]
#
# Supported toolchains:
#   - aarch64-linux-gnu (default)
#   - aarch64-linux-android
#   - arm64-apple-darwin (for macOS/iOS)
#   - aarch64-none-elf (bare metal)

set -e

# Configuration
TOOLCHAIN=${1:-aarch64-linux-gnu}
INSTALL_DIR=${2:-$(pwd)/build/arm64}
BUILD_TYPE=${BUILD_TYPE:-Release}

# Toolchain detection
case $TOOLCHAIN in
    aarch64-linux-gnu)
        export CC="${TOOLCHAIN}-gcc"
        export CXX="${TOOLCHAIN}-g++"
        export AR="${TOOLCHAIN}-ar"
        export STRIP="${TOOLCHAIN}-strip"
        export RANLIB="${TOOLCHAIN}-ranlib"
        CONFIGURE_HOST="aarch64-linux-gnu"
        ARCH_FLAGS="--enable-arm64 --enable-neon"
        echo "Building for GNU/Linux AArch64 with ${TOOLCHAIN}"
        ;;
    aarch64-linux-android)
        if [ -z "$NDK_ROOT" ]; then
            echo "Error: NDK_ROOT must be set for Android builds"
            exit 1
        fi
        # Use modern NDK standalone toolchain
        export CC="${TOOLCHAIN}-clang"
        export CXX="${TOOLCHAIN}-clang++"
        export AR="${TOOLCHAIN}-ar"
        export STRIP="${TOOLCHAIN}-strip"
        export RANLIB="${TOOLCHAIN}-ranlib"
        CONFIGURE_HOST="aarch64-linux-android"
        ARCH_FLAGS="--enable-arm64 --enable-neon"
        echo "Building for Android ARM64 with NDK"
        ;;
    arm64-apple-darwin)
        export CC="clang"
        export CXX="clang++"
        export CFLAGS="-arch arm64 -mmacosx-version-min=11.0"
        export CXXFLAGS="-arch arm64 -mmacosx-version-min=11.0"
        CONFIGURE_HOST="arm64-apple-darwin"
        ARCH_FLAGS="--enable-arm64 --enable-neon"
        echo "Building for macOS ARM64 (Apple Silicon)"
        ;;
    aarch64-none-elf)
        export CC="${TOOLCHAIN}-gcc"
        export CXX="${TOOLCHAIN}-g++"
        export AR="${TOOLCHAIN}-ar"
        export STRIP="${TOOLCHAIN}-strip"
        export RANLIB="${TOOLCHAIN}-ranlib"
        CONFIGURE_HOST="aarch64-none-elf"
        ARCH_FLAGS="--enable-arm64 --enable-neon --disable-dynamic-code"
        echo "Building for bare metal AArch64"
        ;;
    *)
        echo "Error: Unsupported toolchain: $TOOLCHAIN"
        echo "Supported: aarch64-linux-gnu, aarch64-linux-android, arm64-apple-darwin, aarch64-none-elf"
        exit 1
        ;;
esac

# Verify toolchain availability
if ! command -v $CC &> /dev/null; then
    echo "Error: Compiler $CC not found. Please install the appropriate toolchain."
    exit 1
fi

# Create build directory
mkdir -p "$INSTALL_DIR"

echo "Configuring FFTS for ARM64..."
echo "  Toolchain: $TOOLCHAIN"
echo "  Install directory: $INSTALL_DIR"
echo "  Architecture flags: $ARCH_FLAGS"

# Configure with ARM64 support
./configure \
    $ARCH_FLAGS \
    --host=$CONFIGURE_HOST \
    --prefix="$INSTALL_DIR" \
    --enable-neon \
    --disable-shared \
# ./configure \
#     $ARCH_FLAGS \
#     --host=$CONFIGURE_HOST \
#     --prefix="$INSTALL_DIR" \
#     --enable-static \
#     --disable-shared \
#     --disable-dynamic-code

echo "Building FFTS..."
make clean
make -j$(nproc 2>/dev/null || echo 4)

echo "Installing FFTS..."
make install

echo "ARM64 build completed successfully!"
echo "Install directory: $INSTALL_DIR"
echo "Libraries: $INSTALL_DIR/lib/"
echo "Headers: $INSTALL_DIR/include/"

# Optional: Create a simple test if we can run ARM64 binaries
if command -v qemu-aarch64 &> /dev/null && [ "$TOOLCHAIN" = "aarch64-linux-gnu" ]; then
    echo "Testing with QEMU..."
    # Look for test executable in tests directory (autotools build)
    if [ -f "tests/test" ]; then
        qemu-aarch64 -L /usr/aarch64-linux-gnu tests/test || true
    elif [ -f "build/ffts_test" ]; then
        qemu-aarch64 -L /usr/aarch64-linux-gnu build/ffts_test || true
    else
        echo "No test executable found to run with QEMU"
    fi
fi 