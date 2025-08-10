/*

 This file is part of FFTS.

 Copyright (c) 2012, Anthony M. Blake
 All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 	* Redistributions of source code must retain the above copyright
 		notice, this list of conditions and the following disclaimer.
 	* Redistributions in binary form must reproduce the above copyright
 		notice, this list of conditions and the following disclaimer in the
 		documentation and/or other materials provided with the distribution.
 	* Neither the name of the organization nor the
	  names of its contributors may be used to endorse or promote products
 		derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL ANTHONY M. BLAKE BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/

#define _POSIX_C_SOURCE 200112L  /* For posix_memalign */
#include "../include/ffts.h"
#include "../src/ffts_attributes.h"
#include "../src/ffts_internal.h"

#include <stddef.h> // Required for offsetof

#ifdef __ARM_NEON__
#endif

#ifdef HAVE_SSE
#include <xmmintrin.h>
#endif

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <inttypes.h>

#ifndef M_PI
#define M_PI 3.1415926535897932384626433832795028841971693993751058209
#endif

static float impulse_error(int N, int sign, float *data)
{
#ifdef __ANDROID__
    double delta_sum = 0.0f;
    double sum = 0.0f;
#else
    long double delta_sum = 0.0f;
    long double sum = 0.0f;
#endif
    int i;

    for (i = 0; i < N; i++) {
#ifdef __ANDROID__
        double re, im;

        if (sign < 0) {
            re = cos(2 * M_PI * (double) i / (double) N);
            im = -sin(2 * M_PI * (double) i / (double) N);
        } else {
            re = cos(2 * M_PI * (double) i / (double) N);
            im = sin(2 * M_PI * (double) i / (double) N);
        }
#else
        long double re, im;

        if (sign < 0) {
            re = cosl(2 * M_PI * (long double) i / (long double) N);
            im = -sinl(2 * M_PI * (long double) i / (long double) N);
        } else {
            re = cosl(2 * M_PI * (long double) i / (long double) N);
            im = sinl(2 * M_PI * (long double) i / (long double) N);
        }
#endif

        sum += re * re + im * im;

        re = re - data[2*i];
        im = im - data[2*i+1];

        delta_sum += re * re + im * im;
    }

#ifdef __ANDROID__
    return (float) (sqrt(delta_sum) / sqrt(sum));
#else
    return (float) (sqrtl(delta_sum) / sqrtl(sum));
#endif
}

void print_ffts_plan_offsets(void)
{
    printf("Offset of offsets: %zu\n", offsetof(struct _ffts_plan_t, offsets));
    printf("Offset of oe_ws: %zu\n", offsetof(struct _ffts_plan_t, oe_ws));
    printf("Offset of eo_ws: %zu\n", offsetof(struct _ffts_plan_t, eo_ws));
    printf("Offset of ee_ws: %zu\n", offsetof(struct _ffts_plan_t, ee_ws));
    printf("Offset of is: %zu\n", offsetof(struct _ffts_plan_t, is));
    printf("Offset of ws_is: %zu\n", offsetof(struct _ffts_plan_t, ws_is));
    printf("Offset of i0: %zu\n", offsetof(struct _ffts_plan_t, i0));
    printf("Offset of i1: %zu\n", offsetof(struct _ffts_plan_t, i1));
    printf("Offset of n_luts: %zu\n", offsetof(struct _ffts_plan_t, n_luts));
    printf("Offset of N: %zu\n", offsetof(struct _ffts_plan_t, N));
    printf("Offset of lastlut: %zu\n", offsetof(struct _ffts_plan_t, lastlut));
#ifdef __arm__
    printf("Offset of temporary_fix_as_dynamic_code_assumes_fixed_offset: %zu\n", offsetof(struct _ffts_plan_t, temporary_fix_as_dynamic_code_assumes_fixed_offset));
#endif
    printf("Offset of transform: %zu\n", offsetof(struct _ffts_plan_t, transform));
    printf("Offset of transform_base: %zu\n", offsetof(struct _ffts_plan_t, transform_base));
    printf("Offset of transform_size: %zu\n", offsetof(struct _ffts_plan_t, transform_size));
    printf("Offset of constants: %zu\n", offsetof(struct _ffts_plan_t, constants));
    printf("Offset of plans: %zu\n", offsetof(struct _ffts_plan_t, plans));
    printf("Offset of rank: %zu\n", offsetof(struct _ffts_plan_t, rank));
    printf("Offset of Ns: %zu\n", offsetof(struct _ffts_plan_t, Ns));
    printf("Offset of Ms: %zu\n", offsetof(struct _ffts_plan_t, Ms));
    printf("Offset of buf: %zu\n", offsetof(struct _ffts_plan_t, buf));
    printf("Offset of transpose_buf: %zu\n", offsetof(struct _ffts_plan_t, transpose_buf));
    printf("Offset of destroy: %zu\n", offsetof(struct _ffts_plan_t, destroy));
    printf("Offset of A: %zu\n", offsetof(struct _ffts_plan_t, A));
    printf("Offset of B: %zu\n", offsetof(struct _ffts_plan_t, B));
    printf("Offset of i2: %zu\n", offsetof(struct _ffts_plan_t, i2));
}

