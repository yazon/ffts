#define _USE_MATH_DEFINES
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <stdint.h>
#include "ffts.h"

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

static void print_complex_array(const char* name, const float* arr, int N) {
    printf("%s: ", name);
    for (int i = 0; i < N; i++) {
        printf("(%.6f%+.6fi)", arr[2*i], arr[2*i+1]);
        if (i < N-1) printf(", ");
    }
    printf("\n");
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
    printf("Debug Test for Size 8 FFT - Complex Pattern\n");
    printf("==========================================\n\n");
    
    int N = 8;
    
    // More complex input pattern that will exercise twiddle factors 
    float* input = (float*)malloc(2 * N * sizeof(float));
    float* output_ffts = (float*)malloc(2 * N * sizeof(float));
    float* output_ref = (float*)malloc(2 * N * sizeof(float));
    
    // Initialize with pattern: [1+1i, 2+0i, 1-1i, 0+2i, ...]
    for (int i = 0; i < N; i++) {
        input[2*i] = (float)(i + 1);      // Real part: 1, 2, 3, 4...
        input[2*i+1] = (float)(i);        // Imaginary part: 0, 1, 2, 3...
    }
    
    print_complex_array("Input", input, N);
    
    // FFTS forward transform
    ffts_plan_t* plan = ffts_init_1d(N, FFTS_FORWARD);
    if (plan) {
        ffts_execute(plan, input, output_ffts);
        print_complex_array("FFTS Output", output_ffts, N);
        ffts_free(plan);
    } else {
        printf("Failed to create FFTS plan\n");
        free(input); free(output_ffts); free(output_ref);
        return 1;
    }
    
    // Reference implementation
    reference_dft(input, output_ref, N, 0);
    print_complex_array("Reference Output", output_ref, N);
    
    // Check differences
    printf("\nDifferences:\n");
    double max_error = 0.0;
    for (int i = 0; i < N; i++) {
        double re_diff = output_ffts[2*i] - output_ref[2*i];
        double im_diff = output_ffts[2*i+1] - output_ref[2*i+1];
        double abs_diff = sqrt(re_diff*re_diff + im_diff*im_diff);
        
        printf("[%d]: FFTS(%.6f%+.6fi) vs REF(%.6f%+.6fi) -> diff=%.6f\n", 
               i, output_ffts[2*i], output_ffts[2*i+1], 
               output_ref[2*i], output_ref[2*i+1], abs_diff);
        
        if (abs_diff > max_error) max_error = abs_diff;
    }
    
    printf("\nMax error: %.6e\n", max_error);
    
    free(input);
    free(output_ffts);
    free(output_ref);
    
    return 0;
} 