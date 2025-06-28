// neon64_static_unit.c – Focused unit-tests for ARM64 static routines
// Build:  gcc -std=c99 -O2 -I../include -I../src -DUNIT_TEST_NEON64_STATIC tests/neon64_static_unit.c ../src/*.c -lm
//
// The tester exercises the public FFTS transform for a hand-picked set of
// sizes so that each of the ARM64 static assembly kernels is invoked at
// least once.  The numerical results are validated against a high-accuracy
// naïve DFT computed in double precision.
//
//  Covered kernels (size that first triggers it):
//   • neon_static_e_f / neon_static_o_f      (N = 32, 64, 128 …)
//   • neon_static_x4_f                      (N = 64)
//   • neon_static_x8_f                      (N = 128)
//   • neon_static_x8_t_f                    (N = 32, 64, 128)
//
//  The test is AArch64-only; if built on other architectures the program
//  compiles but exits with SKIPPED to avoid false negatives.

#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <assert.h>
#include <signal.h>
#include <unistd.h>
#include <errno.h>

#include "../include/ffts.h"

#ifndef M_PI
#define M_PI 3.141592653589793238462643383279502884L
#endif

#define TOLERANCE 1e-4f   /* single-precision RMS error acceptable */

static volatile size_t g_current_N = 0;
static volatile int    g_current_sign = 0;

static void segv_handler(int sig) {
    (void)sig;
    fprintf(stderr, "\nCaught SIGSEGV while processing N=%zu sign=%d\n", g_current_N, g_current_sign);
    _Exit(128 + sig);
}

// Install handler at program start
__attribute__((constructor))
static void install_segv_handler(void) {
    struct sigaction sa = {0};
    sa.sa_handler = segv_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    sigaction(SIGSEGV, &sa, NULL);
}

static void *aligned_malloc(size_t size, size_t align) {
    void *ptr = NULL;
    if (posix_memalign(&ptr, align, size) != 0) return NULL;
    return ptr;
}

/* reference DFT in double precision, results returned as single precision */
static void reference_dft(const float *in, float *out, size_t N, int sign) {
    const double theta = 2.0 * M_PI * (double)sign / (double)N;
    for (size_t k = 0; k < N; k++) {
        double real_sum = 0.0;
        double imag_sum = 0.0;
        for (size_t n = 0; n < N; n++) {
            double in_r = (double)in[2*n];
            double in_i = (double)in[2*n + 1];
            double angle = theta * (double)((k * n) % N);
            double c = cos(angle);
            double s = sin(angle);
            /* (in_r + j in_i) * (c + j s)  with  sign = -1 => e^{-jθ} */
            double prod_r =  in_r * c - in_i * s;
            double prod_i =  in_r * s + in_i * c;
            real_sum += prod_r;
            imag_sum += prod_i;
        }
        out[2*k]     = (float)real_sum;
        out[2*k + 1] = (float)imag_sum;
    }
}

static int cmp_arrays(const float *a, const float *b, size_t n, float tol) {
    float max_err = 0.0f, rms = 0.0f;
    for (size_t i = 0; i < 2*n; i++) {
        float diff = fabsf(a[i] - b[i]);
        rms += diff * diff;
        if (diff > max_err) max_err = diff;
    }
    rms = sqrtf(rms / (2*n));
    if (max_err > tol) {
        fprintf(stderr, "Validation failed: max_err=%g, rms=%g\n", max_err, rms);
        return 0;
    }
    return 1;
}

static int run_case(size_t N, int sign) {
    g_current_N = N;
    g_current_sign = sign;
    printf("Testing N=%zu sign=%d ... ", N, sign);

#ifndef __aarch64__
    printf("skipped (non-AArch64)\n");
    return 1;
#else
    size_t bytes = 2 * N * sizeof(float);
    float *in  = (float*)aligned_malloc(bytes, 16);
    float *ref = (float*)aligned_malloc(bytes, 16);
    float *out = (float*)aligned_malloc(bytes, 16);
    if (!in || !ref || !out) {
        fprintf(stderr, "alloc failed\n");
        return 0;
    }

    /* deterministic pseudo-random data */
    srand(0x1234 + (unsigned)N + sign);
    for (size_t i = 0; i < 2*N; i++) in[i] = ((float)rand() / RAND_MAX) * 2.0f - 1.0f;

    reference_dft(in, ref, N, sign);

    ffts_plan_t *plan = ffts_init_1d(N, sign);
    assert(plan && "plan creation failed");

    ffts_execute(plan, in, out);
    ffts_free(plan);

    int ok = cmp_arrays(ref, out, N, TOLERANCE);
    printf(ok ? "OK\n" : "FAIL\n");

    free(in); free(ref); free(out);
    return ok;
#endif
}

int main(void) {
    const size_t sizes[] = {16, 32, 64, 128, 256};
    int all_ok = 1;
    for (size_t i = 0; i < sizeof(sizes)/sizeof(sizes[0]); i++) {
        size_t N = sizes[i];
        all_ok &= run_case(N, FFTS_FORWARD);
        all_ok &= run_case(N, FFTS_BACKWARD);
    }
    return all_ok ? 0 : 1;
}

#ifndef HAS_SINCOS
static inline void sincos(double x, double *s, double *c) {
    *s = sin(x);
    *c = cos(x);
}
#endif

#ifndef HAS_SINCOSF
static inline void sincosf(float x, float *s, float *c) {
    *s = sinf(x);
    *c = cosf(x);
}
#endif 