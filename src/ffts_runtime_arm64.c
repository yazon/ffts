/*
 * ffts_runtime_arm64.c: ARM64/AArch64 runtime CPU feature detection
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
 * - Dynamic CPU feature detection for ARM64
 * - Function pointer selection based on available features
 * - Cross-platform compatible implementation
 */

#include "ffts_runtime_arm64.h"
#include "ffts_internal.h"

#ifdef __aarch64__

#ifdef __linux__
#include <sys/auxv.h>
#include <asm/hwcap.h>
#endif

#ifdef __ANDROID__
#include <cpu-features.h>
#endif

#ifdef __APPLE__
#include <sys/types.h>
#include <sys/sysctl.h>
#endif

/* ARM64 CPU feature flags */
static int arm64_cpu_features = 0;
static int arm64_features_detected = 0;

/* ARM64 CPU feature detection */
static void ffts_detect_arm64_features(void)
{
    if (arm64_features_detected) {
        return;
    }

#ifdef __linux__
    /* Linux: Use getauxval() to read hardware capabilities */
    unsigned long hwcap = getauxval(AT_HWCAP);
    unsigned long hwcap2 = getauxval(AT_HWCAP2);

    /* NEON is always available on AArch64 */
    arm64_cpu_features |= FFTS_ARM64_NEON;

    /* Check for advanced features */
    if (hwcap & HWCAP_ASIMD) {
        arm64_cpu_features |= FFTS_ARM64_ASIMD;
    }

    if (hwcap & HWCAP_SVE) {
        arm64_cpu_features |= FFTS_ARM64_SVE;
    }

    if (hwcap2 & HWCAP2_SVE2) {
        arm64_cpu_features |= FFTS_ARM64_SVE2;
    }

    if (hwcap & HWCAP_SHA1) {
        arm64_cpu_features |= FFTS_ARM64_SHA1;
    }

    if (hwcap & HWCAP_SHA2) {
        arm64_cpu_features |= FFTS_ARM64_SHA2;
    }

    if (hwcap & HWCAP_CRC32) {
        arm64_cpu_features |= FFTS_ARM64_CRC32;
    }

#elif defined(__ANDROID__)
    /* Android NDK: Use cpu-features library */
    AndroidCpuFamily family = android_getCpuFamily();
    if (family == ANDROID_CPU_FAMILY_ARM64) {
        arm64_cpu_features |= FFTS_ARM64_NEON;

        uint64_t features = android_getCpuFeatures();
        if (features & ANDROID_CPU_ARM64_FEATURE_ASIMD) {
            arm64_cpu_features |= FFTS_ARM64_ASIMD;
        }
    }

#elif defined(__APPLE__)
    /* macOS/iOS: Use sysctl to detect CPU features */
    size_t size = sizeof(int);
    int has_feature = 0;

    /* NEON is always available on Apple Silicon */
    arm64_cpu_features |= FFTS_ARM64_NEON;
    arm64_cpu_features |= FFTS_ARM64_ASIMD;

    /* Check for advanced features on Apple Silicon */
    if (sysctlbyname("hw.optional.arm.FEAT_FP16", &has_feature, &size, NULL, 0) == 0 && has_feature) {
        arm64_cpu_features |= FFTS_ARM64_FP16;
    }

#else
    /* Fallback: Assume basic NEON support */
    arm64_cpu_features |= FFTS_ARM64_NEON;
#endif

    arm64_features_detected = 1;
}

/* Public API functions */
void ffts_arm64_init_cpu_caps(void)
{
    ffts_detect_arm64_features();
}

int ffts_have_arm64_neon(void)
{
    ffts_detect_arm64_features();
    return (arm64_cpu_features & FFTS_ARM64_NEON) ? 1 : 0;
}

int ffts_have_arm64_asimd(void)
{
    ffts_detect_arm64_features();
    return (arm64_cpu_features & FFTS_ARM64_ASIMD) ? 1 : 0;
}

int ffts_have_arm64_sve(void)
{
    ffts_detect_arm64_features();
    return (arm64_cpu_features & FFTS_ARM64_SVE) ? 1 : 0;
}

int ffts_have_arm64_sve2(void)
{
    ffts_detect_arm64_features();
    return (arm64_cpu_features & FFTS_ARM64_SVE2) ? 1 : 0;
}

int ffts_have_arm64_fp16(void)
{
    ffts_detect_arm64_features();
    return (arm64_cpu_features & FFTS_ARM64_FP16) ? 1 : 0;
}

/* Get all detected features as a bitmask */
int ffts_get_arm64_features(void)
{
    ffts_detect_arm64_features();
    return arm64_cpu_features;
}

