cmake_minimum_required(VERSION 3.25 FATAL_ERROR)

# Set project name and version
project(ffts 
    VERSION 0.9.0
    DESCRIPTION "Fastest Fourier Transform in the South"
    HOMEPAGE_URL "https://github.com/linkotec/ffts"
    LANGUAGES C ASM
)

# Set C standard
set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Enable testing
enable_testing()

# Set default build type
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Release" CACHE STRING "Build type" FORCE)
endif()

# Set build type options
set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS 
    "Debug" "Release" "RelWithDebInfo" "MinSizeRel")

# Set output directories
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

# Enable folders for IDE organization
set_property(GLOBAL PROPERTY USE_FOLDERS ON)

# Include directories
include(GNUInstallDirs)
include(CheckCSourceCompiles)
include(CheckCSourceRuns)
include(CheckFunctionExists)
include(CheckIncludeFile)
include(CheckSymbolExists)
include(CheckCCompilerFlag)

# Set installation paths
set(INCLUDE_INSTALL_DIR ${CMAKE_INSTALL_INCLUDEDIR}/ffts)
set(LIB_INSTALL_DIR ${CMAKE_INSTALL_LIBDIR})

# Build options
option(ENABLE_NEON "Enable NEON instructions for ARM" OFF)
option(ENABLE_VFP "Enable VFP instructions for ARM" OFF)
option(DISABLE_DYNAMIC_CODE "Disable dynamic machine code generation" OFF)
option(GENERATE_POSITION_INDEPENDENT_CODE "Generate position independent code" OFF)
option(ENABLE_SHARED "Build shared library" OFF)
option(ENABLE_STATIC "Build static library" ON)
option(ENABLE_TESTS "Build tests" ON)
option(ENABLE_EXAMPLES "Build examples" OFF)
option(ENABLE_BENCHMARKS "Build benchmarks" OFF)
option(ENABLE_DOCUMENTATION "Build documentation" OFF)
option(ENABLE_COVERAGE "Enable code coverage" OFF)
option(ENABLE_SANITIZERS "Enable sanitizers" OFF)

# Architecture-specific options
option(ENABLE_SSE "Enable SSE instructions" ON)
option(ENABLE_SSE2 "Enable SSE2 instructions" ON)
option(ENABLE_SSE3 "Enable SSE3 instructions" ON)
option(ENABLE_AVX "Enable AVX instructions" OFF)
option(ENABLE_AVX2 "Enable AVX2 instructions" OFF)

# Define FFTS_BUILD when building the library
add_compile_definitions(FFTS_BUILD)

# Check for required headers
check_include_file(malloc.h HAVE_MALLOC_H)
check_include_file(mm_malloc.h HAVE_MM_MALLOC_H)
check_include_file(stdint.h HAVE_STDINT_H)
check_include_file(stdlib.h HAVE_STDLIB_H)
check_include_file(string.h HAVE_STRING_H)
check_include_file(sys/mman.h HAVE_SYS_MMAN_H)
check_include_file(unistd.h HAVE_UNISTD_H)

# Add definitions for found headers
foreach(header MALLOC MM_MALLOC STDINT STDLIB STRING SYS_MMAN UNISTD)
    if(HAVE_${header}_H)
        add_compile_definitions(HAVE_${header}_H)
    endif()
endforeach()

# Check for memory allocation functions
check_symbol_exists(aligned_alloc stdlib.h HAVE_DECL_ALIGNED_ALLOC)
check_symbol_exists(memalign malloc.h HAVE_DECL_MEMALIGN)
check_symbol_exists(posix_memalign stdlib.h HAVE_DECL_POSIX_MEMALIGN)
check_symbol_exists(valloc stdlib.h HAVE_DECL_VALLOC)
check_symbol_exists(_mm_malloc malloc.h HAVE_DECL__MM_MALLOC)

# Add definitions for found functions
foreach(func aligned_alloc memalign posix_memalign valloc _mm_malloc)
    string(TOUPPER "${func}" func_upper)
    # Handle special case for _mm_malloc which has two underscores in the variable name
    if(func STREQUAL "_mm_malloc")
        set(func_upper "__MM_MALLOC")
    endif()
    if(HAVE_DECL_${func_upper})
        add_compile_definitions(HAVE_DECL_${func_upper})
    endif()
