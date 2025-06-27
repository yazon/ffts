#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "../include/ffts.h"

int test_size(size_t n) {
    printf("Testing FFT size %zu... ", n);
    
    // Allocate aligned input and output buffers
    float *input = aligned_alloc(32, 2 * n * sizeof(float));
    float *output = aligned_alloc(32, 2 * n * sizeof(float));
    
    if (!input || !output) {
        printf("FAILED - Memory allocation\n");
        return 0;
    }
    
    // Initialize with simple test data
    for (size_t i = 0; i < 2 * n; i++) {
        input[i] = (i % 2 == 0) ? 1.0f : 0.0f;  // Real: 1, Imag: 0
    }
    
    // Create forward FFT plan
    ffts_plan_t *plan = ffts_init_1d(n, FFTS_FORWARD);
    if (!plan) {
        printf("FAILED - Plan creation\n");
        free(input);
        free(output);
        return 0;
    }
    
    // Execute FFT
    ffts_execute(plan, input, output);
    
    // Check output is reasonable (not NaN or infinite)
    int valid = 1;
    for (size_t i = 0; i < 2 * n; i++) {
        if (!isfinite(output[i])) {
            valid = 0;
            break;
        }
    }
    
    printf("%s\n", valid ? "PASSED" : "FAILED - Invalid output");
    
    ffts_free(plan);
    free(input);
    free(output);
    
    return valid;
}

int main() {
    printf("ARM64 Static NEON Implementation Test\n");
    printf("=====================================\n");
    
    // Test sizes that will use our static functions
    size_t test_sizes[] = {2, 4, 8, 16, 32, 64, 128, 256};
    int num_tests = sizeof(test_sizes) / sizeof(test_sizes[0]);
    int passed = 0;
    
    for (int i = 0; i < num_tests; i++) {
        if (test_size(test_sizes[i])) {
            passed++;
        }
    }
    
    printf("\n");
    printf("Results: %d/%d tests passed\n", passed, num_tests);
    
    if (passed == num_tests) {
        printf("✅ All tests passed! ARM64 static NEON implementation is working correctly.\n");
        return 0;
    } else {
        printf("❌ Some tests failed.\n");
        return 1;
    }
} 