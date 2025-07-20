#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <ffts.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

int main() {
    const size_t N = 1024;
    ffts_plan_t *plan;
    float *input, *output;
    size_t i;

    printf("FFTS Simple Example\n");
    printf("==================\n");
    printf("Computing %zu-point forward FFT\n\n", N);

    // Allocate aligned memory for input and output
    input = (float*)ffts_malloc(2 * N * sizeof(float));
    output = (float*)ffts_malloc(2 * N * sizeof(float));
    
    if (!input || !output) {
        fprintf(stderr, "Error: Failed to allocate memory\n");
        return 1;
    }

    // Initialize input with a simple sine wave
    for (i = 0; i < N; i++) {
        // Real part: sine wave at frequency 10
        input[2*i] = sinf(2.0f * M_PI * 10.0f * i / N);
        // Imaginary part: zero
        input[2*i + 1] = 0.0f;
    }

    // Create FFT plan
    plan = ffts_init_1d(N, FFTS_FORWARD);
    if (!plan) {
        fprintf(stderr, "Error: Failed to create FFT plan\n");
        ffts_free(input);
        ffts_free(output);
        return 1;
    }

    // Execute FFT
    ffts_execute(plan, input, output);

    // Print first 10 results
    printf("First 10 FFT results:\n");
    for (i = 0; i < 10; i++) {
        printf("X[%2zu] = %8.4f + %8.4f*i (magnitude: %8.4f)\n", 
               i, output[2*i], output[2*i + 1], 
               sqrtf(output[2*i]*output[2*i] + output[2*i + 1]*output[2*i + 1]));
    }

    // Clean up
    ffts_free(plan);
    ffts_free(input);
    ffts_free(output);

    printf("\nFFT completed successfully!\n");
    return 0;
}