endforeach()

# Check for function availability
check_function_exists(aligned_alloc HAVE_ALIGNED_ALLOC)
check_function_exists(memalign HAVE_MEMALIGN)
check_function_exists(posix_memalign HAVE_POSIX_MEMALIGN)
check_function_exists(valloc HAVE_VALLOC)
check_function_exists(_mm_malloc HAVE__MM_MALLOC)

# Add definitions for available functions
foreach(func aligned_alloc memalign posix_memalign valloc _mm_malloc)
    string(TOUPPER "${func}" func_upper)
    if(HAVE_${func_upper})
        add_compile_definitions(HAVE_${func_upper})
    endif()
endforeach()

# Architecture detection and optimization
if(CMAKE_CROSSCOMPILING)
    # Cross-compilation mode - rely on user configuration
    message(STATUS "Cross-compiling - using user-provided configuration")
else()
    # Native compilation - auto-detect architecture
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "^arm")
        # ARM architecture detection
        set(CMAKE_REQUIRED_QUIET 1)
        
        # Test for ARM architecture support
        set(TEST_SOURCE_CODE "int main() { return 0; }")
        
        # Try native optimization first
        set(CMAKE_REQUIRED_FLAGS "-march=native")
        check_c_source_runs("${TEST_SOURCE_CODE}" GCC_MARCH_NATIVE_FLAG_SUPPORTED)
        
        if(GCC_MARCH_NATIVE_FLAG_SUPPORTED)
            message(STATUS "FFTS using 'march=native' for ARM")
            set(CMAKE_ASM_FLAGS "${CMAKE_ASM_FLAGS} -march=native")
            set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -march=native")
        else()
            # Fallback to ARMv7
            set(CMAKE_REQUIRED_FLAGS "-march=armv7-a")
            check_c_source_runs("${TEST_SOURCE_CODE}" GCC_MARCH_ARMV7A_FLAG_SUPPORTED)
            
            if(GCC_MARCH_ARMV7A_FLAG_SUPPORTED)
                message(STATUS "FFTS using 'march=armv7-a' for ARM")
                set(CMAKE_ASM_FLAGS "${CMAKE_ASM_FLAGS} -march=armv7-a")
                set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -march=armv7-a")
            else()
                # Fallback to ARMv6
                set(CMAKE_REQUIRED_FLAGS "-march=armv6")
                check_c_source_runs("${TEST_SOURCE_CODE}" GCC_MARCH_ARMV6_FLAG_SUPPORTED)
                
                if(GCC_MARCH_ARMV6_FLAG_SUPPORTED)
                    message(STATUS "FFTS using 'march=armv6' for ARM")
                    set(CMAKE_ASM_FLAGS "${CMAKE_ASM_FLAGS} -march=armv6")
                    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -march=armv6")
                else()
                    message(WARNING "FFTS failed to determine ARM architecture")
                endif()
            endif()
        endif()
        
        # NEON detection for ARM
        set(TEST_SOURCE_CODE "
            #include <arm_neon.h>
            int main() {
                float32x4_t v;
                float zeros[4] = {0.0f, 0.0f, 0.0f, 0.0f};
                v = vld1q_f32(zeros);
                return 0;
            }"
        )
        
        # Test NEON with hard float ABI
        set(CMAKE_REQUIRED_FLAGS "-mfpu=neon -mfloat-abi=hard")
        check_c_source_runs("${TEST_SOURCE_CODE}" NEON_HARDFP_SUPPORTED)
        
        if(NEON_HARDFP_SUPPORTED)
            message(STATUS "FFTS using 'neon' FPU and 'hard' float ABI")
            set(CMAKE_ASM_FLAGS "${CMAKE_ASM_FLAGS} -mfpu=neon -mfloat-abi=hard")
            set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -mfpu=neon -mfloat-abi=hard")
            set(ENABLE_NEON ON)
        else()
            # Test NEON with soft float ABI
            set(CMAKE_REQUIRED_FLAGS "-mfpu=neon -mfloat-abi=softfp")
            check_c_source_runs("${TEST_SOURCE_CODE}" NEON_SOFTFP_SUPPORTED)
            
            if(NEON_SOFTFP_SUPPORTED)
                message(STATUS "FFTS using 'neon' FPU and 'softfp' float ABI")
                set(CMAKE_ASM_FLAGS "${CMAKE_ASM_FLAGS} -mfpu=neon -mfloat-abi=softfp")
                set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -mfpu=neon -mfloat-abi=softfp")
                set(ENABLE_NEON ON)
            else()
                if(ENABLE_NEON)
                    message(FATAL_ERROR "FFTS cannot enable NEON on this platform")
                endif()
                
                # Fallback to VFP
                set(TEST_SOURCE_CODE "
                    double sum(double a, double b) { return a + b; }
                    int main() {
                        double s1, s2, v1 = 1.0, v2 = 2.0, v3 = 1.0e-322;
                        s1 = sum(v1, v2);
                        s2 = sum(v3, v3);
                        return 0;
                    }"
                )
                
                set(CMAKE_REQUIRED_FLAGS "-mfpu=vfp")
                check_c_source_runs("${TEST_SOURCE_CODE}" VFP_SUPPORTED)
                
                if(VFP_SUPPORTED)
                    message(STATUS "FFTS using 'vfp' FPU")
                    set(CMAKE_ASM_FLAGS "${CMAKE_ASM_FLAGS} -mfpu=vfp")
                    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -mfpu=vfp")
                    set(ENABLE_VFP ON)
                else()
                    if(ENABLE_VFP)
                        message(FATAL_ERROR "FFTS cannot enable VFP on this platform")
                    endif()
                    message(WARNING "FFTS using 'soft' FPU")
                endif()
            endif()
        endif()
    else()
        # x86/x64 architecture
        if(CMAKE_COMPILER_IS_GNUCC)
            set(CMAKE_REQUIRED_FLAGS "-msse")
        endif()
        
        # Check SSE support
        check_include_file(xmmintrin.h HAVE_XMMINTRIN_H)
        if(HAVE_XMMINTRIN_H)
            add_compile_definitions(HAVE_SSE)
            set(CMAKE_REQUIRED_FLAGS_SAVE ${CMAKE_REQUIRED_FLAGS})
        endif()
        
        # Check SSE2 support
        if(CMAKE_COMPILER_IS_GNUCC)
            set(CMAKE_REQUIRED_FLAGS "${CMAKE_REQUIRED_FLAGS_SAVE} -msse2")
        endif()
        
        check_include_file(emmintrin.h HAVE_EMMINTRIN_H)
        if(HAVE_EMMINTRIN_H)
            add_compile_definitions(HAVE_SSE2)
            set(CMAKE_REQUIRED_FLAGS_SAVE ${CMAKE_REQUIRED_FLAGS})
        endif()
        
        # Check SSE3 support
        if(CMAKE_COMPILER_IS_GNUCC)
            set(CMAKE_REQUIRED_FLAGS "${CMAKE_REQUIRED_FLAGS_SAVE} -msse3")
        endif()
        
        check_include_file(pmmintrin.h HAVE_PMMINTRIN_H)
        if(HAVE_PMMINTRIN_H)
            add_compile_definitions(HAVE_PMMINTRIN_H HAVE_SSE3)
            set(CMAKE_REQUIRED_FLAGS_SAVE ${CMAKE_REQUIRED_FLAGS})
        else()
            # Check for specific intrinsics
            check_include_file(intrin.h HAVE_INTRIN_H)
            if(HAVE_INTRIN_H)
                add_compile_definitions(HAVE_INTRIN_H)
                
                check_c_source_compiles("
                    #include<intrin.h>
                    int main(int argc, char** argv) {
                        (void) argv;
                        (void) argc;
                        return _mm_movemask_ps(_mm_moveldup_ps(_mm_set_ss(1.0f)));
                    }" HAVE__MM_MOVELDUP_PS
                )
                
                if(HAVE__MM_MOVELDUP_PS)
                    add_compile_definitions(HAVE_SSE3)
                endif()
            endif()
        endif()
    endif()
