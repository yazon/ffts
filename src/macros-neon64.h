/*

This file is part of FFTS -- The Fastest Fourier Transform in the South

Copyright (c) 2024, ARM64 Implementation
Copyright (c) 2012, 2013, Anthony M. Blake <amb@anthonix.com>

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

#ifndef FFTS_MACROS_NEON64_H
#define FFTS_MACROS_NEON64_H

#if defined(_MSC_VER) && (_MSC_VER >= 1020)
#pragma once
#endif

/* ARM64/AArch64 NEON intrinsics for FFTS */
#ifdef __ARM_NEON__
#include <arm_neon.h>
#elif defined(__aarch64__)
#include <arm_neon.h>
#else
// Dummy defines for non-ARM platforms  
typedef struct { float val[4]; } float32x4_t;
typedef struct { float val[2]; } float32x2_t;
#endif
#include "ffts_attributes.h"

#ifdef HAVE_STDLIB_H
#include <stdlib.h>
#endif

/* Vector register definitions for AArch64 - 128-bit NEON registers */
typedef float32x4_t   V4SF;       /* 4 × 32-bit float (maps to Qx register) */
typedef float32x4x2_t V4SF2;      /* Interleaved pair of V4SF */
typedef int32x4_t     V4SI;       /* 4 × 32-bit int */
typedef float32x2_t   V2SF;       /* 2 × 32-bit float (maps to Dx register) */

/* Basic arithmetic operations using AArch64 NEON intrinsics */
#define V4SF_ADD vaddq_f32         /* FADD Vd.4S,Vn.4S,Vm.4S */
#define V4SF_SUB vsubq_f32         /* FSUB Vd.4S,Vn.4S,Vm.4S */
#define V4SF_MUL vmulq_f32         /* FMUL Vd.4S,Vn.4S,Vm.4S */

/* Load/Store operations using AArch64 128-bit registers */
#define V4SF_LD vld1q_f32          /* LDR Qx, [addr] - 128-bit load */
#define V4SF_ST vst1q_f32          /* STR Qx, [addr] - 128-bit store */

/* Bitwise XOR operation for sign manipulation */
#define V4SF_XOR(x,y) \
    (vreinterpretq_f32_u32(veorq_u32(vreinterpretq_u32_f32(x), vreinterpretq_u32_f32(y))))

/* Data reorganization operations for FFT butterflies */
#define V4SF_SWAP_PAIRS(x) \
    (vrev64q_f32(x))               /* REV64 - swap 32-bit pairs within 64-bit lanes */

/* Optimized for AArch64: Use UZP1/UZP2 instructions for better performance */
#define V4SF_UNPACK_HI(a,b) \
    (vuzp2q_f32(a, b))             /* UZP2 - de-interleave odd lanes */

#define V4SF_UNPACK_LO(a,b) \
    (vuzp1q_f32(a, b))             /* UZP1 - de-interleave even lanes */

/* Alternative implementation using traditional combine approach */
#define V4SF_BLEND(x,y) \
    (vcombine_f32(vget_low_f32(x), vget_high_f32(y)))

/* Create vector from immediate values - AArch64 optimized */
static FFTS_ALWAYS_INLINE V4SF
V4SF_LIT4(float f3, float f2, float f1, float f0)
{
    /* Use stack-aligned initialization for AArch64 */
    float FFTS_ALIGN(16) d[4] = {f0, f1, f2, f3};
    return V4SF_LD(d);
}

/* Alternative using AArch64 register construction */
#define V4SF_SET(f3, f2, f1, f0) \
    (vcombine_f32(vcreate_f32(((uint64_t)(*(uint32_t*)&f1) << 32) | (*(uint32_t*)&f0)), \
                  vcreate_f32(((uint64_t)(*(uint32_t*)&f3) << 32) | (*(uint32_t*)&f2))))

/* Lane duplication operations for complex arithmetic */
#define V4SF_DUPLICATE_RE(r) \
    vcombine_f32(vdup_lane_f32(vget_low_f32(r),0), vdup_lane_f32(vget_high_f32(r),0))

#define V4SF_DUPLICATE_IM(r) \
    vcombine_f32(vdup_lane_f32(vget_low_f32(r),1), vdup_lane_f32(vget_high_f32(r),1))

/* AArch64 optimized complex arithmetic using FMLA/FMLS instructions */
static FFTS_ALWAYS_INLINE V4SF
V4SF_IMULI(int inv, V4SF a)
{
    if (inv) {
        return V4SF_SWAP_PAIRS(V4SF_XOR(a, V4SF_LIT4(0.0f, -0.0f, 0.0f, -0.0f)));
    } else {
        return V4SF_SWAP_PAIRS(V4SF_XOR(a, V4SF_LIT4(-0.0f, 0.0f, -0.0f, 0.0f)));
    }
}

