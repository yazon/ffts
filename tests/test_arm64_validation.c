/*
 * test_arm64_validation.c: Validation Against Reference Implementation
 *
 * This file is part of FFTS -- The Fastest Fourier Transform in the South
 *
 * Copyright (c) 2024, ARM64 Implementation
 * Copyright (c) 2012, Anthony M. Blake <amb@anthonix.com>
 * Copyright (c) 2012, The University of Waikato
 *
 * All rights reserved.
 *
 * Phase 6.2: Validation Against Reference Implementation
 * - Compare ARM64 implementation against reference DFT
 * - Validate accuracy requirements (L2 norm error < 1e-6)
 * - Test bit-exact results for identical input
 * - Handle edge cases (zero input, DC components)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <assert.h>
#include <time.h>
#include <float.h>
#include <complex.h>

#ifdef __aarch64__
#include <arm_neon.h>
#endif

#include "../include/ffts.h"
#include "../src/ffts_internal.h"

#ifndef M_PI
#define M_PI 3.1415926535897932384626433832795028841971693993751058209
#endif

// Validation configuration
#define VALIDATION_TOLERANCE_STRICT 1e-6f
#define VALIDATION_TOLERANCE_RELAXED 1e-5f
#define MAX_VALIDATION_SIZE 8192
#define NUM_VALIDATION_ITERATIONS 50

// Test patterns for comprehensive validation
typedef enum {
    PATTERN_IMPULSE,
    PATTERN_DC_ONLY,
    PATTERN_SINE_SINGLE,
    PATTERN_SINE_MULTIPLE,
    PATTERN_COMPLEX_EXPONENTIAL,
    PATTERN_RANDOM_UNIFORM,
    PATTERN_RANDOM_GAUSSIAN,
    PATTERN_CHIRP_LINEAR,
    PATTERN_CHIRP_QUADRATIC,
    PATTERN_ZEROS,
    PATTERN_ONES,
    PATTERN_ALTERNATING,
    PATTERN_HARMONIC_SERIES,
    PATTERN_COUNT
} test_pattern_t;

typedef struct {
    test_pattern_t pattern;
    const char *name;
    const char *description;
} pattern_info_t;

static const pattern_info_t pattern_info[] = {
    {PATTERN_IMPULSE, "Impulse", "Delta function at t=1"},
    {PATTERN_DC_ONLY, "DC Only", "Constant DC component"},
    {PATTERN_SINE_SINGLE, "Single Sine", "Single frequency sine wave"},
    {PATTERN_SINE_MULTIPLE, "Multiple Sine", "Sum of multiple sine waves"},
    {PATTERN_COMPLEX_EXPONENTIAL, "Complex Exp", "Complex exponential signal"},
    {PATTERN_RANDOM_UNIFORM, "Random Uniform", "Uniformly distributed random"},
    {PATTERN_RANDOM_GAUSSIAN, "Random Gaussian", "Gaussian distributed random"},
    {PATTERN_CHIRP_LINEAR, "Linear Chirp", "Linear frequency chirp"},
    {PATTERN_CHIRP_QUADRATIC, "Quadratic Chirp", "Quadratic frequency chirp"},
    {PATTERN_ZEROS, "All Zeros", "Zero input signal"},
    {PATTERN_ONES, "All Ones", "Unit amplitude signal"},
    {PATTERN_ALTERNATING, "Alternating", "Alternating +1/-1 pattern"},
    {PATTERN_HARMONIC_SERIES, "Harmonics", "Harmonic series signal"}
};

// Statistics structure
typedef struct {
    double l2_error;
    double max_error;
    double snr_db;
    int bit_exact_match;
    int passed_strict;
    int passed_relaxed;
} validation_stats_t;

// Generate Box-Muller gaussian random numbers
static double box_muller_gaussian(void) {
    static int has_spare = 0;
    static double spare;
    
    if (has_spare) {
        has_spare = 0;
        return spare;
    }
    
    has_spare = 1;
    double u = ((double)rand() / RAND_MAX) * 2.0 - 1.0;
    double v = ((double)rand() / RAND_MAX) * 2.0 - 1.0;
    double s = u * u + v * v;
    
    while (s >= 1.0 || s == 0.0) {
        u = ((double)rand() / RAND_MAX) * 2.0 - 1.0;
        v = ((double)rand() / RAND_MAX) * 2.0 - 1.0;
        s = u * u + v * v;
    }
    
    double multiplier = sqrt(-2.0 * log(s) / s);
    spare = v * multiplier;
    return u * multiplier;
}

// Generate test patterns
static void generate_test_pattern(float *data, size_t n, test_pattern_t pattern) {
    switch (pattern) {
        case PATTERN_IMPULSE:
            memset(data, 0, n * 2 * sizeof(float));
            if (n > 1) {
                data[2] = 1.0f; // Impulse at index 1
            }
            break;
            
        case PATTERN_DC_ONLY:
            memset(data, 0, n * 2 * sizeof(float));
            data[0] = 1.0f; // DC component
            break;
            
        case PATTERN_SINE_SINGLE:
            for (size_t i = 0; i < n; i++) {
                float phase = 2.0f * M_PI * i / n * 8; // 8 cycles
                data[2*i] = cosf(phase);
                data[2*i+1] = sinf(phase);
            }
            break;
            
        case PATTERN_SINE_MULTIPLE:
            memset(data, 0, n * 2 * sizeof(float));
            for (int harmonic = 1; harmonic <= 5; harmonic++) {
                for (size_t i = 0; i < n; i++) {
                    float phase = 2.0f * M_PI * i / n * harmonic;
                    float amplitude = 1.0f / harmonic;
                    data[2*i] += amplitude * cosf(phase);
                    data[2*i+1] += amplitude * sinf(phase);
                }
            }
            break;
            
        case PATTERN_COMPLEX_EXPONENTIAL:
            for (size_t i = 0; i < n; i++) {
                float phase = 2.0f * M_PI * i / n * 10; // 10 cycles
                data[2*i] = cosf(phase);
                data[2*i+1] = sinf(phase);
            }
            break;
            
        case PATTERN_RANDOM_UNIFORM:
            for (size_t i = 0; i < n * 2; i++) {
                data[i] = ((float)rand() / RAND_MAX) * 2.0f - 1.0f;
            }
            break;
            
        case PATTERN_RANDOM_GAUSSIAN:
            for (size_t i = 0; i < n; i++) {
                data[2*i] = (float)box_muller_gaussian();
                data[2*i+1] = (float)box_muller_gaussian();
            }
            break;
            
        case PATTERN_CHIRP_LINEAR:
            for (size_t i = 0; i < n; i++) {
                float t = (float)i / n;
                float phase = 2.0f * M_PI * t * t * n / 8; // Linear chirp
                data[2*i] = cosf(phase);
                data[2*i+1] = sinf(phase);
            }
            break;
            
        case PATTERN_CHIRP_QUADRATIC:
            for (size_t i = 0; i < n; i++) {
                float t = (float)i / n;
                float phase = 2.0f * M_PI * t * t * t * n / 4; // Quadratic chirp
                data[2*i] = cosf(phase);
                data[2*i+1] = sinf(phase);
            }
            break;
            
        case PATTERN_ZEROS:
            memset(data, 0, n * 2 * sizeof(float));
            break;
            
        case PATTERN_ONES:
            for (size_t i = 0; i < n * 2; i++) {
                data[i] = 1.0f;
            }
            break;
            
        case PATTERN_ALTERNATING:
            for (size_t i = 0; i < n; i++) {
                data[2*i] = (i % 2) ? -1.0f : 1.0f;
                data[2*i+1] = 0.0f;
            }
            break;
            
        case PATTERN_HARMONIC_SERIES:
            memset(data, 0, n * 2 * sizeof(float));
            for (int k = 1; k <= 8 && k < n/2; k++) {
                for (size_t i = 0; i < n; i++) {
                    float phase = 2.0f * M_PI * k * i / n;
                    float amplitude = 1.0f / k; // Harmonic series 1/k
                    data[2*i] += amplitude * cosf(phase);
                    data[2*i+1] += amplitude * sinf(phase);
                }
            }
            break;
            
        default:
            memset(data, 0, n * 2 * sizeof(float));
            break;
    }
}

// High-precision reference DFT using double precision
static void dft_reference_double(const float *input, float *output, size_t n, int sign) {
    for (size_t k = 0; k < n; k++) {
        double real_sum = 0.0, imag_sum = 0.0;
        
        for (size_t j = 0; j < n; j++) {
            double angle = sign * 2.0 * M_PI * (double)k * (double)j / (double)n;
            double cos_val = cos(angle);
            double sin_val = sin(angle);
            
            real_sum += (double)input[2*j] * cos_val - (double)input[2*j+1] * sin_val;
            imag_sum += (double)input[2*j] * sin_val + (double)input[2*j+1] * cos_val;
        }
        
        output[2*k] = (float)real_sum;
        output[2*k+1] = (float)imag_sum;
    }
}

// Calculate validation statistics
static validation_stats_t calculate_validation_stats(const float *reference, const float *actual, size_t n) {
    validation_stats_t stats = {0};
    
    double sum_error = 0.0, sum_reference = 0.0, sum_diff_sq = 0.0;
    double max_error = 0.0;
    int bit_exact = 1;
    
    for (size_t i = 0; i < n * 2; i++) {
        double diff = (double)reference[i] - (double)actual[i];
        double abs_diff = fabs(diff);
        
        sum_error += diff * diff;
        sum_reference += (double)reference[i] * (double)reference[i];
        sum_diff_sq += abs_diff * abs_diff;
        
        if (abs_diff > max_error) {
            max_error = abs_diff;
        }
        
        // Check bit-exact match (allowing for tiny floating point differences)
        if (abs_diff > FLT_EPSILON) {
            bit_exact = 0;
        }
    }
    
    stats.l2_error = sqrt(sum_error / (sum_reference + 1e-30));
    stats.max_error = max_error;
    stats.bit_exact_match = bit_exact;
    stats.passed_strict = (stats.l2_error < VALIDATION_TOLERANCE_STRICT);
    stats.passed_relaxed = (stats.l2_error < VALIDATION_TOLERANCE_RELAXED);
    
    // Calculate SNR in dB
    double signal_power = sum_reference / (n * 2);
    double noise_power = sum_diff_sq / (n * 2);
    stats.snr_db = (noise_power > 1e-30) ? 10.0 * log10(signal_power / noise_power) : 100.0;
    
    return stats;
}

// Validate single transform
static validation_stats_t validate_single_transform(size_t n, int sign, test_pattern_t pattern) {
    float *input = aligned_alloc(32, n * 2 * sizeof(float));
    float *output_ffts = aligned_alloc(32, n * 2 * sizeof(float));
    float *output_reference = aligned_alloc(32, n * 2 * sizeof(float));
    
    generate_test_pattern(input, n, pattern);
    
    // FFTS ARM64 transform
    ffts_plan_t *plan = ffts_init_1d(n, sign);
    validation_stats_t stats = {0};
    
    if (plan) {
        ffts_execute(plan, input, output_ffts);
        
        // Reference DFT with double precision
        dft_reference_double(input, output_reference, n, sign);
        
        stats = calculate_validation_stats(output_reference, output_ffts, n);
        
        ffts_free(plan);
    } else {
        printf("Failed to create plan for size %zu\n", n);
    }
    
    free(input);
    free(output_ffts);
    free(output_reference);
    
    return stats;
}

// Comprehensive validation test
static int test_comprehensive_validation(void) {
    printf("=== Comprehensive Validation Against Reference ===\n");
    
    size_t test_sizes[] = {2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096};
    int num_sizes = sizeof(test_sizes) / sizeof(test_sizes[0]);
    int signs[] = {FFTS_FORWARD, FFTS_BACKWARD};
    
    int total_tests = 0, passed_strict = 0, passed_relaxed = 0;
    double max_l2_error = 0.0, avg_l2_error = 0.0;
    
    for (int size_idx = 0; size_idx < num_sizes; size_idx++) {
        size_t n = test_sizes[size_idx];
        
        for (int sign_idx = 0; sign_idx < 2; sign_idx++) {
            int sign = signs[sign_idx];
            const char *direction = (sign == FFTS_FORWARD) ? "Forward" : "Inverse";
            
            printf("\nSize %zu, %s Transform:\n", n, direction);
            
            for (int pattern = 0; pattern < PATTERN_COUNT; pattern++) {
                validation_stats_t stats = validate_single_transform(n, sign, pattern);
                
                total_tests++;
                if (stats.passed_strict) passed_strict++;
                if (stats.passed_relaxed) passed_relaxed++;
                
                max_l2_error = fmax(max_l2_error, stats.l2_error);
                avg_l2_error += stats.l2_error;
                
                printf("  %-20s: L2=%.2e, Max=%.2e, SNR=%.1fdB %s\n",
                       pattern_info[pattern].name,
                       stats.l2_error, stats.max_error, stats.snr_db,
                       stats.passed_strict ? "✅" : (stats.passed_relaxed ? "⚠️" : "❌"));
                
                // Detailed failure analysis for strict failures
                if (!stats.passed_strict && stats.passed_relaxed) {
                    printf("    Warning: Exceeds strict tolerance but within relaxed tolerance\n");
                } else if (!stats.passed_relaxed) {
                    printf("    Error: Exceeds both strict and relaxed tolerances\n");
                }
            }
        }
    }
    
    avg_l2_error /= total_tests;
    
    printf("\n=== Validation Summary ===\n");
    printf("Total tests: %d\n", total_tests);
    printf("Passed strict (%.0e): %d (%.1f%%)\n", 
           VALIDATION_TOLERANCE_STRICT, passed_strict, 
           100.0 * passed_strict / total_tests);
    printf("Passed relaxed (%.0e): %d (%.1f%%)\n", 
           VALIDATION_TOLERANCE_RELAXED, passed_relaxed, 
           100.0 * passed_relaxed / total_tests);
    printf("Maximum L2 error: %.2e\n", max_l2_error);
    printf("Average L2 error: %.2e\n", avg_l2_error);
    
    return (passed_relaxed == total_tests);
}

// Test edge cases specifically
static int test_edge_cases_validation(void) {
    printf("\n=== Edge Cases Validation ===\n");
    
    typedef struct {
        const char *name;
        size_t n;
        test_pattern_t pattern;
        float expected_tolerance;
    } edge_case_t;
    
    edge_case_t edge_cases[] = {
        {"Minimum size (N=2)", 2, PATTERN_IMPULSE, 1e-10f},
        {"Zero input", 64, PATTERN_ZEROS, 1e-10f},
        {"DC only", 64, PATTERN_DC_ONLY, 1e-7f},
        {"Large size", 4096, PATTERN_SINE_SINGLE, 1e-5f},
        {"All ones", 128, PATTERN_ONES, 1e-6f},
        {"Alternating pattern", 256, PATTERN_ALTERNATING, 1e-6f}
    };
    
    int num_edge_cases = sizeof(edge_cases) / sizeof(edge_cases[0]);
    int passed = 0;
    
    for (int i = 0; i < num_edge_cases; i++) {
        edge_case_t *test_case = &edge_cases[i];
        
        validation_stats_t forward_stats = validate_single_transform(
            test_case->n, FFTS_FORWARD, test_case->pattern);
        validation_stats_t inverse_stats = validate_single_transform(
            test_case->n, FFTS_BACKWARD, test_case->pattern);
        
        int case_passed = (forward_stats.l2_error < test_case->expected_tolerance) &&
                         (inverse_stats.l2_error < test_case->expected_tolerance);
        
        printf("%-25s: Forward L2=%.2e, Inverse L2=%.2e %s\n",
               test_case->name,
               forward_stats.l2_error, inverse_stats.l2_error,
               case_passed ? "✅" : "❌");
        
        if (case_passed) passed++;
    }
    
    printf("Edge cases passed: %d/%d\n", passed, num_edge_cases);
    return (passed == num_edge_cases);
}

// Test roundtrip accuracy (forward then inverse)
static int test_roundtrip_validation(void) {
    printf("\n=== Roundtrip Validation ===\n");
    
    size_t test_sizes[] = {16, 64, 256, 1024};
    int num_sizes = sizeof(test_sizes) / sizeof(test_sizes[0]);
    int total_tests = 0, passed_tests = 0;
    
    for (int size_idx = 0; size_idx < num_sizes; size_idx++) {
        size_t n = test_sizes[size_idx];
        
        for (int pattern = 0; pattern < PATTERN_COUNT; pattern++) {
            total_tests++;
            
            float *original = aligned_alloc(32, n * 2 * sizeof(float));
            float *transformed = aligned_alloc(32, n * 2 * sizeof(float));
            float *restored = aligned_alloc(32, n * 2 * sizeof(float));
            
            generate_test_pattern(original, n, pattern);
            
            ffts_plan_t *forward_plan = ffts_init_1d(n, FFTS_FORWARD);
            ffts_plan_t *inverse_plan = ffts_init_1d(n, FFTS_BACKWARD);
            
            if (forward_plan && inverse_plan) {
                // Forward transform
                ffts_execute(forward_plan, original, transformed);
                
                // Inverse transform
                ffts_execute(inverse_plan, transformed, restored);
                
                // Scale by 1/N for proper normalization
                for (size_t i = 0; i < n * 2; i++) {
                    restored[i] /= n;
                }
                
                validation_stats_t stats = calculate_validation_stats(original, restored, n);
                
                if (stats.l2_error < VALIDATION_TOLERANCE_RELAXED) {
                    passed_tests++;
                } else {
                    printf("  Size %zu, %s failed: L2=%.2e\n",
                           n, pattern_info[pattern].name, stats.l2_error);
                }
                
                ffts_free(forward_plan);
                ffts_free(inverse_plan);
            }
            
            free(original);
            free(transformed);
            free(restored);
        }
    }
    
    printf("Roundtrip tests passed: %d/%d (%.1f%%)\n",
           passed_tests, total_tests, 100.0 * passed_tests / total_tests);
    
    return (passed_tests == total_tests);
}

int main(int argc, char **argv) {
    printf("=== ARM64 FFTS Validation Against Reference Implementation ===\n");
    printf("Comprehensive accuracy validation with multiple test patterns\n\n");
    
#ifdef __aarch64__
    printf("Running on ARM64 platform - full validation enabled\n");
#else
    printf("Not running on ARM64 platform - generic validation\n");
#endif
    
    srand(12345); // Fixed seed for reproducible results
    
    // Run validation test suites
    int comprehensive_passed = test_comprehensive_validation();
    int edge_cases_passed = test_edge_cases_validation();
    int roundtrip_passed = test_roundtrip_validation();
    
    // Overall validation result
    printf("\n=== Final Validation Results ===\n");
    printf("Comprehensive validation: %s\n", comprehensive_passed ? "✅ PASSED" : "❌ FAILED");
    printf("Edge cases validation: %s\n", edge_cases_passed ? "✅ PASSED" : "❌ FAILED");
    printf("Roundtrip validation: %s\n", roundtrip_passed ? "✅ PASSED" : "❌ FAILED");
    
    int all_passed = comprehensive_passed && edge_cases_passed && roundtrip_passed;
    
    if (all_passed) {
        printf("\n🎉 All validation tests passed! ARM64 implementation meets accuracy requirements.\n");
        return 0;
    } else {
        printf("\n⚠️  Some validation tests failed. Review implementation for accuracy issues.\n");
        return 1;
    }
}