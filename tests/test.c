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
#include <stdint.h>

#ifdef __ARM_NEON__
#endif

#ifdef HAVE_SSE
#include <xmmintrin.h>
#endif

#ifdef __aarch64__
extern volatile uint32_t ffts_arm64_debug_stores_enabled;
extern volatile uint8_t *ffts_arm64_debug_buf;
#else
extern volatile uint32_t ffts_arm_debug_stores_enabled;
extern volatile uint8_t *ffts_arm_debug_buf;
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
    return 0.0f;
}

static void dump_floats(const char *label, const float *buf, int count)
{
    printf("%s", label);
    for (int i = 0; i < count; i++) {
        if ((i % 8) == 0) printf("\n  [%02d..]: ", i);
        printf("% .9e ", buf[i]);
    }
    printf("\n");
}

static void dump_u64_offsets(const char *label, const uint64_t *vals, int count)
{
    printf("%s", label);
    for (int i = 0; i < count; i++) {
        printf(" %llu", (unsigned long long)vals[i]);
    }
    printf("\n");
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
    printf("Freeing memory2!\n");
    ffts_free(p);
    printf("Memory freed2!\n");
    return 1;
}

int main(int argc, char *argv[])
{
    print_ffts_plan_offsets(); // Print offsets at the start of main

    if (argc == 3 && strcmp(argv[1], "--trace-n8") == 0) {
        int sign = atoi(argv[2]);
        int n = 8;

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

        for (int i = 0; i < 2*n; i++) { input[i] = 0.0f; output[i] = 0.0f; }
        input[2] = 1.0f; // impulse at index 1 (re)

        ffts_plan_t *p = ffts_init_1d(n, sign);
        if (!p) {
            printf("Plan unsupported\n");
            free(input); free(output);
            return 1;
        }

        printf("TRACE N=8 sign=%d\n", sign);
        printf("plan.N=%zu, i0=%zu, i1=%zu, n_luts=%zu\n", p->N, p->i0, p->i1, p->n_luts);
        printf("plan.ws=%p, plan.ws_is[0]=%zu\n", (void*)p->ws, (size_t)(p->ws_is ? p->ws_is[0] : 0));

        // Twiddle/LUT dump for first stage used by base-case (assume ws_is[0])
        if (p->ws && p->ws_is) {
            size_t ws_off_bytes = 8 * p->ws_is[0]; // matches ARM64 emitter
            const float *tw = (const float *)((const uint8_t*)p->ws + ws_off_bytes);
            dump_floats("twiddles[0..15] (from p->ws + ws_is[0]*8):", tw, 16);
        }

        // Stride assumptions
        size_t stride_arm32_bytes = (size_t)n << 2; // r1 = N, used with lsl #2 => N*4 bytes
        size_t stride_arm64_bytes = (size_t)n << 3; // x1 = N<<3 bytes per emitter
        printf("stride_arm32_bytes=%zu, stride_arm64_bytes=%zu\n", stride_arm32_bytes, stride_arm64_bytes);
        printf("loop_count_if_arm64_style = (stride>>5) = %zu\n", (stride_arm64_bytes >> 5));

        // Compute stream pointer byte offsets relative to base (x0/r0) for both styles
        uint64_t off32[8] = {0};
        uint64_t off64[8] = {0};
        // ARM32-style (from neon_x8):
        // r3=base, r4=base+N, r5=base+2N, r6=r5+N, r7=r5+2N, r8=r7+N, r9=r7+2N, r10=r9+N; all *4 bytes
        off32[0] = 0; // data0
        off32[1] = (uint64_t)stride_arm32_bytes; // data1
        off32[2] = (uint64_t)(2*stride_arm32_bytes); // data2
        off32[3] = (uint64_t)(3*stride_arm32_bytes); // data3
        off32[4] = (uint64_t)(4*stride_arm32_bytes); // data4
        off32[5] = (uint64_t)(5*stride_arm32_bytes); // data5
        off32[6] = (uint64_t)(6*stride_arm32_bytes); // data6
        off32[7] = (uint64_t)(7*stride_arm32_bytes); // data7

        // ARM64-style (from neon64_x8): x1 is bytes
        // x3=base, x4=base+x1, x5=base+2*x1, x6=x5+x1, x7=x5+2*x1, x8=x7+x1, x9=x7+2*x1, x10=x9+x1
        off64[0] = 0; // data0
        off64[1] = (uint64_t)stride_arm64_bytes; // data1
        off64[2] = (uint64_t)(2*stride_arm64_bytes); // data2
        off64[3] = (uint64_t)(3*stride_arm64_bytes); // data3
        off64[4] = (uint64_t)(4*stride_arm64_bytes); // data4
        off64[5] = (uint64_t)(5*stride_arm64_bytes); // data5
        off64[6] = (uint64_t)(6*stride_arm64_bytes); // data6
        off64[7] = (uint64_t)(7*stride_arm64_bytes); // data7

        dump_u64_offsets("ARM32-style stream byte offsets:", off32, 8);
        dump_u64_offsets("ARM64-style stream byte offsets:", off64, 8);

        dump_floats("input[0..15] (interleaved re,im):", input, 16);

        ffts_execute(p, input, output);

        dump_floats("output[0..15] (interleaved re,im):", output, 16);
        printf("L2 Error (N=8, sign=%d): % .9e\n", sign, impulse_error(n, sign, output));

        ffts_free(p);
        free(input);
        free(output);
        return 0;
    }

    if (argc == 2 && strcmp(argv[1], "--dump-leaf32") == 0) {
        const int n = 32;
        const int sign = -1;
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
        for (int i = 0; i < 2*n; i++) { input[i] = 0.0f; output[i] = 0.0f; }

        /* Enable debug leaf emission */
        setenv("FFTS_DEBUG_LEAF", "1", 1);
        ffts_plan_t *p = ffts_init_1d(n, sign);
        if (!p) {
            printf("Plan unsupported\n");
            free(input); free(output);
            return 1;
        }
        /* Ensure buf exists before executing */
        if (!p->buf) {
            p->buf = malloc(128);
            if (!p->buf) { fprintf(stderr, "failed to alloc debug buf\n"); return 1; }
        }
        /* Execute once to trigger debug stores and early return */
        ffts_execute(p, input, output);
        
        unsigned char *b = (unsigned char*)p->buf;
        uint64_t x3  = *(uint64_t*)(b + 0);
        uint64_t x4  = *(uint64_t*)(b + 8);
        uint64_t x5  = *(uint64_t*)(b + 16);
        uint64_t x6  = *(uint64_t*)(b + 24);
        uint64_t x7  = *(uint64_t*)(b + 32);
        uint64_t x8  = *(uint64_t*)(b + 40);
        uint64_t x9  = *(uint64_t*)(b + 48);
        uint64_t x10 = *(uint64_t*)(b + 56);
        uint64_t x12 = *(uint64_t*)(b + 64);
        uint32_t off0 = *(uint32_t*)(b + 72);
        uint32_t off1 = *(uint32_t*)(b + 76);
        printf("LEAF32-DUMP\n");
        printf("x3..x10: %llu %llu %llu %llu %llu %llu %llu %llu\n",
               (unsigned long long)x3,(unsigned long long)x4,(unsigned long long)x5,(unsigned long long)x6,
               (unsigned long long)x7,(unsigned long long)x8,(unsigned long long)x9,(unsigned long long)x10);
        printf("x12=%llu off0=%u off1=%u\n",
               (unsigned long long)x12, off0, off1);
        ffts_free(p);
        free(input);
        free(output);
        return 0;
    }

    if (argc == 2 && strcmp(argv[1], "--dump-stagews-32") == 0) {
        const int n = 32;
        const int sign = -1;
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
        for (int i = 0; i < 2*n; i++) { input[i] = 0.0f; output[i] = 0.0f; }

        setenv("FFTS_DEBUG_STAGE_WS", "1", 1);
        ffts_plan_t *p = ffts_init_1d(n, sign);
        if (!p) {
            printf("Plan unsupported\n");
            free(input); free(output);
            return 1;
        }
        if (!p->buf) {
            p->buf = malloc(128);
            if (!p->buf) { fprintf(stderr, "failed to alloc debug buf\n"); return 1; }
            memset(p->buf, 0, 128);
        }
        ffts_execute(p, input, output);
        unsigned char *b = (unsigned char*)p->buf;
        uint64_t stage_ws0 = *(uint64_t*)(b + 80);
        uint64_t stage_ws1 = *(uint64_t*)(b + 96);
        printf("STAGEWS32-DUMP\n");
        printf("plan.ws=%p stage_ws0=%llu stage_ws1=%llu\n", (void*)p->ws, (unsigned long long)stage_ws0, (unsigned long long)stage_ws1);
        ffts_free(p);
        free(input);
        free(output);
        return 0;
    }

    if (argc == 4 && strcmp(argv[1], "--dump-plan") == 0) {
        int n = atoi(argv[2]);
        int sign = atoi(argv[3]);

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
        for (int i = 0; i < 2*n; i++) { input[i] = 0.0f; output[i] = 0.0f; }

        ffts_plan_t *p = ffts_init_1d(n, sign);
        if (!p) {
            printf("Plan unsupported\n");
            free(input); free(output);
            return 1;
        }

        printf("DUMP PLAN N=%d sign=%d\n", n, sign);
        printf("plan.N=%zu i0=%zu i1=%zu n_luts=%zu\n", p->N, p->i0, p->i1, p->n_luts);
        printf("plan.ws=%p plan.offsets=%p\n", (void*)p->ws, (void*)p->offsets);

        if (p->ws_is && p->n_luts > 0) {
            size_t to_print = p->n_luts < 8 ? p->n_luts : 8;
            printf("ws_is[0..%zu):", to_print);
            for (size_t i = 0; i < to_print; i++) printf(" %zu", p->ws_is[i]);
            printf("\n");
            printf("ws_is_bytes (8x)[0..%zu):", to_print);
            for (size_t i = 0; i < to_print; i++) printf(" %zu", (size_t)(8 * p->ws_is[i]));
            printf("\n");
        } else {
            printf("ws_is: (none)\n");
        }

        if (p->offsets) {
            /* In FFTS, plan->offsets has length N/leaf_N and stores only off2 values (2*output offset),
               sorted by output offset. Print the first up to 16 entries. */
            int count = (int)(p->N / 8);
            int to_print = count < 16 ? count : 16;
            printf("offset off2 (first up to %d):\n", to_print);
            for (int i = 0; i < to_print; i++) {
                printf("  [%02d] off2=%td\n", i, p->offsets[i]);
            }
        }

        ffts_free(p);
        free(input);
        free(output);
        return 0;
    }

    if (argc == 2 && strcmp(argv[1], "--dump-plan-32") == 0) {
        int n = 32, sign = -1;
        float FFTS_ALIGN(32) *input, *output;
        if (posix_memalign((void **)&input , 16 , 2*n*sizeof(float)) != 0) return 1;
        if (posix_memalign((void **)&output, 16 , 2*n*sizeof(float)) != 0) { free(input); return 1; }
        ffts_plan_t *p = ffts_init_1d(n, sign);
        if (!p) { printf("Plan unsupported\n"); return 1; }
        printf("DUMP PLAN N=32 sign=-1\n");
        printf("plan.N=%zu i0=%zu i1=%zu n_luts=%zu\n", p->N, p->i0, p->i1, p->n_luts);
        printf("plan.ws=%p plan.offsets=%p\n", (void*)p->ws, (void*)p->offsets);
        if (p->ws_is && p->n_luts > 0) {
            size_t to_print = p->n_luts < 8 ? p->n_luts : 8;
            printf("ws_is[0..%zu):", to_print);
            for (size_t i = 0; i < to_print; i++) printf(" %zu", p->ws_is[i]);
            printf("\n");
            printf("ws_is_bytes (8x)[0..%zu):", to_print);
            for (size_t i = 0; i < to_print; i++) printf(" %zu", (size_t)(8 * p->ws_is[i]));
            printf("\n");
        } else {
            printf("ws_is: (none)\n");
        }
        if (p->offsets) {
            int count = (int)(p->N / 8);
            int to_print = count < 16 ? count : 16;
            printf("offset off2 (first up to %d):\n", to_print);
            for (int i = 0; i < to_print; i++) {
                printf("  [%02d] off2=%td\n", i, p->offsets[i]);
            }
        }
        ffts_free(p); free(input); free(output);
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
        printf("Freeing memory3!\n");
        ffts_free(p);
        printf("Memory freed3!\n");

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
        printf("Freeing memory1!\n");
        ffts_free(p);
        printf("Memory freed1!\n");

#ifdef HAVE_SSE
        _mm_free(buffer);
#else
        free(buffer);
#endif
        return 0;
    }

    if (argc == 2 && strcmp(argv[1], "--dump-pre-oe32") == 0) {
        const int n = 32;
        const int sign = -1;
        float FFTS_ALIGN(32) *input;
        float FFTS_ALIGN(32) *output;
        if (posix_memalign((void **)&input , 16 , 2*n*sizeof(float)) != 0) return 1;
        if (posix_memalign((void **)&output, 16 , 2*n*sizeof(float)) != 0) { free(input); return 1; }
        for (int i = 0; i < 2*n; i++) { input[i] = 0.0f; output[i] = 0.0f; }
        setenv("FFTS_DUMP_PRE_OE", "1", 1);
        ffts_plan_t *p = ffts_init_1d(n, sign);
        if (!p) { printf("Plan unsupported\n"); return 1; }
        if (!p->buf) { p->buf = malloc(128); if (!p->buf) return 1; memset(p->buf, 0, 128); }
        ffts_execute(p, input, output);
        unsigned char *b = (unsigned char*)p->buf;
        uint64_t r0 = *(uint64_t*)(b + 0);
        uint64_t r22 = *(uint64_t*)(b + 8);
        uint64_t r2 = *(uint64_t*)(b + 16);
        uint64_t r11 = *(uint64_t*)(b + 24);
        uint64_t r12 = *(uint64_t*)(b + 32);
        printf("PRE-OE32\n");
        printf("x0=%llu x22=%llu x2=%llu x11=%llu x12=%llu\n",
               (unsigned long long)r0,(unsigned long long)r22,(unsigned long long)r2,
               (unsigned long long)r11,(unsigned long long)r12);
        ffts_free(p); free(input); free(output);
        return 0;
    }

    if (argc == 2 && strcmp(argv[1], "--dump-pre-edges-32") == 0) {
        const int n = 32;
        const int sign = -1;
        float FFTS_ALIGN(32) *input;
        float FFTS_ALIGN(32) *output;
        if (posix_memalign((void **)&input , 16 , 2*n*sizeof(float)) != 0) return 1;
        if (posix_memalign((void **)&output, 16 , 2*n*sizeof(float)) != 0) { free(input); return 1; }
        for (int i = 0; i < 2*n; i++) { input[i] = 0.0f; output[i] = 0.0f; }
        setenv("FFTS_DUMP_PRE_EDGES", "1", 1);
        ffts_plan_t *p = ffts_init_1d(n, sign);
        if (!p) { printf("Plan unsupported\n"); return 1; }
        if (!p->buf) { p->buf = malloc(128); if (!p->buf) return 1; memset(p->buf, 0, 128); }
        ffts_execute(p, input, output);
        unsigned char *b = (unsigned char*)p->buf;
        /* Slot A: before ee at buf+0 */
        uint64_t a_x0  = *(uint64_t*)(b + 0);
        uint64_t a_x22 = *(uint64_t*)(b + 8);
        uint64_t a_x2  = *(uint64_t*)(b + 16);
        uint64_t a_x11 = *(uint64_t*)(b + 24);
        uint64_t a_x12 = *(uint64_t*)(b + 32);
        /* Slot B: before oe at buf+40 */
        uint64_t b_x0  = *(uint64_t*)(b + 40);
        uint64_t b_x22 = *(uint64_t*)(b + 48);
        uint64_t b_x2  = *(uint64_t*)(b + 56);
        uint64_t b_x11 = *(uint64_t*)(b + 64);
        uint64_t b_x12 = *(uint64_t*)(b + 72);
        printf("PRE-EDGES32\n");
        printf("A(before ee):  x0=%llu x22=%llu x2=%llu x11=%llu x12=%llu\n",
               (unsigned long long)a_x0,(unsigned long long)a_x22,(unsigned long long)a_x2,
               (unsigned long long)a_x11,(unsigned long long)a_x12);
        printf("B(before oe):  x0=%llu x22=%llu x2=%llu x11=%llu x12=%llu\n",
               (unsigned long long)b_x0,(unsigned long long)b_x22,(unsigned long long)b_x2,
               (unsigned long long)b_x11,(unsigned long long)b_x12);
        ffts_free(p); free(input); free(output);
        return 0;
    }

    if (argc == 2 && strcmp(argv[1], "--dump-after-ee-32") == 0) {
        const int n = 32;
        const int sign = -1;
        float FFTS_ALIGN(32) *input;
        float FFTS_ALIGN(32) *output;
        if (posix_memalign((void **)&input , 16 , 2*n*sizeof(float)) != 0) return 1;
        if (posix_memalign((void **)&output, 16 , 2*n*sizeof(float)) != 0) { free(input); return 1; }
        for (int i = 0; i < 2*n; i++) { input[i] = 0.0f; output[i] = 0.0f; }
        setenv("FFTS_SNAP_AFTER_EE", "1", 1);
        ffts_plan_t *p = ffts_init_1d(n, sign);
        if (!p) { printf("Plan unsupported\n"); return 1; }
        if (!p->buf) { p->buf = malloc(128); if (!p->buf) return 1; memset(p->buf, 0, 128); }
        ffts_execute(p, input, output);
        unsigned char *b = (unsigned char*)p->buf;
        uint64_t s_x0  = *(uint64_t*)(b + 80);
        uint64_t s_x22 = *(uint64_t*)(b + 88);
        uint64_t s_x2  = *(uint64_t*)(b + 96);
        uint64_t s_x11 = *(uint64_t*)(b + 104);
        uint64_t s_x12 = *(uint64_t*)(b + 112);
        uint64_t m_entry = *(uint64_t*)(b + 0);
        uint64_t m_exit  = *(uint64_t*)(b + 8);
        uint64_t m_mid1  = *(uint64_t*)(b + 16);
        uint64_t m_mid2  = *(uint64_t*)(b + 24);
        uint64_t addr1   = *(uint64_t*)(b + 32);
        uint64_t addr2   = *(uint64_t*)(b + 40);
        uint32_t off0    = *(uint32_t*)(b + 64);
        uint32_t off1    = *(uint32_t*)(b + 68);
        uint64_t inner_x12 = *(uint64_t*)(b + 72);
        uint64_t inner_x0  = *(uint64_t*)(b + 80);
        uint64_t inner_x2  = *(uint64_t*)(b + 88);
        uint32_t peek0     = *(uint32_t*)(b + 112);
        uint32_t peek1     = *(uint32_t*)(b + 116);
        printf("AFTER-EE32\n");
        printf("S(after ee): x0=%llu x22=%llu x2=%llu x11=%llu x12=%llu\n",
               (unsigned long long)s_x0,(unsigned long long)s_x22,(unsigned long long)s_x2,
               (unsigned long long)s_x11,(unsigned long long)s_x12);
        printf("EE markers: entry=%#llx mid1=%#llx mid2=%#llx exit=%#llx\n",
               (unsigned long long)m_entry,(unsigned long long)m_mid1,(unsigned long long)m_mid2,
               (unsigned long long)m_exit);
        printf("EE addrs: addr1=%#llx addr2=%#llx off0=%u off1=%u\n",
               (unsigned long long)addr1, (unsigned long long)addr2,
               (unsigned)off0, (unsigned)off1);
        printf("EE inner: x12=%#llx x0=%#llx x2=%#llx peek0=%u peek1=%u\n",
               (unsigned long long)inner_x12, (unsigned long long)inner_x0,
               (unsigned long long)inner_x2, (unsigned)peek0, (unsigned)peek1);
        ffts_free(p); free(input); free(output);
        return 0;
    }

    if (argc == 2 && strcmp(argv[1], "--snap-stores-32") == 0) {
        const int n = 32;
        const int sign = -1;
        float FFTS_ALIGN(32) *input;
        float FFTS_ALIGN(32) *output;
        if (posix_memalign((void **)&input , 16 , 2*n*sizeof(float)) != 0) return 1;
        if (posix_memalign((void **)&output, 16 , 2*n*sizeof(float)) != 0) { free(input); return 1; }
        for (int i = 0; i < 2*n; i++) { input[i] = 0.0f; output[i] = 0.0f; }
        input[2] = 1.0f;
#ifdef __aarch64__
        /* Ensure codegen returns immediately after ee leaf to avoid crash paths */
        setenv("FFTS_RET_AFTER_EE", "1", 1);
        unsetenv("FFTS_RET_BEFORE_EE");
        unsetenv("FFTS_RET_BEFORE_OE");
#endif
        ffts_plan_t *p = ffts_init_1d(n, sign);
        if (!p) { printf("Plan unsupported\n"); free(input); free(output); return 1; }
        if (!p->buf) { p->buf = malloc(256); if (!p->buf) { ffts_free(p); free(input); free(output); return 1; } memset(p->buf, 0, 256); }
        /* Enable ARM64 snapshots if available (harmless on ARM32) */
#ifdef __aarch64__
        ffts_arm64_debug_stores_enabled = 1;
        ffts_arm64_debug_buf = (uint8_t*)p->buf;
#else
        ffts_arm_debug_stores_enabled = 1;
        ffts_arm_debug_buf = (uint8_t*)p->buf;
#endif
        ffts_execute(p, input, output);
        /* Read four interleaved 8-float pairs from output using plan->offsets[0..1] */
        printf("SNAP-STORES32\n");
        if (p->offsets) {
            int off0 = (int)p->offsets[0]; /* off2 in floats */
            int off1 = (int)p->offsets[1];
            float *base = output;
            dump_floats("pair0 (out+off0):", base + off0, 8);
            dump_floats("pair1 (out+off0+8):", base + off0 + 8, 8);
            dump_floats("pair2 (out+off1):", base + off1, 8);
            dump_floats("pair3 (out+off1+8):", base + off1 + 8, 8);
        } else {
            /* Fallback: first 32 floats */
            dump_floats("pair0 (out+0):", output + 0, 8);
            dump_floats("pair1 (out+8):", output + 8, 8);
            dump_floats("pair2 (out+16):", output + 16, 8);
            dump_floats("pair3 (out+24):", output + 24, 8);
        }
        ffts_free(p);
        free(input);
        free(output);
        return 0;
    }

    if (argc == 2 && strcmp(argv[1], "--dump-post-reload-32") == 0) {
        const int n = 32;
        const int sign = -1;
        float FFTS_ALIGN(32) *input;
        float FFTS_ALIGN(32) *output;
        if (posix_memalign((void **)&input , 16 , 2*n*sizeof(float)) != 0) return 1;
        if (posix_memalign((void **)&output, 16 , 2*n*sizeof(float)) != 0) { free(input); return 1; }
        for (int i = 0; i < 2*n; i++) { input[i] = 0.0f; output[i] = 0.0f; }
        setenv("FFTS_RELOAD_AFTER_EE", "1", 1);
        setenv("FFTS_DUMP_POST_RELOAD", "1", 1);
        ffts_plan_t *p = ffts_init_1d(n, sign);
        if (!p) { printf("Plan unsupported\n"); return 1; }
        if (!p->buf) { p->buf = malloc(128); if (!p->buf) return 1; memset(p->buf, 0, 128); }
        ffts_execute(p, input, output);
        unsigned char *b = (unsigned char*)p->buf;
        uint64_t r_x0  = *(uint64_t*)(b + 40);
        uint64_t r_x22 = *(uint64_t*)(b + 48);
        uint64_t r_x2  = *(uint64_t*)(b + 56);
        uint64_t r_x11 = *(uint64_t*)(b + 64);
        uint64_t r_x12 = *(uint64_t*)(b + 72);
        printf("POST-RELOAD32\n");
        printf("R(post reload): x0=%llu x22=%llu x2=%llu x11=%llu x12=%llu\n",
               (unsigned long long)r_x0,(unsigned long long)r_x22,(unsigned long long)r_x2,
               (unsigned long long)r_x11,(unsigned long long)r_x12);
        ffts_free(p); free(input); free(output);
        return 0;
    }

    if (argc == 2 && strcmp(argv[1], "--mark-after-ee-32") == 0) {
        const int n = 32;
        const int sign = -1;
        float FFTS_ALIGN(32) *input;
        float FFTS_ALIGN(32) *output;
        if (posix_memalign((void **)&input , 16 , 2*n*sizeof(float)) != 0) return 1;
        if (posix_memalign((void **)&output, 16 , 2*n*sizeof(float)) != 0) { free(input); return 1; }
        for (int i = 0; i < 2*n; i++) { input[i] = 0.0f; output[i] = 0.0f; }
        setenv("FFTS_MARK_AFTER_EE", "1", 1);
        ffts_plan_t *p = ffts_init_1d(n, sign);
        if (!p) { printf("Plan unsupported\n"); return 1; }
        if (!p->buf) { p->buf = malloc(128); if (!p->buf) return 1; memset(p->buf, 0, 128); }
        ffts_execute(p, input, output);
        unsigned char *b = (unsigned char*)p->buf;
        unsigned long long marker = *(unsigned long long*)(b + 0);
        printf("MARK-AFTER-EE32\n");
        printf("marker=%#llx\n", marker);
        ffts_free(p); free(input); free(output);
        return 0;
    }

    if (argc == 2 && strcmp(argv[1], "--mark-before-ee-32") == 0) {
        const int n = 32;
        const int sign = -1;
        float FFTS_ALIGN(32) *input;
        float FFTS_ALIGN(32) *output;
        if (posix_memalign((void **)&input , 16 , 2*n*sizeof(float)) != 0) return 1;
        if (posix_memalign((void **)&output, 16 , 2*n*sizeof(float)) != 0) { free(input); return 1; }
        for (int i = 0; i < 2*n; i++) { input[i] = 0.0f; output[i] = 0.0f; }
        setenv("FFTS_MARK_BEFORE_EE", "1", 1);
        ffts_plan_t *p = ffts_init_1d(n, sign);
        if (!p) { printf("Plan unsupported\n"); return 1; }
        if (!p->buf) { p->buf = malloc(128); if (!p->buf) return 1; memset(p->buf, 0, 128); }
        ffts_execute(p, input, output);
        unsigned char *b = (unsigned char*)p->buf;
        unsigned long long marker = *(unsigned long long*)(b + 0);
        printf("MARK-BEFORE-EE32\n");
        printf("marker=%#llx\n", marker);
        ffts_free(p); free(input); free(output);
        return 0;
    }

    if (argc == 2 && strcmp(argv[1], "--probe-ee32") == 0) {
        const int n = 32;
        const int sign = -1;
        float FFTS_ALIGN(32) *input;
        float FFTS_ALIGN(32) *output;
        if (posix_memalign((void **)&input , 16 , 2*n*sizeof(float)) != 0) return 1;
        if (posix_memalign((void **)&output, 16 , 2*n*sizeof(float)) != 0) { free(input); return 1; }
        for (int i = 0; i < 2*n; i++) { input[i] = 0.0f; output[i] = 0.0f; }
        setenv("FFTS_DEBUG_BUF", "1", 1);
        ffts_plan_t *p = ffts_init_1d(n, sign);
        if (!p) { free(input); free(output); return 1; }
        // Optionally enable ee offsets enforcement if requested via env
        if (p->buf) {
            const char *enf = getenv("FFTS_ENFORCE_EE_X12");
            if (enf && *enf) {
                *(uint64_t*)((unsigned char*)p->buf + 120) = 1ULL;
            }
        }
        // Force return before oe so we can inspect ee results
        setenv("FFTS_RET_BEFORE_OE", "1", 1);
        ffts_execute(p, input, output);
        if (p->buf) {
            unsigned char *b = (unsigned char*)p->buf;
            uint64_t entry = *(uint64_t*)(b + 0);
            uint64_t exitm = *(uint64_t*)(b + 8);
            uint64_t mid1  = *(uint64_t*)(b + 16);
            uint64_t pre   = *(uint64_t*)(b + 48);
            uint64_t addr1 = *(uint64_t*)(b + 32);
            uint64_t addr2 = *(uint64_t*)(b + 40);
            uint32_t off0  = *(uint32_t*)(b + 64);
            uint32_t off1  = *(uint32_t*)(b + 68);
            uint32_t peek0 = *(uint32_t*)(b + 112);
            uint32_t peek1 = *(uint32_t*)(b + 116);
            printf("EE-PROBE entry=%llu exit=%llu mid1=%llu pre=%llu off0=%u off1=%u peek0=%u peek1=%u\n",
                   (unsigned long long)entry,(unsigned long long)exitm,(unsigned long long)mid1,(unsigned long long)pre,
                   off0,off1,peek0,peek1);
            printf("EE-PROBE addr1=%llu addr2=%llu\n", (unsigned long long)addr1,(unsigned long long)addr2);
        }
        ffts_free(p);
        free(input);
        free(output);
        return 0;
    }

    if (argc == 2 && strcmp(argv[1], "--dump-ee-buf32") == 0) {
        const int n = 32;
        const int sign = -1;
        float FFTS_ALIGN(32) *input;
        float FFTS_ALIGN(32) *output;
        if (posix_memalign((void **)&input , 16 , 2*n*sizeof(float)) != 0) return 1;
        if (posix_memalign((void **)&output, 16 , 2*n*sizeof(float)) != 0) { free(input); return 1; }
        for (int i = 0; i < 2*n; i++) { input[i] = 0.0f; output[i] = 0.0f; }
        setenv("FFTS_DEBUG_BUF", "1", 1);
        setenv("FFTS_RET_BEFORE_OE", "1", 1);
        ffts_plan_t *p = ffts_init_1d(n, sign);
        if (!p) { free(input); free(output); return 1; }
        if (!p->buf) { p->buf = malloc(256); if (!p->buf) { ffts_free(p); free(input); free(output); return 1; } memset(p->buf, 0, 256); }
        const char *enf = getenv("FFTS_ENFORCE_EE_X12");
        if (enf && *enf) {
            *(uint64_t*)((unsigned char*)p->buf + 120) = 1ULL;
        }
        ffts_execute(p, input, output);
        if (p->buf) {
            unsigned char *b = (unsigned char*)p->buf;
            uint64_t entry = *(uint64_t*)(b + 0);
            uint64_t exitm = *(uint64_t*)(b + 8);
            uint64_t mid1  = *(uint64_t*)(b + 16);
            uint64_t pre   = *(uint64_t*)(b + 48);
            uint64_t addr1 = *(uint64_t*)(b + 32);
            uint64_t addr2 = *(uint64_t*)(b + 40);
            uint32_t off0  = *(uint32_t*)(b + 64);
            uint32_t off1  = *(uint32_t*)(b + 68);
            uint64_t inner_x12 = *(uint64_t*)(b + 72);
            uint64_t inner_x0  = *(uint64_t*)(b + 80);
            uint64_t inner_x2  = *(uint64_t*)(b + 88);
            uint64_t entry_x12 = *(uint64_t*)(b + 96);
            uint32_t peek0 = *(uint32_t*)(b + 112);
            uint32_t peek1 = *(uint32_t*)(b + 116);
            printf("EE-BUF: entry=%llu exit=%llu mid1=%llu pre=%llu\n",
                   (unsigned long long)entry,(unsigned long long)exitm,(unsigned long long)mid1,(unsigned long long)pre);
            printf("EE-BUF: off0=%u off1=%u peek0=%u peek1=%u\n", off0, off1, peek0, peek1);
            printf("EE-BUF: addr1=0x%llx addr2=0x%llx\n", (unsigned long long)addr1, (unsigned long long)addr2);
            printf("EE-BUF: inner_x12=0x%llx entry_x12=0x%llx inner_x0=0x%llx inner_x2=0x%llx\n",
                   (unsigned long long)inner_x12, (unsigned long long)entry_x12, (unsigned long long)inner_x0, (unsigned long long)inner_x2);
        }
        ffts_free(p);
        free(input);
        free(output);
        return 0;
    }

#ifdef __aarch64__
    if (argc == 2 && strcmp(argv[1], "--dump-ee-snapshot-32") == 0) {
        const int n = 32, sign = -1;
        float FFTS_ALIGN(32) *input, *output;
        if (posix_memalign((void **)&input , 16 , 2*n*sizeof(float)) != 0) return 1;
        if (posix_memalign((void **)&output, 16 , 2*n*sizeof(float)) != 0) { free(input); return 1; }
        for (int i = 0; i < 2*n; i++) { input[i] = 0.0f; output[i] = 0.0f; }
        input[2] = 1.0f;
        ffts_plan_t *p = ffts_init_1d(n, sign);
        if (!p) { printf("Plan unsupported\n"); free(input); free(output); return 1; }
        if (!p->buf) { p->buf = malloc(256); if (!p->buf) { ffts_free(p); free(input); free(output); return 1; } memset(p->buf, 0, 256); }
        ffts_execute(p, input, output);
        unsigned char *b = (unsigned char*)p->buf;
        uint64_t sx0  = *(uint64_t*)(b + 0);
        uint64_t sx16 = *(uint64_t*)(b + 8);
        uint64_t sx17 = *(uint64_t*)(b + 16);
        uint64_t sx12 = *(uint64_t*)(b + 24);
        printf("EE-SNAP32\n");
        printf("x0=%#llx x16=%#llx x17=%#llx x12=%#llx\n",
               (unsigned long long)sx0,(unsigned long long)sx16,
               (unsigned long long)sx17,(unsigned long long)sx12);
        float *fv = (float*)(b + 32);
        for (int i = 0; i < 8; ++i) {
            char lbl[32]; snprintf(lbl, sizeof(lbl), "v%d:", i);
            dump_floats(lbl, fv + i*4, 4);
        }
        ffts_free(p); free(input); free(output);
        return 0;
    }
#endif

#ifdef __aarch64__
    if (argc == 2 && strcmp(argv[1], "--dump-ee-addrs-32") == 0) {
        const int n = 32, sign = -1;
        float FFTS_ALIGN(32) *input, *output;
        if (posix_memalign((void **)&input , 16 , 2*n*sizeof(float)) != 0) return 1;
        if (posix_memalign((void **)&output, 16 , 2*n*sizeof(float)) != 0) { free(input); return 1; }
        for (int i = 0; i < 2*n; i++) { input[i] = 0.0f; output[i] = 0.0f; }
        input[2] = 1.0f;
        ffts_plan_t *p = ffts_init_1d(n, sign);
        if (!p) { printf("Plan unsupported\n"); free(input); free(output); return 1; }
        if (!p->buf) { p->buf = malloc(256); if (!p->buf) { ffts_free(p); free(input); free(output); return 1; } memset(p->buf, 0, 256); }
        ffts_execute(p, input, output);
        unsigned char *b = (unsigned char*)p->buf;
        uint64_t off0 = *(uint64_t*)(b + 160);
        uint64_t off1 = *(uint64_t*)(b + 168);
        uint64_t outp = *(uint64_t*)(b + 176);
        printf("EE-ADDRS32 off0=%llu off1=%llu x0=%#llx\n",
               (unsigned long long)off0,(unsigned long long)off1,(unsigned long long)outp);
        ffts_free(p); free(input); free(output);
        return 0;
    }

    if (argc == 2 && strcmp(argv[1], "--dump-off2-debug-32") == 0) {
        const int n = 32, sign = -1;
        float FFTS_ALIGN(32) *input, *output;
        if (posix_memalign((void **)&input , 16 , 2*n*sizeof(float)) != 0) return 1;
        if (posix_memalign((void **)&output, 16 , 2*n*sizeof(float)) != 0) { free(input); return 1; }
        for (int i = 0; i < 2*n; i++) { input[i] = 0.0f; output[i] = 0.0f; }
        input[2] = 1.0f;
        ffts_plan_t *p = ffts_init_1d(n, sign);
        if (!p) { printf("Plan unsupported\n"); free(input); free(output); return 1; }
        if (!p->buf) { p->buf = malloc(256); if (!p->buf) { ffts_free(p); free(input); free(output); return 1; } memset(p->buf, 0, 256); }
        
        // Enable ARM64 debug stores
#ifdef __aarch64__
        ffts_arm64_debug_stores_enabled = 1;
        ffts_arm64_debug_buf = (uint8_t*)p->buf;
#endif
        
        ffts_execute(p, input, output);
        
        unsigned char *b = (unsigned char*)p->buf;
        uint32_t ee_off2_1 = *(uint32_t*)(b + 160);
        uint64_t ee_base   = *(uint64_t*)(b + 168);
        uint32_t ee_off2_2 = *(uint32_t*)(b + 172);
        uint64_t ee_addr1  = *(uint64_t*)(b + 176);
        uint64_t ee_addr2  = *(uint64_t*)(b + 184);
        
        uint32_t oe_off2_1 = *(uint32_t*)(b + 192);
        uint64_t oe_addr1  = *(uint64_t*)(b + 200);
        uint32_t oe_off2_2 = *(uint32_t*)(b + 196);
        uint64_t oe_addr2  = *(uint64_t*)(b + 208);
        
        printf("OFF2-DEBUG32 N=%d output_base=%#llx buffer_size=%d\n", n, (unsigned long long)output, 2*n*4);
        printf("EE: off2_1=%u off2_2=%u base=%#llx addr1=%#llx addr2=%#llx\n",
               ee_off2_1, ee_off2_2, (unsigned long long)ee_base,
               (unsigned long long)ee_addr1, (unsigned long long)ee_addr2);
        printf("OE: off2_1=%u off2_2=%u addr1=%#llx addr2=%#llx\n",
               oe_off2_1, oe_off2_2, (unsigned long long)oe_addr1, (unsigned long long)oe_addr2);
        
        // Check if addresses are within bounds
        uint64_t buffer_start = (uint64_t)output;
        uint64_t buffer_end = buffer_start + (2*n*4);
        printf("Buffer bounds: [%#llx, %#llx)\n", (unsigned long long)buffer_start, (unsigned long long)buffer_end);
        
        // Each store pair writes 64 bytes, so check if addr+64 <= buffer_end
        const char* check_ee1 = (ee_addr1 + 64 <= buffer_end) ? "OK" : "OVERFLOW";
        const char* check_ee2 = (ee_addr2 + 64 <= buffer_end) ? "OK" : "OVERFLOW";
        const char* check_oe1 = (oe_addr1 + 64 <= buffer_end) ? "OK" : "OVERFLOW";
        const char* check_oe2 = (oe_addr2 + 64 <= buffer_end) ? "OK" : "OVERFLOW";
        
        printf("Bounds check: EE_addr1=%s EE_addr2=%s OE_addr1=%s OE_addr2=%s\n",
               check_ee1, check_ee2, check_oe1, check_oe2);
        
        ffts_free(p); free(input); free(output);
        return 0;
    }
#endif

#ifdef __aarch64__
    if (argc == 2 && strcmp(argv[1], "--dump-ee-vregs-32") == 0) {
        const int n = 32, sign = -1;
        float FFTS_ALIGN(32) *input, *output;
        if (posix_memalign((void **)&input , 16 , 2*n*sizeof(float)) != 0) return 1;
        if (posix_memalign((void **)&output, 16 , 2*n*sizeof(float)) != 0) { free(input); return 1; }
        for (int i = 0; i < 2*n; i++) { input[i] = 0.0f; output[i] = 0.0f; }
        input[2] = 1.0f;
        ffts_plan_t *p = ffts_init_1d(n, sign);
        if (!p) { printf("Plan unsupported\n"); free(input); free(output); return 1; }
        float *dump = NULL; if (posix_memalign((void **)&dump, 16, 32*sizeof(float)) != 0) { ffts_free(p); free(input); free(output); return 1; }
        memset(dump, 0, 32*sizeof(float));
        p->debug_vec_dump = dump;
        ffts_execute(p, input, output);
        printf("EE-VREGS32\n");
        for (int i = 0; i < 8; ++i) {
            char lbl[16]; snprintf(lbl, sizeof(lbl), "v%d:", i);
            dump_floats(lbl, dump + i*4, 4);
        }
        free(dump);
        ffts_free(p); free(input); free(output);
        return 0;
    }
#endif

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