endif()

# Compiler-specific settings
if(MSVC)
    # MSVC settings
    add_compile_options(/W4 /wd4127)
    set(CMAKE_DEBUG_POSTFIX "d")
    add_compile_definitions(_USE_MATH_DEFINES)
elseif(CMAKE_COMPILER_IS_GNUCC)
    # GCC settings
    add_compile_options(-Wall -Wextra)
    
    # Check for visibility support
    check_c_compiler_flag(-fvisibility=hidden HAVE_GCC_VISIBILITY)
    if(HAVE_GCC_VISIBILITY)
        add_compile_options(-fvisibility=hidden)
        add_compile_definitions(HAVE_GCC_VISIBILITY)
    endif()
    
    # Check for math library
    check_library_exists(m pow "" HAVE_LIBM)
    if(HAVE_LIBM)
        set(FFTS_EXTRA_LIBRARIES m)
    endif()
    
    # Add SSE definitions
    if(HAVE_PMMINTRIN_H)
        add_compile_definitions(-msse3)
    elseif(HAVE_EMMINTRIN_H)
        add_compile_definitions(-msse2)
    elseif(HAVE_XMMINTRIN_H)
        add_compile_definitions(-msse)
    endif()
endif()

# Position independent code
if(GENERATE_POSITION_INDEPENDENT_CODE)
    set(CMAKE_POSITION_INDEPENDENT_CODE ON)