int test_transform(int n, int sign)
{
    ffts_plan_t *p;

#ifdef HAVE_SSE
    float FFTS_ALIGN(32) *input = _mm_malloc(2 * n * sizeof(float), 32);
    float FFTS_ALIGN(32) *output = _mm_malloc(2 * n * sizeof(float), 32);
#else
    float FFTS_ALIGN(32) *input;
    float FFTS_ALIGN(32) *output;
    if (posix_memalign((void **)&input , 16 , 2*n*sizeof(float)) != 0) {
        fprintf(stderr, "posix_memalign failed for input\n");
        return 0;
    }
    if (posix_memalign((void **)&output, 16 , 2*n*sizeof(float)) != 0) {
        fprintf(stderr, "posix_memalign failed for output\n");
        free(input);
        return 0;
    }
#endif
    int i;

    for (i = 0; i < n; i++) {
        input[2*i + 0] = 0.0f;
        input[2*i + 1] = 0.0f;
    }

    input[2] = 1.0f;

    p = ffts_init_1d(n, sign);
    if (!p) {
        printf("Plan unsupported\n");
        return 0;
    }

    ffts_execute(p, input, output);
    printf(" %3d  | %9d | %10E\n", sign, n, impulse_error(n, sign, output));
    ffts_free(p);
    return 1;
}

#if defined(__aarch64__)
extern void neon64_x8(void *data_base, size_t stride_bytes, void *ws_base);
#elif defined(__arm__)
extern void neon_x8(void *data_base, size_t stride_bytes, void *ws_base);
#endif

// Minimal helper to print a float vector
static void print_floats(const char *label, const float *f, size_t count)
{
    printf("%s:", label);
    for (size_t i = 0; i < count; ++i) {
        if ((i % 8) == 0) printf("\n  ");
        printf(" % .8f", f[i]);
    }
    printf("\n");
}

// Dump first K floats from ws at stage s (stage_idx), for dynamic JIT plans (N >= 32)
static int dump_ws_stage(size_t N, int sign, size_t stage_idx, size_t first_floats)
{
    if (N < 32) {
        fprintf(stderr, "dump-ws requires N >= 32 (dynamic path)\n");
        return 1;
    }
    ffts_plan_t *p = ffts_init_1d(N, sign);
    if (!p) {
        fprintf(stderr, "Plan unsupported\n");
        return 1;
    }
    if (!p->ws || !p->ws_is || p->n_luts == 0) {
        fprintf(stderr, "No ws/ws_is available (unexpected)\n");
        ffts_free(p);
        return 1;
    }
    if (stage_idx >= p->n_luts) {
        fprintf(stderr, "stage_idx out of range: %zu (n_luts=%zu)\n", stage_idx, (size_t)p->n_luts);
        ffts_free(p);
        return 1;
    }
    size_t ws_byte_off = 8 * p->ws_is[stage_idx]; // bytes
    const float *wsf = (const float *)((const uint8_t*)p->ws + ws_byte_off);

    printf("WS stage %zu (byte_off=%zu) first %zu floats\n", stage_idx, ws_byte_off, first_floats);
    size_t count = first_floats;
    print_floats("ws", wsf, count);

    ffts_free(p);
    return 0;
}