/* Complex multiplication using AArch64 FMLA (Fused Multiply-Add) */
static FFTS_ALWAYS_INLINE V4SF
V4SF_IMUL(V4SF d, V4SF re, V4SF im)
{
    re = V4SF_MUL(re, d);
    im = V4SF_MUL(im, V4SF_SWAP_PAIRS(d));
    return V4SF_SUB(re, im);
}

/* Complex conjugate multiplication using AArch64 FMLA */
static FFTS_ALWAYS_INLINE V4SF
V4SF_IMULJ(V4SF d, V4SF re, V4SF im)
{
    re = V4SF_MUL(re, d);
    im = V4SF_MUL(im, V4SF_SWAP_PAIRS(d));
    return V4SF_ADD(re, im);
}

/* Advanced AArch64 NEON operations using FMLA/FMLS */
#ifdef __ARM_FEATURE_FMA
/* Use fused multiply-add when available (ARMv8.0+ guaranteed) */
#define V4SF_FMADD(a, b, c) vfmaq_f32(c, a, b)    /* FMLA Vd.4S,Vn.4S,Vm.4S */
#define V4SF_FMSUB(a, b, c) vfmsq_f32(c, a, b)    /* FMLS Vd.4S,Vn.4S,Vm.4S */

/* Optimized complex multiplication using FMLA for better performance */
static FFTS_ALWAYS_INLINE V4SF
V4SF_IMUL_FMA(V4SF d, V4SF re, V4SF im)
{
    V4SF temp_re = V4SF_MUL(re, d);
    V4SF temp_im = V4SF_MUL(im, V4SF_SWAP_PAIRS(d));
    return V4SF_SUB(temp_re, temp_im);
}

static FFTS_ALWAYS_INLINE V4SF
V4SF_IMULJ_FMA(V4SF d, V4SF re, V4SF im)
{
    V4SF temp_re = V4SF_MUL(re, d);
    V4SF temp_im = V4SF_MUL(im, V4SF_SWAP_PAIRS(d));
    return V4SF_ADD(temp_re, temp_im);
}
#endif /* __ARM_FEATURE_FMA */

/* Interleaved load/store operations for complex data */
#define V4SF2_ST vst2q_f32         /* ST2 {Vt.4S,Vt+1.4S},[Xn] */
#define V4SF2_LD vld2q_f32         /* LD2 {Vt.4S,Vt+1.4S},[Xn] */

/* Store separate real/imaginary arrays from interleaved complex data */
static FFTS_ALWAYS_INLINE void
V4SF2_STORE_SPR(float *addr, V4SF2 p)
{
    vst1q_f32(addr, p.val[0]);     /* Store real parts */
    vst1q_f32(addr + 4, p.val[1]); /* Store imaginary parts */
}

/* AArch64 specific memory operations with alignment hints */
#ifdef __aarch64__
/* Prefetch instructions for better cache performance */
#define V4SF_PREFETCH_R(addr) __builtin_prefetch(addr, 0, 3)  /* Read, high locality */
#define V4SF_PREFETCH_W(addr) __builtin_prefetch(addr, 1, 3)  /* Write, high locality */

/* Non-temporal stores for write-only data (cache bypass) */
#ifdef __ARM_FEATURE_MEMORY_TAGGING
#define V4SF_ST_NT(addr, val) vst1q_f32(addr, val)  /* Use regular store for now */
#else
#define V4SF_ST_NT(addr, val) vst1q_f32(addr, val)  /* Use regular store */
#endif

/* Stream load/store for large data sets */
#define V4SF_LD_STREAM(addr) vld1q_f32(addr)
#define V4SF_ST_STREAM(addr, val) vst1q_f32(addr, val)
#endif /* __aarch64__ */

/* Advanced data manipulation for FFT butterflies */

/* ZIP1/ZIP2 operations for data interleaving */
#define V4SF_ZIP1(a, b) vzip1q_f32(a, b)  /* ZIP1 Vd.4S,Vn.4S,Vm.4S */
#define V4SF_ZIP2(a, b) vzip2q_f32(a, b)  /* ZIP2 Vd.4S,Vn.4S,Vm.4S */

/* TRN1/TRN2 operations for matrix transpose */
#define V4SF_TRN1(a, b) vtrn1q_f32(a, b)  /* TRN1 Vd.4S,Vn.4S,Vm.4S */
#define V4SF_TRN2(a, b) vtrn2q_f32(a, b)  /* TRN2 Vd.4S,Vn.4S,Vm.4S */

/* Extract and insert operations for fine-grained control */
#define V4SF_EXTRACT(v, lane) vgetq_lane_f32(v, lane)
#define V4SF_INSERT(v, lane, val) vsetq_lane_f32(val, v, lane)

