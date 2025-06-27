# CMake Toolchain File for ARM64/AArch64 Cross-compilation
# Based on ARM AArch64 documentation referenced in PLAN_x64.md
#
# Usage:
#   cmake -DCMAKE_TOOLCHAIN_FILE=cmake/arm64-toolchain.cmake ..
#
# Environment variables:
#   ARM64_TOOLCHAIN_PREFIX: Toolchain prefix (default: aarch64-linux-gnu)
#   ARM64_SYSROOT: Path to ARM64 sysroot (optional)

# Target system information
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# Toolchain configuration
set(TOOLCHAIN_PREFIX $ENV{ARM64_TOOLCHAIN_PREFIX})
if(NOT TOOLCHAIN_PREFIX)
    set(TOOLCHAIN_PREFIX "aarch64-linux-gnu")
endif()

# Cross compiler configuration
set(CMAKE_C_COMPILER ${TOOLCHAIN_PREFIX}-gcc)
set(CMAKE_CXX_COMPILER ${TOOLCHAIN_PREFIX}-g++)
set(CMAKE_ASM_COMPILER ${TOOLCHAIN_PREFIX}-gcc)

# Utility tools
set(CMAKE_AR ${TOOLCHAIN_PREFIX}-ar)
set(CMAKE_STRIP ${TOOLCHAIN_PREFIX}-strip)
set(CMAKE_NM ${TOOLCHAIN_PREFIX}-nm)
set(CMAKE_OBJCOPY ${TOOLCHAIN_PREFIX}-objcopy)
set(CMAKE_OBJDUMP ${TOOLCHAIN_PREFIX}-objdump)
set(CMAKE_RANLIB ${TOOLCHAIN_PREFIX}-ranlib)

# Sysroot configuration (if available)
if(DEFINED ENV{ARM64_SYSROOT})
    set(CMAKE_SYSROOT $ENV{ARM64_SYSROOT})
    set(CMAKE_FIND_ROOT_PATH $ENV{ARM64_SYSROOT})
endif()

# Search paths configuration for cross-compilation
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# ARM64 specific compiler flags
# Based on ARM Architecture Reference Manual for A-profile architecture
set(CMAKE_C_FLAGS_INIT "-march=armv8-a")
set(CMAKE_CXX_FLAGS_INIT "-march=armv8-a")
set(CMAKE_ASM_FLAGS_INIT "-march=armv8-a")

# Enable ARM64 optimizations
set(ENABLE_ARM64 ON CACHE BOOL "Enable ARM64 optimizations")
set(ENABLE_NEON ON CACHE BOOL "Enable NEON (automatically available on ARM64)")

# Performance optimization flags for ARM64
set(CMAKE_C_FLAGS_RELEASE "-O3 -DNDEBUG -mcpu=generic")
set(CMAKE_CXX_FLAGS_RELEASE "-O3 -DNDEBUG -mcpu=generic")

# Debug flags
set(CMAKE_C_FLAGS_DEBUG "-O0 -g")
set(CMAKE_CXX_FLAGS_DEBUG "-O0 -g")

# Link flags for ARM64
set(CMAKE_EXE_LINKER_FLAGS_INIT "")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "")

# Cache variables to help CMake tests
set(CMAKE_CROSSCOMPILING TRUE CACHE BOOL "Cross compiling")
set(CMAKE_SYSTEM_PROCESSOR "aarch64" CACHE STRING "Target processor")

# Print configuration
message(STATUS "ARM64 Toolchain Configuration:")
message(STATUS "  Toolchain prefix: ${TOOLCHAIN_PREFIX}")
message(STATUS "  C Compiler: ${CMAKE_C_COMPILER}")
message(STATUS "  CXX Compiler: ${CMAKE_CXX_COMPILER}")
if(CMAKE_SYSROOT)
    message(STATUS "  Sysroot: ${CMAKE_SYSROOT}")
endif()
message(STATUS "  Target: ${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR}")

# Verification function to check toolchain
function(verify_arm64_toolchain)
    execute_process(
        COMMAND ${CMAKE_C_COMPILER} --version
        OUTPUT_VARIABLE COMPILER_VERSION
        ERROR_QUIET
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    if(COMPILER_VERSION)
        message(STATUS "ARM64 compiler verification successful")
    else()
        message(FATAL_ERROR "ARM64 toolchain verification failed. Please check your toolchain installation.")
    endif()
endfunction()

# Run verification
verify_arm64_toolchain() 