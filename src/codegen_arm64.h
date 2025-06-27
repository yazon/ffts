/*
 * codegen_arm64.h: ARM64/AArch64 code generation for FFTS
 *
 * This file is part of FFTS -- The Fastest Fourier Transform in the South
 *
 * Copyright (c) 2024, ARM64 Implementation
 * Copyright (c) 2012, Anthony M. Blake <amb@anthonix.com>
 * Copyright (c) 2012, The University of Waikato
 * 
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * 	* Redistributions of source code must retain the above copyright
 * 		notice, this list of conditions and the following disclaimer.
 * 	* Redistributions in binary form must reproduce the above copyright
 * 		notice, this list of conditions and the following disclaimer in the
 * 		documentation and/or other materials provided with the distribution.
 * 	* Neither the name of the organization nor the
	  names of its contributors may be used to endorse or promote products
 * 		derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL ANTHONY M. BLAKE BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

#ifndef FFTS_CODEGEN_ARM64_H
#define FFTS_CODEGEN_ARM64_H

#if defined (_MSC_VER) && (_MSC_VER >= 1020)
#pragma once
#endif

#include "ffts_internal.h"
#include "arch/arm64/arm64-codegen.h"
#include "macros-neon64.h"

#ifdef HAVE_STRING_H
#include <string.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* ARM64-specific instruction type for FFTS */
typedef arm64instr_t ffts_insn_t;

/* ARM64 SIMD constants for FFT operations */
extern const float arm64_neon_constants[];
extern const float arm64_neon_constants_inv[];

/* ARM64 FFT Constants - forward transform */
static const float arm64_neon_constants[] = {
    /* Sign mask for complex multiplication */
    -0.0f, 0.0f, -0.0f, 0.0f,
    
    /* Twiddle factors for 8-point FFT */
    1.0f, 0.0f, 0.7071067811865475f, -0.7071067811865475f,   /* W_8^0, W_8^1 */
    0.0f, -1.0f, -0.7071067811865475f, -0.7071067811865475f,  /* W_8^2, W_8^3 */
    
    /* Additional constants for larger transforms */
    0.9238795325112867f, -0.3826834323650898f,   /* W_16^1 */
    0.3826834323650898f, -0.9238795325112867f,   /* W_16^3 */
    
    /* Constants for complex number operations */
    1.0f, 1.0f, 1.0f, 1.0f,        /* All ones */
    -1.0f, 1.0f, -1.0f, 1.0f,      /* Alternating sign for imaginary parts */
};

/* ARM64 FFT Constants - inverse transform */
static const float arm64_neon_constants_inv[] = {
    /* Sign mask for complex multiplication (inverted) */
    0.0f, -0.0f, 0.0f, -0.0f,
    
    /* Twiddle factors for 8-point IFFT (conjugated) */
    1.0f, 0.0f, 0.7071067811865475f, 0.7071067811865475f,    /* W_8^0, W_8^1* */
    0.0f, 1.0f, -0.7071067811865475f, 0.7071067811865475f,   /* W_8^2*, W_8^3* */
    
    /* Additional constants for larger transforms (conjugated) */
    0.9238795325112867f, 0.3826834323650898f,    /* W_16^1* */
    0.3826834323650898f, 0.9238795325112867f,    /* W_16^3* */
    
    /* Constants for complex number operations */
    1.0f, 1.0f, 1.0f, 1.0f,        /* All ones */
    -1.0f, 1.0f, -1.0f, 1.0f,      /* Alternating sign for imaginary parts */
};

/* Function prototypes for ARM64 FFT code generation */

/* Base case generators */
static inline ffts_insn_t*
generate_size4_base_case_arm64(ffts_insn_t **p, int sign)
{
    return arm64_generate_size4_base_case(p, sign);
}

static inline ffts_insn_t*
generate_size8_base_case_arm64(ffts_insn_t **p, int sign)
{
    return arm64_generate_size8_base_case(p, sign);
}

static inline ffts_insn_t*
generate_size16_base_case_arm64(ffts_insn_t **p, int sign)
{
    /* For now, implement as combination of smaller cases */
    /* Full optimized implementation would use all 32 NEON registers */
    ffts_insn_t *start = *p;
    
    /* Store caller-saved registers */
    arm64_emit_instruction(p, 0xa9be7bfd);  /* stp x29, x30, [sp, #-32]! */
    arm64_emit_instruction(p, 0xa9015bf5);  /* stp x21, x22, [sp, #16] */
    
    /* Implement 16-point FFT using divide-and-conquer */
    /* This is a placeholder - optimized version would use radix-4 */
    
    /* Restore registers */
    arm64_emit_instruction(p, 0xa9415bf5);  /* ldp x21, x22, [sp, #16] */
    arm64_emit_instruction(p, 0xa8c27bfd);  /* ldp x29, x30, [sp], #32 */
    
    arm64_emit_ret(p);
    return start;
}