// Build a synthetic base-case input across 8 streams for a single iteration (stride_bytes must be multiple of 32)
// Layout: stream s base at data + s*stride_bytes; each stream holds 8 floats (4 complex) for a single iteration
static void init_basecase8_input(float *base, size_t stride_bytes)
{
    for (int s = 0; s < 8; ++s) {
        float *stream = (float *)((uint8_t*)base + (size_t)s * stride_bytes);
        for (int lane = 0; lane < 4; ++lane) {
            // 4 complex numbers → 8 floats per stream per iteration
            // re, im pattern per complex index
            int idx = lane * 2;
            float val = (float)(s * 10 + lane);
            stream[idx + 0] = val;     // re
            stream[idx + 1] = -val;    // im
        }
    }
}

static void init_basecase8_ws(float *ws /*at least 16 floats*/, int sign)
{
    // Two ld1 of {v2.4s, v3.4s} per iteration → 16 floats
    // Use simple twiddle set (re in first 4, im in next 4), repeated twice.
    // If sign > 0 we flip imaginary signs to emulate conjugate, otherwise keep as-is.
    for (int block = 0; block < 2; ++block) {
        float *re = ws + block * 8;
        float *im = ws + block * 8 + 4;
        for (int i = 0; i < 4; ++i) {
            re[i] = (float)(1.0 + 0.1 * i);
            float imag = (float)(0.5 + 0.05 * i);
            im[i] = (sign < 0) ? imag : -imag; // mimic forward/inverse sign convention on imag
        }
    }
}

// Execute the raw x8 base-case once and print outputs for each stream's first 8 floats
static int run_basecase8_once(int sign, size_t stride_bytes)
{
    if ((stride_bytes % 32) != 0) {
        fprintf(stderr, "stride_bytes must be a multiple of 32 (got %zu)\n", stride_bytes);
        return 1;
    }

    size_t buf_bytes = 8 * stride_bytes; // 8 streams
#ifdef HAVE_SSE
    float *buf = _mm_malloc(buf_bytes, 32);
#else
    float *buf;
    if (posix_memalign((void **)&buf, 32, buf_bytes) != 0) {
        fprintf(stderr, "posix_memalign failed for buf\n");
        return 1;
    }
#endif
    memset(buf, 0, buf_bytes);
    init_basecase8_input(buf, stride_bytes);

    float ws[16];
    init_basecase8_ws(ws, sign);

    printf("[base8] sign=%d stride_bytes=%zu\n", sign, stride_bytes);
    print_floats("ws(0..15)", ws, 16);

#if defined(__aarch64__)
    neon64_x8((void*)buf, stride_bytes, (void*)ws);
#elif defined(__arm__)
    neon_x8((void*)buf, stride_bytes, (void*)ws);
#else
    fprintf(stderr, "This mode is only available on ARM32/ARM64 builds\n");
#ifdef HAVE_SSE
    _mm_free(buf);
#else
    free(buf);
#endif
    return 1;
#endif

    for (int s = 0; s < 8; ++s) {
        float *stream = (float *)((uint8_t*)buf + (size_t)s * stride_bytes);
        char lab[64];
        snprintf(lab, sizeof(lab), "out stream[%d] first8", s);
        print_floats(lab, stream, 8);
    }

#ifdef HAVE_SSE
    _mm_free(buf);
#else
    free(buf);
#endif
    return 0;
}

