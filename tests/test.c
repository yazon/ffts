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

static void print_floats(const char *label, const float *ptr, size_t count)
{
    printf("%s:", label);
    for (size_t i = 0; i < count; ++i) {
        if (i % 8 == 0) printf("\n  ");
        printf("% .9E ", ptr[i]);
    }
    printf("\n");
}

static void dump_plan_ws_and_indices(ffts_plan_t *p, size_t ws_words)
{
    if (!p) return;
    const float *wsf = (const float*)p->ws;
    printf("N=%zu i0=%zu i1=%zu n_luts=%zu\n", p->N, p->i0, p->i1, p->n_luts);
    if (p->ws_is) {
        size_t limit = p->n_luts < 8 ? p->n_luts : 8;
        printf("ws_is[0..%zu):", limit);
        for (size_t i = 0; i < limit; ++i) printf(" %zu", p->ws_is[i]);
        printf("\n");
    }
    if (wsf) {
        size_t words = ws_words ? ws_words : 16; /* default two ld1 {v2,v3} */
        print_floats("p->ws[0..)", wsf, words);
    }
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

int main(int argc, char *argv[])
{
    print_ffts_plan_offsets(); // Print offsets at the start of main

    if (argc == 3 && strcmp(argv[1], "--dump-n8") == 0) {
        int sign = atoi(argv[2]);
        int n = 8;
#ifdef HAVE_SSE
        float FFTS_ALIGN(32) *input = _mm_malloc(2 * n * sizeof(float), 32);
        float FFTS_ALIGN(32) *output = _mm_malloc(2 * n * sizeof(float), 32);
#else
        float FFTS_ALIGN(32) *input;
        float FFTS_ALIGN(32) *output;
        if (posix_memalign((void **)&input , 16 , 2*n*sizeof(float)) != 0) {
            fprintf(stderr, "posix_memalign failed for input\n");
            return 1;
        }
        if (posix_memalign((void **)&output, 16 , 2*n*sizeof(float)) != 0) {
            fprintf(stderr, "posix_memalign failed for output\n");
            free(input);
            return 1;
        }
#endif
        for (int i = 0; i < 2*n; i++) { input[i] = 0.0f; output[i] = 0.0f; }
        input[2] = 1.0f; /* impulse at bin 1 (real) */

        ffts_plan_t *p = ffts_init_1d(n, sign);
        if (!p) {
            printf("Plan unsupported\n");
#ifdef HAVE_SSE
            _mm_free(input); _mm_free(output);
#else
            free(input); free(output);
#endif
            return 1;
        }

        dump_plan_ws_and_indices(p, 16);
        print_floats("input[0..15]", input, 16);

        ffts_execute(p, input, output);

        print_floats("output[0..15]", output, 16);
        printf("L2 Error: %10E\n", impulse_error(n, sign, output));

        ffts_free(p);
#ifdef HAVE_SSE
        _mm_free(input); _mm_free(output);
#else
        free(input); free(output);
#endif
        return 0;
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