/* Prologue/Epilogue generation */
static inline ffts_insn_t*
generate_prologue_arm64(ffts_insn_t **p, ffts_plan_t *plan)
{
    ffts_insn_t *start = *p;
    
    /* Generate standard ARM64 function prologue */
    arm64_generate_prologue(p, ARM64_X0, ARM64_X1);
    
    /* Set up constants pointer in x2 if needed */
    if (plan->constants) {
        /* adrp x2, constants */
        /* add x2, x2, :lo12:constants */
        /* For now, assume constants are passed as parameter */
        ARM64_MOV_X(p, ARM64_X2, ARM64_X2);
    }
    
    return start;
}

static inline void
generate_epilogue_arm64(ffts_insn_t **p)
{
    arm64_generate_epilogue(p);
}

/* Loop and control flow generation */
static inline void
generate_leaf_init_arm64(ffts_insn_t **p, uint32_t loop_count)
{
    /* Initialize loop counter for ARM64 */
    if (loop_count <= 0xfff) {
        /* mov w3, #loop_count */
        arm64_emit_instruction(p, 0x52800000 | (loop_count << 5) | 3);
    } else {
        /* Use movz/movk sequence for larger values */
        arm64_emit_instruction(p, 0x52800003 | ((loop_count & 0xffff) << 5));
        if (loop_count > 0xffff) {
            arm64_emit_instruction(p, 0x72a00003 | (((loop_count >> 16) & 0xffff) << 5));
        }
    }
}

static inline void
generate_leaf_ee_arm64(ffts_insn_t **p, size_t N, size_t offset, int sign)
{
    /* Generate even-even leaf computation for ARM64 */
    /* This implements the core FFT butterfly operations */
    
    /* Load data using LDP instructions for better performance */
    ARM64_LDP_Q(p, ARM64_V0, ARM64_V1, ARM64_X0, offset / 8);
    ARM64_LDP_Q(p, ARM64_V2, ARM64_V3, ARM64_X0, (offset + N/2) / 8);
    
    /* Perform butterfly operations */
    arm64_generate_butterfly_4s(p, ARM64_V0, ARM64_V2, ARM64_V4, ARM64_V5);
    arm64_generate_butterfly_4s(p, ARM64_V1, ARM64_V3, ARM64_V6, ARM64_V7);
    
    /* Store results */
    ARM64_STP_Q(p, ARM64_V0, ARM64_V1, ARM64_X0, offset / 8);
    ARM64_STP_Q(p, ARM64_V2, ARM64_V3, ARM64_X0, (offset + N/2) / 8);
}

static inline void
generate_leaf_eo_arm64(ffts_insn_t **p, size_t N, size_t offset, int sign)
{
    /* Generate even-odd leaf computation for ARM64 */
    /* Similar to ee but with different twiddle factors */
    
    /* Load twiddle factors */
    ARM64_LDP_Q(p, ARM64_V8, ARM64_V9, ARM64_X1, 0);  /* Load twiddle factors */
    
    /* Load data */
    ARM64_LDP_Q(p, ARM64_V0, ARM64_V1, ARM64_X0, offset / 8);
    ARM64_LDP_Q(p, ARM64_V2, ARM64_V3, ARM64_X0, (offset + N/4) / 8);
    
    /* Apply twiddle factors and perform butterflies */
    arm64_generate_complex_mul(p, ARM64_V2, ARM64_V2, ARM64_V8, ARM64_V9);
    arm64_generate_complex_mul(p, ARM64_V3, ARM64_V3, ARM64_V10, ARM64_V11);
    
    arm64_generate_butterfly_4s(p, ARM64_V0, ARM64_V2, ARM64_V4, ARM64_V5);
    arm64_generate_butterfly_4s(p, ARM64_V1, ARM64_V3, ARM64_V6, ARM64_V7);
    
    /* Store results */
    ARM64_STP_Q(p, ARM64_V0, ARM64_V1, ARM64_X0, offset / 8);
    ARM64_STP_Q(p, ARM64_V2, ARM64_V3, ARM64_X0, (offset + N/4) / 8);
}

static inline void
generate_leaf_oe_arm64(ffts_insn_t **p, size_t N, size_t offset, int sign)
{
    /* Generate odd-even leaf computation for ARM64 */
    generate_leaf_eo_arm64(p, N, offset, sign);  /* Similar implementation */
}

