/*
 * ffts_runtime_arm64.h: ARM64/AArch64 runtime CPU feature detection header
 *
 * This file is part of FFTS -- The Fastest Fourier Transform in the South
 *
 * Copyright (c) 2024, ARM64 Implementation
 * Copyright (c) 2012, Anthony M. Blake <amb@anthonix.com>
 * Copyright (c) 2012, The University of Waikato
 *
 * All rights reserved.
 *
 * Phase 7.2: Runtime Detection and Selection
 */

#ifndef FFTS_RUNTIME_ARM64_H
#define FFTS_RUNTIME_ARM64_H

#if defined(_MSC_VER) && (_MSC_VER >= 1020)
#pragma once
#endif

#include "ffts_internal.h"

/* Ensure ffts_plan_t is properly defined */
typedef struct _ffts_plan_t ffts_plan_t;

#ifdef __cplusplus
extern "C" {
#endif

/* ARM64 CPU feature flags */
#define FFTS_ARM64_NEON     (1 << 0)  /* Basic NEON support (always available) */
#define FFTS_ARM64_ASIMD    (1 << 1)  /* Advanced SIMD (128-bit vectors) */
#define FFTS_ARM64_SVE      (1 << 2)  /* Scalable Vector Extension */
#define FFTS_ARM64_SVE2     (1 << 3)  /* Scalable Vector Extension 2 */
#define FFTS_ARM64_FP16     (1 << 4)  /* Half-precision floating point */
#define FFTS_ARM64_SHA1     (1 << 5)  /* SHA1 instructions */
#define FFTS_ARM64_SHA2     (1 << 6)  /* SHA256 instructions */
#define FFTS_ARM64_CRC32    (1 << 7)  /* CRC32 instructions */

/* Runtime CPU feature detection functions */

/**
 * Detect if ARM64 NEON is available
 * @return 1 if NEON is available, 0 otherwise
 */
int ffts_have_arm64_neon(void);

/**
 * Detect if ARM64 Advanced SIMD is available
 * @return 1 if ASIMD is available, 0 otherwise
 */
int ffts_have_arm64_asimd(void);

/**
 * Detect if ARM64 SVE is available
 * @return 1 if SVE is available, 0 otherwise
 */
int ffts_have_arm64_sve(void);

/**
 * Detect if ARM64 SVE2 is available
 * @return 1 if SVE2 is available, 0 otherwise
 */
int ffts_have_arm64_sve2(void);

/**
 * Detect if ARM64 FP16 is available
 * @return 1 if FP16 is available, 0 otherwise
 */
int ffts_have_arm64_fp16(void);

/**
 * Get all detected ARM64 features as a bitmask
 * @return Bitmask of detected features (FFTS_ARM64_* flags)
 */
int ffts_get_arm64_features(void);

/**
 * Select the best ARM64 implementation for the given plan
 * @param p FFT plan to configure
 */
void ffts_select_arm64_implementation(ffts_plan_t *p);

/**
 * Get a human-readable string describing detected ARM64 CPU features
 * @return String describing CPU features (static buffer, no need to free)
 */
const char* ffts_get_arm64_cpu_info(void);

/**
 * Initialize ARM64 CPU feature detection
 * This function should be called once at program startup
 */
void ffts_arm64_init_cpu_caps(void);

/* Forward declarations for ARM64 transform functions */
#ifdef __aarch64__

/**
 * Generic 1D 32-bit float transform (fallback implementation)
 */
void ffts_execute_1d_32f(ffts_plan_t *p, const void *input, void *output);

/**
 * ARM64 NEON implementation for small transforms (N <= 8)
 */
void ffts_execute_1d_32f_arm64_neon_small(ffts_plan_t *p, const void *input, void *output);

/**
 * ARM64 NEON implementation for medium transforms (8 < N <= 64)
 */
void ffts_execute_1d_32f_arm64_neon_medium(ffts_plan_t *p, const void *input, void *output);

/**
 * ARM64 NEON implementation for large transforms (N > 64)
 */
void ffts_execute_1d_32f_arm64_neon_large(ffts_plan_t *p, const void *input, void *output);

/**
 * ARM64 SVE implementation for very large transforms (N >= 256)
 */
void ffts_execute_1d_32f_arm64_sve(ffts_plan_t *p, const void *input, void *output);

#endif /* __aarch64__ */

#ifdef __cplusplus
}
#endif

#endif /* FFTS_RUNTIME_ARM64_H */ 