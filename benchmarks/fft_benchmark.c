#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>
#include <ffts.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// Simple timing function
static double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1e9;
}

void benchmark_fft(size_t N, int iterations) {
    ffts_plan_t *plan;
    float *input, *output;
    double start_time, end_time, total_time;
    size_t i, iter;

    printf("Benchmarking %zu-point FFT with %d iterations...\n", N, iterations);

    // Allocate aligned memory
    input = (float*)ffts_malloc(2 * N * sizeof(float));
    if (!input) {
        fprintf(stderr, "Error: Failed to allocate input memory for size %zu\n", N);
        return;
    }
    
    output = (float*)ffts_malloc(2 * N * sizeof(float));
    if (!output) {
        fprintf(stderr, "Error: Failed to allocate output memory for size %zu\n", N);
        ffts_free(input);
        return;
    }

    // Initialize input with random data
    for (i = 0; i < N; i++) {
        input[2*i] = (float)rand() / RAND_MAX - 0.5f;
        input[2*i + 1] = (float)rand() / RAND_MAX - 0.5f;
    }

    // Create FFT plan
    plan = ffts_init_1d(N, FFTS_FORWARD);
    if (!plan) {
        fprintf(stderr, "Error: Failed to create FFT plan for size %zu\n", N);
        ffts_free(input);
        ffts_free(output);
        return;
    }

    // Warm up
    ffts_execute(plan, input, output);

    // Benchmark
    start_time = get_time();
    for (iter = 0; iter < iterations; iter++) {
        ffts_execute(plan, input, output);
    }
    end_time = get_time();

    total_time = end_time - start_time;
    double avg_time = total_time / iterations;
    double mflops = (5.0 * N * log2(N) / avg_time) / 1e6;

    printf("  Size: %8zu | Avg time: %8.3f μs | MFLOPS: %8.2f\n", 
           N, avg_time * 1e6, mflops);

    // Clean up
    ffts_free(plan);
    ffts_free(input);
    ffts_free(output);
}

int main() {
    const int iterations = 1000;
    size_t sizes[] = {64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384};
    size_t num_sizes = sizeof(sizes) / sizeof(sizes[0]);
    size_t i;

    printf("FFTS Performance Benchmark\n");
    printf("==========================\n");
    printf("Number of iterations per size: %d\n\n", iterations);

    // Seed random number generator
    srand((unsigned int)time(NULL));

    for (i = 0; i < num_sizes; i++) {
        benchmark_fft(sizes[i], iterations);
    }

    printf("\nBenchmark completed!\n");
    printf("Note: MFLOPS calculation assumes 5*N*log2(N) operations per FFT\n");
    
    return 0;
}