static inline void
generate_leaf_oo_arm64(ffts_insn_t **p, size_t N, size_t offset, int sign)
{
    /* Generate odd-odd leaf computation for ARM64 */
    /* Most complex case with full twiddle factor application */
    
    /* Load twiddle factors for both stages */
    ARM64_LDP_Q(p, ARM64_V8, ARM64_V9, ARM64_X1, 0);   /* First stage twiddles */
    ARM64_LDP_Q(p, ARM64_V10, ARM64_V11, ARM64_X1, 2); /* Second stage twiddles */
    ARM64_LDP_Q(p, ARM64_V12, ARM64_V13, ARM64_X1, 4); /* Third stage twiddles */
    
    /* Load data */
    ARM64_LDP_Q(p, ARM64_V0, ARM64_V1, ARM64_X0, offset / 8);
    ARM64_LDP_Q(p, ARM64_V2, ARM64_V3, ARM64_X0, (offset + N/8) / 8);
    
    /* Apply all twiddle factors */
    arm64_generate_complex_mul(p, ARM64_V2, ARM64_V2, ARM64_V8, ARM64_V9);
    arm64_generate_complex_mul(p, ARM64_V3, ARM64_V3, ARM64_V10, ARM64_V11);
    
    /* Perform butterflies */
    arm64_generate_butterfly_4s(p, ARM64_V0, ARM64_V2, ARM64_V4, ARM64_V5);
    arm64_generate_butterfly_4s(p, ARM64_V1, ARM64_V3, ARM64_V6, ARM64_V7);
    
    /* Store results */
    ARM64_STP_Q(p, ARM64_V0, ARM64_V1, ARM64_X0, offset / 8);
    ARM64_STP_Q(p, ARM64_V2, ARM64_V3, ARM64_X0, (offset + N/8) / 8);
}

static inline void
generate_leaf_finish_arm64(ffts_insn_t **p)
{
    /* Finish leaf processing loop */
    /* Decrement counter and branch if not zero */
    
    /* subs w3, w3, #1 */
    arm64_emit_instruction(p, 0x71000463);
    
    /* b.ne loop_start (offset calculated dynamically) */
    /* For now, use a placeholder offset */
    arm64_emit_instruction(p, 0x54000001);  /* b.ne +0 (to be patched) */
}

/* Memory operation helpers */
static inline void
generate_constants_load_arm64(ffts_insn_t **p, ffts_plan_t *plan, int sign)
{
    /* Load constants appropriate for forward/inverse FFT */
    if (sign < 0) {
        /* Load forward FFT constants */
        /* adrp x2, arm64_neon_constants */
        /* add x2, x2, :lo12:arm64_neon_constants */
        ARM64_MOV_X(p, ARM64_X2, ARM64_X2);  /* Placeholder */
    } else {
        /* Load inverse FFT constants */
        /* adrp x2, arm64_neon_constants_inv */
        /* add x2, x2, :lo12:arm64_neon_constants_inv */
        ARM64_MOV_X(p, ARM64_X2, ARM64_X2);  /* Placeholder */
    }
}

/* Branch generation for loops */
static inline void
generate_loop_start_arm64(ffts_insn_t **p)
{
    /* Mark the start of a loop for branch targets */
    /* No instruction needed, just a marker for offset calculation */
}

static inline void
generate_loop_end_arm64(ffts_insn_t **p, ffts_insn_t *loop_start)
{
    /* Generate branch back to loop start */
    ptrdiff_t offset = loop_start - (*p + 1);
    arm64_emit_b(p, (int32_t)(offset * 4));
}

/* Memory prefetch for large FFTs */
static inline void
generate_prefetch_arm64(ffts_insn_t **p, ARM64Reg base, int offset)
{
    /* prfm pldl1keep, [base, #offset] */
    if (offset >= 0 && offset <= 0x7ff8) {
        arm64_emit_instruction(p, 0xf9800000 | ((offset >> 3) << 10) | (base << 5));
    }
}

/* Function wrappers for compatibility */
static inline ffts_insn_t*
generate_size4_base_case(ffts_insn_t **p, int sign)
{
    return generate_size4_base_case_arm64(p, sign);
}

static inline ffts_insn_t*
generate_size8_base_case(ffts_insn_t **p, int sign)
{
    return generate_size8_base_case_arm64(p, sign);
}

static inline ffts_insn_t*
generate_size16_base_case(ffts_insn_t **p, int sign)
{
    return generate_size16_base_case_arm64(p, sign);
}

#ifdef __cplusplus
}
#endif

#endif /* FFTS_CODEGEN_ARM64_H */ 