endif()

# Create FFTS library target
set(FFTS_HEADERS
    include/ffts.h
)

set(FFTS_SOURCES
    src/ffts_attributes.h
    src/ffts.c
    src/ffts_chirp_z.c
    src/ffts_chirp_z.h
    src/ffts_internal.h
    src/ffts_nd.c
    src/ffts_nd.h
    src/ffts_real.h
    src/ffts_real.c
    src/ffts_real_nd.c
    src/ffts_real_nd.h
    src/ffts_transpose.c
    src/ffts_transpose.h
    src/ffts_trig.c
    src/ffts_trig.h
    src/ffts_static.c
    src/ffts_static.h
    src/macros.h
    src/patterns.h
    src/types.h
)

# Add architecture-specific sources
if(ENABLE_NEON)
    list(APPEND FFTS_SOURCES
        src/neon.s
    )
    
    if(DISABLE_DYNAMIC_CODE)
        list(APPEND FFTS_SOURCES
            src/neon_static.s
        )
    endif()
    
    add_compile_definitions(HAVE_NEON)
elseif(ENABLE_VFP)
    if(NOT DISABLE_DYNAMIC_CODE)
        list(APPEND FFTS_SOURCES
            src/vfp.s
        )
    endif()
    
    add_compile_definitions(HAVE_VFP)
elseif(HAVE_XMMINTRIN_H)
    add_compile_definitions(HAVE_SSE)
    
    list(APPEND FFTS_SOURCES
        src/macros-sse.h
    )
    
    if(NOT DISABLE_DYNAMIC_CODE)
        if(CMAKE_SIZEOF_VOID_P EQUAL 8)
            list(APPEND FFTS_SOURCES
                src/codegen_sse.h
            )
        else()
            message(WARNING "Dynamic code is only supported with x64, disabling dynamic code.")
            set(DISABLE_DYNAMIC_CODE ON)
        endif()
    endif()
endif()

# Add dynamic code generation
if(DISABLE_DYNAMIC_CODE)
    add_compile_definitions(DYNAMIC_DISABLED)
else()
    list(APPEND FFTS_SOURCES
        src/codegen.c
        src/codegen.h
    )
endif()

# Create library targets
if(ENABLE_SHARED)
    add_library(ffts_shared SHARED
        ${FFTS_HEADERS}
        ${FFTS_SOURCES}
    )
    
    set_target_properties(ffts_shared PROPERTIES
        DEFINE_SYMBOL FFTS_SHARED
        OUTPUT_NAME ffts
        VERSION ${PROJECT_VERSION}
        SOVERSION ${PROJECT_VERSION_MAJOR}
        C_VISIBILITY_PRESET hidden
    )
    
    target_include_directories(ffts_shared
        PUBLIC
            $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
            $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
        PRIVATE
            ${CMAKE_CURRENT_SOURCE_DIR}/src
            ${CMAKE_CURRENT_BINARY_DIR}
    )
    
    if(FFTS_EXTRA_LIBRARIES)
        target_link_libraries(ffts_shared PRIVATE ${FFTS_EXTRA_LIBRARIES})
    endif()
    
    install(TARGETS ffts_shared
        EXPORT fftsTargets
        LIBRARY DESTINATION ${LIB_INSTALL_DIR}
        ARCHIVE DESTINATION ${LIB_INSTALL_DIR}
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    )
endif()