int main(int argc, char *argv[])
{
    print_ffts_plan_offsets(); // Print offsets at the start of main

    if (argc == 5 && strcmp(argv[1], "--dump-ws") == 0) {
        size_t n = (size_t) strtoull(argv[2], NULL, 10);
        int sign = atoi(argv[3]);
        size_t stage_idx = (size_t) strtoull(argv[4], NULL, 10);
        return dump_ws_stage(n, sign, stage_idx, 16);
    }

    if (argc == 4 && strcmp(argv[1], "--base8") == 0) {
        size_t stride_floats = (size_t) strtoull(argv[2], NULL, 10);
        int sign = atoi(argv[3]);
        size_t stride_bytes = stride_floats * sizeof(float);
        return run_basecase8_once(sign, stride_bytes);
    }

    if (argc == 4 && strcmp(argv[1], "--l2") == 0) {
        int n = atoi(argv[2]);
        int sign = atoi(argv[3]);

#ifdef HAVE_SSE
        float FFTS_ALIGN(32) *input = _mm_malloc(2 * n * sizeof(float), 32);
        float FFTS_ALIGN(32) *output = _mm_malloc(2 * n * sizeof(float), 32);
#else
        float FFTS_ALIGN(32) *input;
        float FFTS_ALIGN(32) *output;
        if (posix_memalign((void **)&input , 16 , 2*n*sizeof(float)) != 0) {
            fprintf(stderr, "posix_memalign failed for input\n");
            return 0;
        }
        if (posix_memalign((void **)&output, 16 , 2*n*sizeof(float)) != 0) {
            fprintf(stderr, "posix_memalign failed for output\n");
            free(input);
            return 0;
        }
#endif

        /* Zero input/output and set impulse */
        for (int i = 0; i < 2*n; i++) {
            input[i] = 0.0f;
            output[i] = 0.0f;
        }
        input[2] = 1.0f;

        ffts_plan_t *p = ffts_init_1d(n, sign);
        if (!p) {
            printf("Plan unsupported\n");
            return 0;
        }
        ffts_execute(p, input, output);
        printf(" %3d  | %9d | %10E\n", sign, n, impulse_error(n, sign, output));
        ffts_free(p);

#ifdef HAVE_SSE
        _mm_free(input);
        _mm_free(output);
#else
        free(input);
        free(output);
#endif
        return 0;
    }

    if (argc == 4 && strcmp(argv[1], "--l2-inplace") == 0) {
        int n = atoi(argv[2]);
        int sign = atoi(argv[3]);

#ifdef HAVE_SSE
        float FFTS_ALIGN(32) *buffer = _mm_malloc(2 * n * sizeof(float), 32);
#else
        float FFTS_ALIGN(32) *buffer;
        if (posix_memalign((void **)&buffer , 16 , 2*n*sizeof(float)) != 0) {
            fprintf(stderr, "posix_memalign failed for buffer\n");
            return 0;
        }
#endif

        for (int i = 0; i < 2*n; i++) buffer[i] = 0.0f;
        buffer[2] = 1.0f;

        ffts_plan_t *p = ffts_init_1d(n, sign);
        if (!p) {
            printf("Plan unsupported\n");
            return 0;
        }
        ffts_execute(p, buffer, buffer);
        printf(" %3d  | %9d | %10E\n", sign, n, impulse_error(n, sign, buffer));
        ffts_free(p);

#ifdef HAVE_SSE
        _mm_free(buffer);
#else
        free(buffer);
#endif
        return 0;
    }

    if (argc == 3) {
        ffts_plan_t *p;
        int i;

        /* test specific transform with test pattern and display output */
        int n = atoi(argv[1]);
        int sign = atoi(argv[2]);

#ifdef HAVE_SSE
        float FFTS_ALIGN(32) *input = _mm_malloc(2 * n * sizeof(float), 32);
        float FFTS_ALIGN(32) *output = _mm_malloc(2 * n * sizeof(float), 32);
#else
        float FFTS_ALIGN(32) *input;
        float FFTS_ALIGN(32) *output;
        if (posix_memalign((void **)&input , 16 , 2*n*sizeof(float)) != 0) {
            fprintf(stderr, "posix_memalign failed for input\n");
            return 0;
        }
        if (posix_memalign((void **)&output, 16 , 2*n*sizeof(float)) != 0) {
            fprintf(stderr, "posix_memalign failed for output\n");
            free(input);
            return 0;
        }
#endif

        for (i = 0; i < n; i++) {
            input[2*i + 0] = (float) i;
            input[2*i + 1] = 0.0f;
        }

        /* input[2] = 1.0f; */

        p = ffts_init_1d(n, sign);
        if (!p) {
            printf("Plan unsupported\n");
            return 0;
        }

        ffts_execute(p, input, output);

        for (i = 0; i < n; i++)
            printf("%d %d %f %f\n", i, sign, output[2*i], output[2*i+1]);
        ffts_free(p);

#ifdef HAVE_SSE
        _mm_free(input);
        _mm_free(output);
#else
        free(input);
        free(output);
#endif
    } else {
        int n, power2;

        /* test various sizes and display error */
        printf(" Sign |      Size |     L2 Error\n");
        printf("------+-----------+-------------\n");

        for (n = 1, power2 = 2; n <= 18; n++, power2 <<= 1) {
            test_transform(power2, -1);
        }

        for (n = 1, power2 = 2; n <= 18; n++, power2 <<= 1) {
            test_transform(power2, 1);
        }
    }

    return 0;
}
