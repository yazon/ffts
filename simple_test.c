#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <stdint.h>
#include "ffts.h"

static double compute_error(const float* computed, const float* expected, int N) {
    double error = 0.0;
    for (int i = 0; i < 2*N; i++) {
        double diff = computed[i] - expected[i];
        error += diff * diff;
    }
    return sqrt(error);
}

static void reference_dft(const float* input, float* output, int N, int inverse) {
    for (int k = 0; k < N; k++) {
        float real = 0.0f, imag = 0.0f;
        for (int n = 0; n < N; n++) {
            float angle = (inverse ? 2.0f : -2.0f) * M_PI * k * n / N;
            float cos_val = cos(angle), sin_val = sin(angle);
            
            real += input[2*n] * cos_val - input[2*n+1] * sin_val;
            imag += input[2*n] * sin_val + input[2*n+1] * cos_val;
        }
        output[2*k] = real;
        output[2*k+1] = imag;
    }
}

int main() {
    printf("Testing FFTS ARM64 Implementation\n");
    printf("==================================\n\n");
    
    int sizes[] = {2, 4, 8, 16};
    int num_sizes = sizeof(sizes) / sizeof(sizes[0]);
    
    for (int s = 0; s < num_sizes; s++) {
        int N = sizes[s];
        printf("Testing size %d:\n", N);
        
        // Allocate input and output arrays
        float* input = (float*)malloc(2 * N * sizeof(float));
        float* output = (float*)malloc(2 * N * sizeof(float));
        float* expected = (float*)malloc(2 * N * sizeof(float));
        
        // Initialize with simple test pattern
        for (int i = 0; i < N; i++) {
            input[2*i] = (float)(i + 1);      // Real part
            input[2*i+1] = (float)(i);        // Imaginary part
        }
        
        // Test forward transform
        ffts_plan_t* plan_forward = ffts_init_1d(N, FFTS_FORWARD);
        if (plan_forward) {
            ffts_execute(plan_forward, input, output);
            
            // Compute reference
            reference_dft(input, expected, N, 0);
            
            double error = compute_error(output, expected, N);
            printf("  Forward:  Error = %.6e", error);
            if (error > 1e-5) printf(" *** LARGE ERROR ***");
            printf("\n");
            
            ffts_free(plan_forward);
        } else {
            printf("  Forward:  Failed to create plan\n");
        }
        
        // Test inverse transform  
        ffts_plan_t* plan_inverse = ffts_init_1d(N, FFTS_BACKWARD);
        if (plan_inverse) {
            ffts_execute(plan_inverse, input, output);
            
            // Compute reference
            reference_dft(input, expected, N, 1);
            
            double error = compute_error(output, expected, N);
            printf("  Inverse:  Error = %.6e", error);
            if (error > 1e-5) printf(" *** LARGE ERROR ***");
            printf("\n");
            
            ffts_free(plan_inverse);
        } else {
            printf("  Inverse:  Failed to create plan\n");
        }
        
        free(input);
        free(output);
        free(expected);
        printf("\n");
    }
    
    return 0;
} 