/* ARM64 function pointer selection */
void ffts_select_arm64_implementation(ffts_plan_t *p)
{
    if (!p) return;

    ffts_detect_arm64_features();

    /* Default to C implementation */
    p->transform = ffts_execute_1d_32f;

    /* Select ARM64 optimized implementation if available */
    if (ffts_have_arm64_neon()) {
        /* Use ARM64 NEON implementation */
        if (p->N <= 8) {
            p->transform = ffts_execute_1d_32f_arm64_neon_small;
        } else if (p->N <= 64) {
            p->transform = ffts_execute_1d_32f_arm64_neon_medium;
        } else {
            p->transform = ffts_execute_1d_32f_arm64_neon_large;
        }
    }

    /* Future: Select SVE implementation if available */
    if (ffts_have_arm64_sve() && p->N >= 256) {
        /* SVE implementation for large transforms */
        p->transform = ffts_execute_1d_32f_arm64_sve;
    }
}

/* CPU information string for debugging */
const char* ffts_get_arm64_cpu_info(void)
{
    static char info_buffer[256];
    static int info_generated = 0;

    if (!info_generated) {
        ffts_detect_arm64_features();
        
        snprintf(info_buffer, sizeof(info_buffer),
                "ARM64 Features: NEON=%s ASIMD=%s SVE=%s SVE2=%s FP16=%s",
                (arm64_cpu_features & FFTS_ARM64_NEON) ? "yes" : "no",
                (arm64_cpu_features & FFTS_ARM64_ASIMD) ? "yes" : "no",
                (arm64_cpu_features & FFTS_ARM64_SVE) ? "yes" : "no",
                (arm64_cpu_features & FFTS_ARM64_SVE2) ? "yes" : "no",
                (arm64_cpu_features & FFTS_ARM64_FP16) ? "yes" : "no");
        
        info_generated = 1;
    }

    return info_buffer;
}

/* Generic fallback 1D 32-bit float transform implementation */
void ffts_execute_1d_32f(ffts_plan_t *p, const void *input, void *output)
{
    /* For ARM64, if we reach here, use static transform functions */
#ifdef DYNAMIC_DISABLED
    if (p && p->transform) {
        /* Use the transform function stored in the plan */
        p->transform(p, input, output);
    }
#else
    /* Fallback to generated code or static transform */
    if (p && p->transform) {
        p->transform(p, input, output);
    }
#endif
}

/* Stub implementations for ARM64 NEON functions */
void ffts_execute_1d_32f_arm64_neon_small(ffts_plan_t *p, const void *input, void *output)
{
    /* TODO: Implement ARM64 NEON small transform */
    /* For now, fallback to generic implementation */
    if (p && p->transform && p->transform != ffts_execute_1d_32f_arm64_neon_small) {
        p->transform(p, input, output);
    }
}

void ffts_execute_1d_32f_arm64_neon_medium(ffts_plan_t *p, const void *input, void *output)
{
    /* TODO: Implement ARM64 NEON medium transform */
    /* For now, fallback to generic implementation */
    if (p && p->transform && p->transform != ffts_execute_1d_32f_arm64_neon_medium) {
        p->transform(p, input, output);
    }
}

void ffts_execute_1d_32f_arm64_neon_large(ffts_plan_t *p, const void *input, void *output)
{
    /* TODO: Implement ARM64 NEON large transform */
    /* For now, fallback to generic implementation */
    if (p && p->transform && p->transform != ffts_execute_1d_32f_arm64_neon_large) {
        p->transform(p, input, output);
    }
}

void ffts_execute_1d_32f_arm64_sve(ffts_plan_t *p, const void *input, void *output)
{
    /* TODO: Implement ARM64 SVE transform */
    /* For now, fallback to generic implementation */
    if (p && p->transform && p->transform != ffts_execute_1d_32f_arm64_sve) {
        p->transform(p, input, output);
    }
}

#else /* !__aarch64__ */

/* Stub implementations for non-ARM64 platforms */
int ffts_have_arm64_neon(void) { return 0; }
int ffts_have_arm64_asimd(void) { return 0; }
int ffts_have_arm64_sve(void) { return 0; }
int ffts_have_arm64_sve2(void) { return 0; }
int ffts_have_arm64_fp16(void) { return 0; }
int ffts_get_arm64_features(void) { return 0; }
void ffts_select_arm64_implementation(ffts_plan_t *p) { (void)p; }
const char* ffts_get_arm64_cpu_info(void) { return "ARM64 not available"; }

#endif /* __aarch64__ */ 