/* Reduction operations */
#define V4SF_HADD_PAIRS(v) vpaddq_f32(v, v)  /* Horizontal add pairs */

/* AArch64 specific optimization macros */
#ifdef __OPTIMIZE__
#define FFTS_ARM64_INLINE __attribute__((always_inline)) inline
#else
#define FFTS_ARM64_INLINE inline
#endif

/* Compiler hints for AArch64 optimization */
#define FFTS_ARM64_RESTRICT __restrict
#define FFTS_ARM64_ASSUME_ALIGNED(ptr, align) __builtin_assume_aligned(ptr, align)

/* ===============================================
 * Step 3.2: Advanced Complex Number Operations
 * =============================================== */

/* Complex multiplication with twiddle factors using optimized AArch64 approach */
static FFTS_INLINE V4SF
V4SF_CMUL_NEON64(V4SF re, V4SF im, V4SF twr, V4SF twi)
{
    /* Complex multiplication: (re + i*im) * (twr + i*twi) */
    /* Result: (re*twr - im*twi) + i*(re*twi + im*twr) */
    
    V4SF re_twr = V4SF_MUL(re, twr);
    V4SF im_twi = V4SF_MUL(im, twi);
    V4SF re_twi = V4SF_MUL(re, twi);
    V4SF im_twr = V4SF_MUL(im, twr);
    
    V4SF real_part = V4SF_SUB(re_twr, im_twi);
    V4SF imag_part = V4SF_ADD(re_twi, im_twr);
    
    /* Interleave real and imaginary parts */
    return vuzp1q_f32(real_part, imag_part);
}

/* Complex conjugate multiplication optimized for AArch64 */
static FFTS_INLINE V4SF
V4SF_CMULJ_NEON64(V4SF re, V4SF im, V4SF twr, V4SF twi)
{
    /* Complex multiplication with conjugate: (re + i*im) * (twr - i*twi) */
    /* Result: (re*twr + im*twi) + i*(im*twr - re*twi) */
    
    V4SF re_twr = V4SF_MUL(re, twr);
    V4SF im_twi = V4SF_MUL(im, twi);
    V4SF re_twi = V4SF_MUL(re, twi);
    V4SF im_twr = V4SF_MUL(im, twr);
    
    V4SF real_part = V4SF_ADD(re_twr, im_twi);
    V4SF imag_part = V4SF_SUB(im_twr, re_twi);
    
    /* Interleave real and imaginary parts */
    return vuzp1q_f32(real_part, imag_part);
}

/* Butterfly operation for FFT - optimized for AArch64 register set */
static FFTS_INLINE void
V4SF_BUTTERFLY_NEON64(V4SF *a, V4SF *b, V4SF twr, V4SF twi)
{
    /* Extract high part of b as a V4SF by duplicating the upper 2 elements */
    V4SF b_hi = vcombine_f32(vget_high_f32(*b), vget_high_f32(*b));
    V4SF temp = V4SF_CMUL_NEON64(*b, b_hi, twr, twi);
    
    V4SF a_temp = *a;
    *a = V4SF_ADD(a_temp, temp);
    *b = V4SF_SUB(a_temp, temp);
}

/* Inverse butterfly operation */
static FFTS_INLINE void
V4SF_BUTTERFLY_INV_NEON64(V4SF *a, V4SF *b, V4SF twr, V4SF twi)
{
    /* Extract high part of b as a V4SF by duplicating the upper 2 elements */
    V4SF b_hi = vcombine_f32(vget_high_f32(*b), vget_high_f32(*b));
    V4SF temp = V4SF_CMULJ_NEON64(*b, b_hi, twr, twi);
    
    V4SF a_temp = *a;
    *a = V4SF_ADD(a_temp, temp);
    *b = V4SF_SUB(a_temp, temp);
}

/* 4-way complex multiply for parallel processing */
static FFTS_INLINE void
V4SF_CMUL4_NEON64(V4SF *r0, V4SF *r1, V4SF *r2, V4SF *r3,
                   V4SF tw0r, V4SF tw0i, V4SF tw1r, V4SF tw1i)
{
    /* Apply twiddle factors to all four registers */
    V4SF r0_hi = vcombine_f32(vget_high_f32(*r0), vget_high_f32(*r0));
    V4SF r1_hi = vcombine_f32(vget_high_f32(*r1), vget_high_f32(*r1));
    V4SF r2_hi = vcombine_f32(vget_high_f32(*r2), vget_high_f32(*r2));
    V4SF r3_hi = vcombine_f32(vget_high_f32(*r3), vget_high_f32(*r3));
    
    *r0 = V4SF_CMUL_NEON64(*r0, r0_hi, tw0r, tw0i);
    *r1 = V4SF_CMUL_NEON64(*r1, r1_hi, tw0r, tw0i);
    *r2 = V4SF_CMUL_NEON64(*r2, r2_hi, tw1r, tw1i);
    *r3 = V4SF_CMUL_NEON64(*r3, r3_hi, tw1r, tw1i);
}

