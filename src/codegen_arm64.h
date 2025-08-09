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
#include "arch/arm64/codegen_arm64_macros.h"

#ifdef HAVE_STRING_H
#include <string.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* ARM64-specific instruction type for FFTS - compatible with existing insns_t */
#ifdef __aarch64__
typedef uint32_t ffts_insn_t;  /* ARM64 instructions are 32-bit */
#else
typedef uint8_t ffts_insn_t;   /* Fallback for non-ARM64 platforms */
#endif

/* ARM64 SIMD constants for FFT operations */
extern const float arm64_neon_constants[];
extern const float arm64_neon_constants_inv[];

/* ARM64 FFT Constants - these are defined in arm64-codegen.c to avoid conflicts */

/* Forward declaration */
struct _ffts_plan_t;

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
generate_prologue_arm64(ffts_insn_t **p, struct _ffts_plan_t *plan)
{
    ffts_insn_t *start = *p;
    
    /* Generate standard ARM64 function prologue */
    arm64_generate_prologue(p, ARM64_X0, ARM64_X1);

    /* Preserve plan pointer in x19 for field loads */
    ARM64_MOV_X(p, ARM64_X19, ARM64_X0);   /* x19 = plan */

    /* Establish calling-convention registers expected by kernels */
    /* x0 = out (move from entry x2) */
    ARM64_MOV_X(p, ARM64_X0, ARM64_X2);

    /* x12 = plan->offsets (LDR x12, [x19, #off]) */
    size_t off_offsets = (size_t)((const char*)&plan->offsets - (const char*)plan);
    ARM64_LDRI_X(p, ARM64_X12, ARM64_X19, (uint32_t)off_offsets);

    /* x1 is used as WS (twiddle) base pointer throughout codegen.c,
     * so leave it as the LUT pointer argument and keep it updated there. */

    /* Compute data stream pointers x3..x10 from out pointer (x0)
     * using stride = N * sizeof(complex float) = N * 8 bytes.
     * Pattern (mirrors ARM32):
     *   x3  = x0
     *   x7  = x0 + 1*stride
     *   x5  = x0 + 2*stride
     *   x10 = x7 + 2*stride
     *   x4  = x5 + 2*stride
     *   x8  = x10 + 2*stride
     *   x6  = x4 + 2*stride
     *   x9  = x8 + 2*stride
     */
    size_t off_N = (size_t)((const char*)&plan->N - (const char*)plan);
    /* Load N into x20 */
    ARM64_LDRI_X(p, ARM64_X20, ARM64_X19, (uint32_t)off_N);
    /* x3 = x0 */
    ARM64_MOV_X(p, ARM64_X3, ARM64_X0);
    /* Compute stream pointers using ADD (shifted register): Xd = Xn + Xm LSL #imm */
    /* x7  = x0 + x20 LSL #3  (1*stride) */
    arm64_emit_add_shifted_reg(p, ARM64_X7,  ARM64_X0,  ARM64_X20, ARM64_SHIFT_LSL, 3);
    /* x5  = x0 + x20 LSL #4  (2*stride) */
    arm64_emit_add_shifted_reg(p, ARM64_X5,  ARM64_X0,  ARM64_X20, ARM64_SHIFT_LSL, 4);
    /* x10 = x7 + x20 LSL #4  (x7 + 2*stride) */
    arm64_emit_add_shifted_reg(p, ARM64_X10, ARM64_X7,  ARM64_X20, ARM64_SHIFT_LSL, 4);
    /* x4  = x5 + x20 LSL #4  (x5 + 2*stride) */
    arm64_emit_add_shifted_reg(p, ARM64_X4,  ARM64_X5,  ARM64_X20, ARM64_SHIFT_LSL, 4);
    /* x8  = x10 + x20 LSL #4 (x10 + 2*stride) */
    arm64_emit_add_shifted_reg(p, ARM64_X8,  ARM64_X10, ARM64_X20, ARM64_SHIFT_LSL, 4);
    /* x6  = x4 + x20 LSL #4  (x4 + 2*stride) */
    arm64_emit_add_shifted_reg(p, ARM64_X6,  ARM64_X4,  ARM64_X20, ARM64_SHIFT_LSL, 4);
    /* x9  = x8 + x20 LSL #4  (x8 + 2*stride) */
    arm64_emit_add_shifted_reg(p, ARM64_X9,  ARM64_X8,  ARM64_X20, ARM64_SHIFT_LSL, 4);

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
    /* Initialize loop counter for ARM64 in w11 (used by leaf blobs) */
    if (loop_count <= 0xffffu) {
        /* mov w11, #imm16 */
        arm64_emit_instruction(p, 0x52800000u | ((loop_count & 0xffffu) << 5) | 11u);
    } else {
        /* movz w11, #(imm16) */
        arm64_emit_instruction(p, 0x52800000u | (((loop_count & 0xffffu)) << 5) | 11u);
        /* movk w11, #(imm16), lsl #16 */
        arm64_emit_instruction(p, 0x72a00000u | ((((loop_count >> 16) & 0xffffu)) << 5) | 11u);
    }
}

static inline void
generate_leaf_ee_arm64(ffts_insn_t **p, size_t N, size_t offset, int sign)
{
    (void)N; (void)offset;
    extern const uint8_t neon64_ee[];
    extern const uint8_t neon64_oo[];
    uint32_t *dst = arm64_copy_blob((uint32_t**)p, neon64_ee, neon64_oo);
    arm64_patch_neon64_ee(dst, sign);
}

static inline void
generate_leaf_oo_arm64(ffts_insn_t **p, size_t N, size_t offset, int sign)
{
    (void)N; (void)offset;
    extern const uint8_t neon64_oo[];
    extern const uint8_t neon64_eo[];
    uint32_t *dst = arm64_copy_blob((uint32_t**)p, neon64_oo, neon64_eo);
    arm64_patch_neon64_oo(dst, sign);
}

static inline void
generate_leaf_eo_arm64(ffts_insn_t **p, size_t N, size_t offset, int sign)
{
    (void)N; (void)offset;
    extern const uint8_t neon64_eo[];
    extern const uint8_t neon64_oe[];
    uint32_t *dst = arm64_copy_blob((uint32_t**)p, neon64_eo, neon64_oe);
    arm64_patch_neon64_eo(dst, sign);
}

static inline void
generate_leaf_oe_arm64(ffts_insn_t **p, size_t N, size_t offset, int sign)
{
    (void)N; (void)offset;
    extern const uint8_t neon64_oe[];
    extern const uint8_t neon64_end[];
    uint32_t *dst = arm64_copy_blob((uint32_t**)p, neon64_oe, neon64_end);
    arm64_patch_neon64_oe(dst, sign);
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
generate_constants_load_arm64(ffts_insn_t **p, struct _ffts_plan_t *plan, int sign)
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

/* ARM64 NEON instruction macros for FFT operations */
/* Note: These macros are also defined in arm64-codegen.h - using those instead */

/* Convenient macros for ARM64 instruction emission - use those from arm64-codegen.h */

#ifdef __cplusplus
}
#endif

#endif /* FFTS_CODEGEN_ARM64_H */ 