if(ENABLE_STATIC)
    add_library(ffts_static STATIC
        ${FFTS_HEADERS}
        ${FFTS_SOURCES}
    )
    
    set_target_properties(ffts_static PROPERTIES
        OUTPUT_NAME ffts
        C_VISIBILITY_PRESET hidden
    )
    
    target_include_directories(ffts_static
        PUBLIC
            $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
            $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
        PRIVATE
            ${CMAKE_CURRENT_SOURCE_DIR}/src
            ${CMAKE_CURRENT_BINARY_DIR}
    )
    
    if(FFTS_EXTRA_LIBRARIES)
        target_link_libraries(ffts_static PRIVATE ${FFTS_EXTRA_LIBRARIES})
    endif()
    
    install(TARGETS ffts_static
        EXPORT fftsTargets
        ARCHIVE DESTINATION ${LIB_INSTALL_DIR}
    )
endif()

# Create alias target
if(ENABLE_STATIC AND ENABLE_SHARED)
    add_library(ffts ALIAS ffts_static)
elseif(ENABLE_STATIC)
    add_library(ffts ALIAS ffts_static)
elseif(ENABLE_SHARED)
    add_library(ffts ALIAS ffts_shared)
endif()

# Build tests
if(ENABLE_TESTS AND (ENABLE_STATIC OR ENABLE_SHARED))
    add_executable(ffts_test tests/test.c)
    
    target_link_libraries(ffts_test ffts)
    
    add_test(NAME ffts_test COMMAND ffts_test)
endif()

# Install headers
install(FILES ${FFTS_HEADERS}
    DESTINATION ${INCLUDE_INSTALL_DIR}
)

# Generate and install pkg-config file
if(UNIX)
    include(FindPkgConfig QUIET)
    if(PKG_CONFIG_FOUND)
        # Convert link libraries to pkg-config format
        set(PRIVATE_LIBS "")
        foreach(LIB ${CMAKE_CXX_IMPLICIT_LINK_LIBRARIES} ${PLATFORM_LIBS})
            set(PRIVATE_LIBS "${PRIVATE_LIBS} -l${LIB}")
        endforeach()
        
        # Configure pkg-config file
        configure_file("ffts.pc.cmake.in" "ffts.pc" @ONLY)
        install(FILES "${CMAKE_CURRENT_BINARY_DIR}/ffts.pc"
                DESTINATION "${CMAKE_INSTALL_LIBDIR}/pkgconfig")
    endif()
endif()

# Install CMake config files
install(EXPORT fftsTargets
    FILE fftsTargets.cmake
    NAMESPACE ffts::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/ffts
)

# Create config file
include(CMakePackageConfigHelpers)
write_basic_package_version_file(
    fftsConfigVersion.cmake
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)

configure_package_config_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/fftsConfig.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/fftsConfig.cmake"
    INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/ffts
)

install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/fftsConfig.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/fftsConfigVersion.cmake"
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/ffts
)

# Print configuration summary
message(STATUS "")
message(STATUS "FFTS Configuration Summary:")
message(STATUS "  Version: ${PROJECT_VERSION}")
message(STATUS "  Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "  Shared library: ${ENABLE_SHARED}")
message(STATUS "  Static library: ${ENABLE_STATIC}")
message(STATUS "  Tests: ${ENABLE_TESTS}")
message(STATUS "  NEON support: ${ENABLE_NEON}")
message(STATUS "  VFP support: ${ENABLE_VFP}")
message(STATUS "  SSE support: ${HAVE_XMMINTRIN_H}")
message(STATUS "  SSE2 support: ${HAVE_EMMINTRIN_H}")
message(STATUS "  SSE3 support: ${HAVE_PMMINTRIN_H}")
message(STATUS "  Dynamic code: ${NOT DISABLE_DYNAMIC_CODE}")
message(STATUS "  Install prefix: ${CMAKE_INSTALL_PREFIX}")
message(STATUS "")