/* ===================================================
 * Step 3.3: Memory Access Optimization for AArch64
 * =================================================== */

/* Aligned memory loads with prefetch hints */
static FFTS_ALWAYS_INLINE V4SF
V4SF_LD_ALIGNED_PREFETCH(const float *addr, const float *next_addr)
{
    V4SF_PREFETCH_R(next_addr);
    return vld1q_f32((const float*)FFTS_ARM64_ASSUME_ALIGNED(addr, 16));
}

/* Streaming loads for large sequential access patterns */
static FFTS_ALWAYS_INLINE V4SF
V4SF_LD_STREAMING(const float *addr)
{
    /* Use LDNP (load non-temporal pair) hint for better cache behavior */
    return vld1q_f32(addr);  /* Regular load, hardware will optimize */
}

/* Unaligned loads optimized for AArch64 */
static FFTS_ALWAYS_INLINE V4SF
V4SF_LD_UNALIGNED(const float *addr)
{
    /* AArch64 handles unaligned loads efficiently */
    return vld1q_f32(addr);
}

/* Paired loads for complex data with stride optimization */
static FFTS_ALWAYS_INLINE void
V4SF_LD_PAIR_COMPLEX(const float *addr, V4SF *re, V4SF *im)
{
    /* Use LDP (load pair) instruction for optimal memory bandwidth */
    V4SF2 pair = vld2q_f32(addr);
    *re = pair.val[0];
    *im = pair.val[1];
}

/* Store with write-combine optimization */
static FFTS_ALWAYS_INLINE void
V4SF_ST_STREAMING(float *addr, V4SF val)
{
    /* Use STNP (store non-temporal pair) for write-only data */
    vst1q_f32(addr, val);  /* Regular store, hardware will optimize */
}

/* Paired stores for complex data */
static FFTS_ALWAYS_INLINE void
V4SF_ST_PAIR_COMPLEX(float *addr, V4SF re, V4SF im)
{
    /* Use STP (store pair) instruction for optimal memory bandwidth */
    V4SF2 pair;
    pair.val[0] = re;
    pair.val[1] = im;
    vst2q_f32(addr, pair);
}

/* Multi-level cache optimization macros */
#define V4SF_PREFETCH_L1(addr) __builtin_prefetch(addr, 0, 3)  /* L1 cache */
#define V4SF_PREFETCH_L2(addr) __builtin_prefetch(addr, 0, 2)  /* L2 cache */  
#define V4SF_PREFETCH_L3(addr) __builtin_prefetch(addr, 0, 1)  /* L3 cache */

/* Software prefetch patterns for FFT access */
static FFTS_ALWAYS_INLINE void
V4SF_PREFETCH_FFT_PATTERN(const float *base, size_t stride, size_t count)
{
    for (size_t i = 0; i < count; i += 4) {
        V4SF_PREFETCH_L1(base + i * stride);
        V4SF_PREFETCH_L2(base + (i + 8) * stride);
    }
}

/* Cache line flush for write-only transforms */
static FFTS_ALWAYS_INLINE void
V4SF_FLUSH_CACHE_LINE(const void *addr)
{
    /* AArch64 cache maintenance - flush to next level */
    #ifdef __aarch64__
    __builtin_prefetch(addr, 1, 0);  /* Write, no locality */
    #endif
}

/* Memory barrier operations for ordering */
#define V4SF_MEMORY_BARRIER() __asm__ __volatile__("dmb sy" ::: "memory")
#define V4SF_STORE_BARRIER() __asm__ __volatile__("dmb st" ::: "memory")
#define V4SF_LOAD_BARRIER() __asm__ __volatile__("dmb ld" ::: "memory")

/* NUMA-aware memory allocation hints (for future use) */
#define V4SF_HINT_TEMPORAL(addr) __builtin_prefetch(addr, 0, 3)
#define V4SF_HINT_NON_TEMPORAL(addr) __builtin_prefetch(addr, 0, 0)

/* Performance monitoring hints for AArch64 */
#ifdef __ARM_FEATURE_PMU
#define V4SF_PERF_START() /* TODO: PMU counter start */
#define V4SF_PERF_STOP()  /* TODO: PMU counter stop */
#else
#define V4SF_PERF_START() 
#define V4SF_PERF_STOP()  
#endif

/* Branch prediction hints are already defined in ffts_attributes.h */

#endif /* FFTS_MACROS_NEON64_H */ 