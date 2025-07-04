#!/bin/bash
# FFTS ARM32/AArch32 Cross-compilation Script
# Supports common ARM32 cross-compilation toolchains
#
# Usage:
#   ./build_arm32.sh [toolchain] [install_dir]
#
# Supported toolchains:
#   - arm-linux-gnueabihf (default)
#   - arm-linux-androideabi
#   - arm-apple-darwin (for macOS/iOS)
#   - arm-none-eabi (bare metal)

set -e

# Configuration
TOOLCHAIN=${1:-arm-linux-gnueabihf}
INSTALL_DIR=${2:-$(pwd)/build/arm32}
BUILD_TYPE=${BUILD_TYPE:-Release}
FLOAT_ABI_FLAG="" # Will be set for specific toolchains

# Toolchain detection
case $TOOLCHAIN in
    arm-linux-gnueabihf)
        export CC="${TOOLCHAIN}-gcc"
        export CXX="${TOOLCHAIN}-g++"
        export AR="${TOOLCHAIN}-ar"
        export STRIP="${TOOLCHAIN}-strip"
        export RANLIB="${TOOLCHAIN}-ranlib"
        # Add -DDYNAMIC_DISABLED to build static version
        export CFLAGS="-DHAVE_NEON -g -O0" # Forcing NEON support
        CONFIGURE_HOST="arm-linux-gnueabihf"
        ARCH_FLAGS="--enable-neon" # --enable-arm is not a valid flag
        FLOAT_ABI_FLAG="--with-float-abi=hard"
        echo "Building for GNU/Linux ARM32 with ${TOOLCHAIN}"
        ;;
    arm-linux-androideabi)
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
        # Add -DDYNAMIC_DISABLED to build static version
        export CFLAGS="-DHAVE_NEON" # Forcing NEON support
        CONFIGURE_HOST="arm-linux-androideabi"
        ARCH_FLAGS="--enable-neon"
        # Android toolchains typically handle float ABI automatically
        echo "Building for Android ARM32 with NDK"
        ;;
    arm-apple-darwin)
        export CC="clang"
        export CXX="clang++"
        export CFLAGS="-arch armv7 -mmacosx-version-min=11.0 -DHAVE_NEON"
        export CXXFLAGS="-arch armv7 -mmacosx-version-min=11.0"
        CONFIGURE_HOST="arm-apple-darwin"
        ARCH_FLAGS="--enable-neon"
        echo "Building for macOS ARM32"
        ;;
    arm-none-eabi)
        export CC="${TOOLCHAIN}-gcc"
        export CXX="${TOOLCHAIN}-g++"
        export AR="${TOOLCHAIN}-ar"
        export STRIP="${TOOLCHAIN}-strip"
        export RANLIB="${TOOLCHAIN}-ranlib"
        SYSROOT=$(${CC} --print-sysroot)
        # Add -DDYNAMIC_DISABLED to build static version
        export CFLAGS="-mcpu=cortex-a8 -DHAVE_NEON -DHAVE_STRING_H -DHAVE_SYS_MMAN_H --specs=nosys.specs"
        CONFIGURE_HOST="arm-none-eabi"
        ARCH_FLAGS="--enable-neon"
        # ARCH_FLAGS="--enable-neon --disable-dynamic-code"
        # Bare metal may need explicit float ABI, depends on sysroot
        # Add --with-float-abi=softfp or --with-float-abi=hard as needed
        echo "Building for bare metal ARM32"
        ;;
    *)
        echo "Error: Unsupported toolchain: $TOOLCHAIN"
        echo "Supported: arm-linux-gnueabihf, arm-linux-androideabi, arm-apple-darwin, arm-none-eabi"
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

echo "Configuring FFTS for ARM32..."
echo "  Toolchain: $TOOLCHAIN"
echo "  Install directory: $INSTALL_DIR"
echo "  Architecture flags: $ARCH_FLAGS"
if [ -n "$FLOAT_ABI_FLAG" ]; then
    echo "  Float ABI flag: $FLOAT_ABI_FLAG"
fi

# Configure with ARM32 support (dynamic)
./configure \
    $ARCH_FLAGS \
    $FLOAT_ABI_FLAG \
    --host=$CONFIGURE_HOST \
    --prefix="$INSTALL_DIR" \
    --enable-neon \
    --disable-shared \
    "CC=$CC" \
    "CXX=$CXX"

# Configure with ARM32 support (static)
# ./configure \
#     $ARCH_FLAGS \
#     $FLOAT_ABI_FLAG \
#     --host=$CONFIGURE_HOST \
#     --prefix="$INSTALL_DIR" \
#     --enable-neon \
#     --disable-shared \
#     --enable-static \
#     --disable-dynamic-code

echo "Building FFTS..."
make clean
make -j$(nproc 2>/dev/null || echo 4)

echo "Installing FFTS..."
make install

echo "ARM32 build completed successfully! "
echo "Install directory: $INSTALL_DIR"
echo "Libraries: $INSTALL_DIR/lib/"
echo "Headers: $INSTALL_DIR/include/"

# Optional: Create a simple test if we can run ARM32 binaries
if command -v qemu-arm &> /dev/null && [ "$TOOLCHAIN" = "arm-linux-gnueabihf" ]; then
    echo "Testing with QEMU..."
    # Look for test executable in tests directory (autotools build)
    if [ -f "tests/test" ]; then
        qemu-arm -L /usr/arm-linux-gnueabihf tests/test || true
    elif [ -f "build/ffts_test" ]; then
        qemu-arm -L /usr/arm-linux-gnueabihf build/ffts_test || true
    else
        echo "No test executable found to run with QEMU"
    fi
fi