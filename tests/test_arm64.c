/*
 * test_arm64.c: Comprehensive unit tests for ARM64 FFTS implementation
 *
 * This file is part of FFTS -- The Fastest Fourier Transform in the South
 *
 * Copyright (c) 2024, ARM64 Implementation
 * Copyright (c) 2012, Anthony M. Blake <amb@anthonix.com>
 * Copyright (c) 2012, The University of Waikato
 *
 * All rights reserved.
 *
 * Phase 6.1: Unit Tests for ARM64
 * - Basic functionality tests for ARM64 FFT implementations
 * - Accuracy validation for various transform sizes
 * - Edge case testing and error handling
 * - SIMD macro validation
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <assert.h>
#include <time.h>
#include <complex.h>

#ifdef __aarch64__
#include <arm_neon.h>
#endif

#include "../include/ffts.h"
#include "../src/ffts_internal.h"

#ifndef M_PI
#define M_PI 3.1415926535897932384626433832795028841971693993751058209
#endif

// Test configuration
#define TEST_TOLERANCE_SINGLE 1e-5f
#define TEST_TOLERANCE_DOUBLE 1e-12
#define MAX_TEST_SIZE 16384
#define NUM_RANDOM_TESTS 100

// Test result structure
typedef struct {
    const char *test_name;
    int passed;
    int total;
    double max_error;
    double avg_error;
} test_result_t;

// Global test statistics
static int total_tests = 0;
static int passed_tests = 0;

// Utility functions
static void print_test_header(const char *test_name) {
    printf("\n=== %s ===\n", test_name);
}

static void print_test_result(test_result_t *result) {
    printf("%-30s: %s (%d/%d) - Max Error: %.2e, Avg Error: %.2e\n",
           result->test_name,
           result->passed == result->total ? "PASS" : "FAIL",
           result->passed, result->total,
           result->max_error, result->avg_error);
    
    total_tests += result->total;
    passed_tests += result->passed;
}

// Complex number utilities
static float complex cexp_f(float complex z) {
    float r = cexpf(cimagf(z));
    return r * (cosf(crealf(z)) + I * sinf(crealf(z)));
}

// Generate test signals
static void generate_impulse(float *data, size_t n) {
    memset(data, 0, n * 2 * sizeof(float));
    data[2] = 1.0f; // Impulse at index 1
}

static void generate_sine_wave(float *data, size_t n, float freq) {
    for (size_t i = 0; i < n; i++) {
        float phase = 2.0f * M_PI * freq * i / n;
        data[2*i] = cosf(phase);
        data[2*i+1] = sinf(phase);
    }
}

static void generate_random_data(float *data, size_t n) {
    for (size_t i = 0; i < n * 2; i++) {
        data[i] = (float)(rand() - RAND_MAX/2) / (RAND_MAX/2);
    }
}

static void generate_chirp(float *data, size_t n) {
    for (size_t i = 0; i < n; i++) {
        float t = (float)i / n;
        float phase = 2.0f * M_PI * t * t * n / 4; // Quadratic chirp
        data[2*i] = cosf(phase);
        data[2*i+1] = sinf(phase);
    }
}

// Reference DFT implementation for validation
static void dft_reference(const float *input, float *output, size_t n, int sign) {
    for (size_t k = 0; k < n; k++) {
        float real_sum = 0.0f, imag_sum = 0.0f;
        
        for (size_t j = 0; j < n; j++) {
            float angle = sign * 2.0f * M_PI * k * j / n;
            float cos_val = cosf(angle);
            float sin_val = sinf(angle);
            
            real_sum += input[2*j] * cos_val - input[2*j+1] * sin_val;
            imag_sum += input[2*j] * sin_val + input[2*j+1] * cos_val;
        }
        
        output[2*k] = real_sum;
        output[2*k+1] = imag_sum;
    }
}

// Error calculation
static double calculate_l2_error(const float *expected, const float *actual, size_t n) {
    double sum_error = 0.0, sum_expected = 0.0;
    
    for (size_t i = 0; i < n * 2; i++) {
        double diff = expected[i] - actual[i];
        sum_error += diff * diff;
        sum_expected += expected[i] * expected[i];
    }
    
    return sqrt(sum_error / (sum_expected + 1e-30));
}

static double calculate_max_error(const float *expected, const float *actual, size_t n) {
    double max_error = 0.0;
    
    for (size_t i = 0; i < n * 2; i++) {
        double diff = fabs(expected[i] - actual[i]);
        if (diff > max_error) {
            max_error = diff;
        }
    }
    
    return max_error;
}

// Test basic ARM64 FFT functionality
static test_result_t test_arm64_basic_functionality(void) {
    test_result_t result = {"ARM64 Basic Functionality", 0, 0, 0.0, 0.0};
    print_test_header(result.test_name);
    
    size_t test_sizes[] = {4, 8, 16, 32, 64, 128, 256, 512, 1024};
    int num_sizes = sizeof(test_sizes) / sizeof(test_sizes[0]);
    
    for (int i = 0; i < num_sizes; i++) {
        size_t n = test_sizes[i];
        
        // Test forward transform
        {
            result.total++;
            
            float *input = aligned_alloc(32, n * 2 * sizeof(float));
            float *output = aligned_alloc(32, n * 2 * sizeof(float));
            float *reference = aligned_alloc(32, n * 2 * sizeof(float));
            
            generate_impulse(input, n);
            
            ffts_plan_t *plan = ffts_init_1d(n, FFTS_FORWARD);
            if (plan) {
                ffts_execute(plan, input, output);
                dft_reference(input, reference, n, -1);
                
                double error = calculate_l2_error(reference, output, n);
                if (error < TEST_TOLERANCE_SINGLE) {
                    result.passed++;
                } else {
                    printf("  Size %zu forward failed: error = %.2e\n", n, error);
                }
                
                result.max_error = fmax(result.max_error, error);
                result.avg_error += error;
                
                ffts_free(plan);
            } else {
                printf("  Failed to create plan for size %zu\n", n);
            }
            
            free(input);
            free(output);
            free(reference);
        }
        
        // Test inverse transform
        {
            result.total++;
            
            float *input = aligned_alloc(32, n * 2 * sizeof(float));
            float *output = aligned_alloc(32, n * 2 * sizeof(float));
            float *reference = aligned_alloc(32, n * 2 * sizeof(float));
            
            generate_impulse(input, n);
            
            ffts_plan_t *plan = ffts_init_1d(n, FFTS_BACKWARD);
            if (plan) {
                ffts_execute(plan, input, output);
                dft_reference(input, reference, n, 1);
                
                double error = calculate_l2_error(reference, output, n);
                if (error < TEST_TOLERANCE_SINGLE) {
                    result.passed++;
                } else {
                    printf("  Size %zu inverse failed: error = %.2e\n", n, error);
                }
                
                result.max_error = fmax(result.max_error, error);
                result.avg_error += error;
                
                ffts_free(plan);
            } else {
                printf("  Failed to create plan for size %zu\n", n);
            }
            
            free(input);
            free(output);
            free(reference);
        }
    }
    
    result.avg_error /= result.total;
    return result;
}

// Test ARM64 FFT with various input patterns
static test_result_t test_arm64_input_patterns(void) {
    test_result_t result = {"ARM64 Input Patterns", 0, 0, 0.0, 0.0};
    print_test_header(result.test_name);
    
    size_t test_size = 256;
    
    // Test patterns: impulse, sine waves, random, chirp
    typedef struct {
        const char *name;
        void (*generator)(float*, size_t);
    } test_pattern_t;
    
    test_pattern_t patterns[] = {
        {"Impulse", generate_impulse},
        {"Sine Wave 10Hz", (void(*)(float*, size_t))generate_sine_wave}, // Note: simplified for this example
        {"Random Data", generate_random_data},
        {"Chirp Signal", generate_chirp}
    };
    
    int num_patterns = sizeof(patterns) / sizeof(patterns[0]);
    
    for (int i = 0; i < num_patterns; i++) {
        result.total++;
        
        float *input = aligned_alloc(32, test_size * 2 * sizeof(float));
        float *output = aligned_alloc(32, test_size * 2 * sizeof(float));
        float *reference = aligned_alloc(32, test_size * 2 * sizeof(float));
        
        if (i == 1) { // Sine wave case
            generate_sine_wave(input, test_size, 10.0f);
        } else {
            patterns[i].generator(input, test_size);
        }
        
        ffts_plan_t *plan = ffts_init_1d(test_size, FFTS_FORWARD);
        if (plan) {
            ffts_execute(plan, input, output);
            dft_reference(input, reference, test_size, -1);
            
            double error = calculate_l2_error(reference, output, test_size);
            if (error < TEST_TOLERANCE_SINGLE) {
                result.passed++;
            } else {
                printf("  Pattern '%s' failed: error = %.2e\n", patterns[i].name, error);
            }
            
            result.max_error = fmax(result.max_error, error);
            result.avg_error += error;
            
            ffts_free(plan);
        } else {
            printf("  Failed to create plan for pattern '%s'\n", patterns[i].name);
        }
        
        free(input);
        free(output);
        free(reference);
    }
    
    result.avg_error /= result.total;
    return result;
}

// Test forward/inverse roundtrip accuracy
static test_result_t test_arm64_roundtrip(void) {
    test_result_t result = {"ARM64 Roundtrip", 0, 0, 0.0, 0.0};
    print_test_header(result.test_name);
    
    size_t test_sizes[] = {4, 8, 16, 32, 64, 128, 256, 512, 1024};
    int num_sizes = sizeof(test_sizes) / sizeof(test_sizes[0]);
    
    for (int i = 0; i < num_sizes; i++) {
        size_t n = test_sizes[i];
        result.total++;
        
        float *original = aligned_alloc(32, n * 2 * sizeof(float));
        float *transformed = aligned_alloc(32, n * 2 * sizeof(float));
        float *restored = aligned_alloc(32, n * 2 * sizeof(float));
        
        generate_random_data(original, n);
        
        ffts_plan_t *forward_plan = ffts_init_1d(n, FFTS_FORWARD);
        ffts_plan_t *inverse_plan = ffts_init_1d(n, FFTS_BACKWARD);
        
        if (forward_plan && inverse_plan) {
            // Forward transform
            ffts_execute(forward_plan, original, transformed);
            
            // Inverse transform
            ffts_execute(inverse_plan, transformed, restored);
            
            // Scale by 1/N for proper normalization
            for (size_t j = 0; j < n * 2; j++) {
                restored[j] /= n;
            }
            
            double error = calculate_l2_error(original, restored, n);
            if (error < TEST_TOLERANCE_SINGLE) {
                result.passed++;
            } else {
                printf("  Size %zu roundtrip failed: error = %.2e\n", n, error);
            }
            
            result.max_error = fmax(result.max_error, error);
            result.avg_error += error;
            
            ffts_free(forward_plan);
            ffts_free(inverse_plan);
        } else {
            printf("  Failed to create plans for size %zu\n", n);
        }
        
        free(original);
        free(transformed);
        free(restored);
    }
    
    result.avg_error /= result.total;
    return result;
}

// Test edge cases and error handling
static test_result_t test_arm64_edge_cases(void) {
    test_result_t result = {"ARM64 Edge Cases", 0, 0, 0.0, 0.0};
    print_test_header(result.test_name);
    
    // Test zero input
    {
        result.total++;
        size_t n = 64;
        float *input = aligned_alloc(32, n * 2 * sizeof(float));
        float *output = aligned_alloc(32, n * 2 * sizeof(float));
        
        memset(input, 0, n * 2 * sizeof(float));
        
        ffts_plan_t *plan = ffts_init_1d(n, FFTS_FORWARD);
        if (plan) {
            ffts_execute(plan, input, output);
            
            // All output should be zero
            int all_zero = 1;
            for (size_t i = 0; i < n * 2; i++) {
                if (fabsf(output[i]) > 1e-10f) {
                    all_zero = 0;
                    break;
                }
            }
            
            if (all_zero) {
                result.passed++;
            } else {
                printf("  Zero input test failed\n");
            }
            
            ffts_free(plan);
        }
        
        free(input);
        free(output);
    }
    
    // Test DC component only
    {
        result.total++;
        size_t n = 64;
        float *input = aligned_alloc(32, n * 2 * sizeof(float));
        float *output = aligned_alloc(32, n * 2 * sizeof(float));
        
        memset(input, 0, n * 2 * sizeof(float));
        input[0] = 1.0f; // DC component
        
        ffts_plan_t *plan = ffts_init_1d(n, FFTS_FORWARD);
        if (plan) {
            ffts_execute(plan, input, output);
            
            // Output should have DC at [0] and zeros elsewhere
            int dc_correct = (fabsf(output[0] - 1.0f) < 1e-6f);
            int others_zero = 1;
            
            for (size_t i = 1; i < n * 2; i++) {
                if (fabsf(output[i]) > 1e-6f) {
                    others_zero = 0;
                    break;
                }
            }
            
            if (dc_correct && others_zero) {
                result.passed++;
            } else {
                printf("  DC component test failed\n");
            }
            
            ffts_free(plan);
        }
        
        free(input);
        free(output);
    }
    
    // Test minimum size (N=2)
    {
        result.total++;
        size_t n = 2;
        float *input = aligned_alloc(32, n * 2 * sizeof(float));
        float *output = aligned_alloc(32, n * 2 * sizeof(float));
        float *reference = aligned_alloc(32, n * 2 * sizeof(float));
        
        input[0] = 1.0f; input[1] = 0.0f;
        input[2] = 0.0f; input[3] = 1.0f;
        
        ffts_plan_t *plan = ffts_init_1d(n, FFTS_FORWARD);
        if (plan) {
            ffts_execute(plan, input, output);
            dft_reference(input, reference, n, -1);
            
            double error = calculate_l2_error(reference, output, n);
            if (error < TEST_TOLERANCE_SINGLE) {
                result.passed++;
            } else {
                printf("  Minimum size test failed: error = %.2e\n", error);
            }
            
            ffts_free(plan);
        }
        
        free(input);
        free(output);
        free(reference);
    }
    
    return result;
}

#ifdef __aarch64__
// Test ARM64 SIMD macros directly
static test_result_t test_arm64_simd_macros(void) {
    test_result_t result = {"ARM64 SIMD Macros", 0, 0, 0.0, 0.0};
    print_test_header(result.test_name);
    
    // Test basic NEON operations
    {
        result.total++;
        
        float32x4_t a = {1.0f, 2.0f, 3.0f, 4.0f};
        float32x4_t b = {5.0f, 6.0f, 7.0f, 8.0f};
        float32x4_t c = vaddq_f32(a, b);
        
        float expected[] = {6.0f, 8.0f, 10.0f, 12.0f};
        float actual[4];
        vst1q_f32(actual, c);
        
        int correct = 1;
        for (int i = 0; i < 4; i++) {
            if (fabsf(actual[i] - expected[i]) > 1e-6f) {
                correct = 0;
                break;
            }
        }
        
        if (correct) {
            result.passed++;
        } else {
            printf("  NEON addition test failed\n");
        }
    }
    
    // Test complex multiplication using FMLA
    {
        result.total++;
        
        float32x4_t real1 = {1.0f, 2.0f, 3.0f, 4.0f};
        float32x4_t imag1 = {5.0f, 6.0f, 7.0f, 8.0f};
        float32x4_t real2 = {2.0f, 1.0f, 0.5f, 0.25f};
        float32x4_t imag2 = {1.0f, 2.0f, 3.0f, 4.0f};
        
        // Complex multiplication: (a+bi)(c+di) = (ac-bd) + (ad+bc)i
        float32x4_t real_result = vmulq_f32(real1, real2);
        real_result = vfmsq_f32(real_result, imag1, imag2);
        
        float32x4_t imag_result = vmulq_f32(real1, imag2);
        imag_result = vfmaq_f32(imag_result, imag1, real2);
        
        // Verify first element: (1+5i)(2+i) = (2-5) + (1+10)i = -3 + 11i
        float real_val[4], imag_val[4];
        vst1q_f32(real_val, real_result);
        vst1q_f32(imag_val, imag_result);
        
        if (fabsf(real_val[0] - (-3.0f)) < 1e-6f && fabsf(imag_val[0] - 11.0f) < 1e-6f) {
            result.passed++;
        } else {
            printf("  NEON complex multiplication test failed\n");
        }
    }
    
    return result;
}
#endif

// Random data stress test
static test_result_t test_arm64_random_stress(void) {
    test_result_t result = {"ARM64 Random Stress", 0, 0, 0.0, 0.0};
    print_test_header(result.test_name);
    
    srand(time(NULL));
    
    for (int test = 0; test < NUM_RANDOM_TESTS; test++) {
        result.total++;
        
        // Random size between 4 and 1024 (power of 2)
        int power = 2 + (rand() % 9); // 2^2 to 2^10
        size_t n = 1 << power;
        
        float *input = aligned_alloc(32, n * 2 * sizeof(float));
        float *output = aligned_alloc(32, n * 2 * sizeof(float));
        float *reference = aligned_alloc(32, n * 2 * sizeof(float));
        
        generate_random_data(input, n);
        
        int sign = (rand() % 2) ? FFTS_FORWARD : FFTS_BACKWARD;
        ffts_plan_t *plan = ffts_init_1d(n, sign);
        
        if (plan) {
            ffts_execute(plan, input, output);
            dft_reference(input, reference, n, sign);
            
            double error = calculate_l2_error(reference, output, n);
            if (error < TEST_TOLERANCE_SINGLE) {
                result.passed++;
            }
            
            result.max_error = fmax(result.max_error, error);
            result.avg_error += error;
            
            ffts_free(plan);
        }
        
        free(input);
        free(output);
        free(reference);
    }
    
    result.avg_error /= result.total;
    return result;
}

// Main test runner
int main(int argc, char **argv) {
    printf("=== ARM64 FFTS Unit Tests ===\n");
    printf("Testing ARM64 optimized FFTS implementation\n\n");
    
#ifdef __aarch64__
    printf("Running on ARM64 platform - full test suite enabled\n");
#else
    printf("Not running on ARM64 platform - limited test suite\n");
#endif
    
    // Run all test suites
    test_result_t results[] = {
        test_arm64_basic_functionality(),
        test_arm64_input_patterns(),
        test_arm64_roundtrip(),
        test_arm64_edge_cases(),
#ifdef __aarch64__
        test_arm64_simd_macros(),
#endif
        test_arm64_random_stress()
    };
    
    // Print summary
    printf("\n=== Test Summary ===\n");
    int num_suites = sizeof(results) / sizeof(results[0]);
    for (int i = 0; i < num_suites; i++) {
        print_test_result(&results[i]);
    }
    
    printf("\nOverall: %d/%d tests passed (%.1f%%)\n",
           passed_tests, total_tests, 
           total_tests > 0 ? 100.0 * passed_tests / total_tests : 0.0);
    
    if (passed_tests == total_tests) {
        printf("✅ All ARM64 unit tests passed!\n");
        return 0;
    } else {
        printf("❌ Some ARM64 unit tests failed!\n");
        return 1;
    }
}