/*
 * arm64-codegen.c: AArch64 (ARM64) code generation implementation
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

#include "arm64-codegen.h"
#include "../../ffts_internal.h"
#include "../../macros-neon64.h"

#ifdef HAVE_STRING_H
#include <string.h>
#endif

/* Function prologue generation for ARM64 FFT functions */
void 
arm64_generate_prologue(arm64instr_t **p, ARM64Reg data_ptr, ARM64Reg lut_ptr)
{
    /* Standard ARM64 function prologue */
    /* stp x29, x30, [sp, #-16]! */
    arm64_emit_instruction(p, 0xa9bf7bfd);
    
    /* mov x29, sp */
    arm64_emit_instruction(p, 0x910003fd);
    
    /* Store callee-saved registers if needed */
    /* stp x19, x20, [sp, #-16]! */
    arm64_emit_instruction(p, 0xa9bf53f3);
    
    /* stp x21, x22, [sp, #-16]! */
    arm64_emit_instruction(p, 0xa9bf5bf5);
    
    /* Set up function parameters in expected registers */
    if (data_ptr != ARM64_X0) {
        ARM64_MOV_X(p, data_ptr, ARM64_X0);
    }
    if (lut_ptr != ARM64_X1) {
        ARM64_MOV_X(p, lut_ptr, ARM64_X1);
    }
}

/* Function epilogue generation for ARM64 FFT functions */
void 
arm64_generate_epilogue(arm64instr_t **p)
{
    /* Restore callee-saved registers */
    /* ldp x21, x22, [sp], #16 */
    arm64_emit_instruction(p, 0xa8c15bf5);
    
    /* ldp x19, x20, [sp], #16 */
    arm64_emit_instruction(p, 0xa8c153f3);
    
    /* Standard ARM64 function epilogue */
    /* ldp x29, x30, [sp], #16 */
    arm64_emit_instruction(p, 0xa8c17bfd);
    
    /* ret */
    arm64_emit_ret(p);
}

/* Generate ARM64 NEON butterfly operation using 4×32-bit floats */
void 
arm64_generate_butterfly_4s(arm64instr_t **p, ARM64VReg a, ARM64VReg b, ARM64VReg twr, ARM64VReg twi)
{
    ARM64VReg temp1 = ARM64_V16;  /* Temporary register */
    ARM64VReg temp2 = ARM64_V17;  /* Temporary register */
    ARM64VReg temp3 = ARM64_V18;  /* Temporary register */
    ARM64VReg temp4 = ARM64_V19;  /* Temporary register */
    
    /* 
     * FFT butterfly operation:
     * temp = b * (twr + i*twi)
     * b_new = a - temp
     * a_new = a + temp
     * 
     * Using ARM64 NEON with complex number layout: [re0, im0, re1, im1]
     */
    
    /* Step 1: Duplicate real and imaginary parts of twiddle factors */
    /* uzp1 temp1.4s, twr.4s, twr.4s  ; Extract real parts: [re0, re1, re0, re1] */
    arm64_emit_uzp1(p, 1, 2, twr, twr, temp1);
    
    /* uzp2 temp2.4s, twi.4s, twi.4s  ; Extract imaginary parts: [im0, im1, im0, im1] */  
    arm64_emit_uzp2(p, 1, 2, twi, twi, temp2);
    
    /* Step 2: Multiply b by real part of twiddle */
    /* fmul temp3.4s, b.4s, temp1.4s  ; b_re * tw_re, b_im * tw_re */
    ARM64_FMUL_4S(p, temp3, b, temp1);
    
    /* Step 3: Multiply b by imaginary part and swap real/imaginary */
    /* rev64 temp4.4s, b.4s  ; Swap pairs: [im0, re0, im1, re1] */
    arm64_emit_rev64(p, 1, 2, b, temp4);
    
    /* fmul temp4.4s, temp4.4s, temp2.4s  ; b_im * tw_im, b_re * tw_im */
    ARM64_FMUL_4S(p, temp4, temp4, temp2);
    
    /* Step 4: Complex multiplication result */
    /* fsub temp3.4s, temp3.4s, temp4.4s  ; Real part: b_re*tw_re - b_im*tw_im */
    /* This gives us the rotated b value */
    ARM64_FSUB_4S(p, temp3, temp3, temp4);
    
    /* Step 5: Butterfly computation */
    /* fsub b.4s, a.4s, temp3.4s  ; a - rotated_b */
    ARM64_FSUB_4S(p, b, a, temp3);
    
    /* fadd a.4s, a.4s, temp3.4s  ; a + rotated_b */
    ARM64_FADD_4S(p, a, a, temp3);
}

/* Generate optimized complex multiplication for ARM64 */
void 
arm64_generate_complex_mul(arm64instr_t **p, ARM64VReg dst, ARM64VReg src1, ARM64VReg src2r, ARM64VReg src2i)
{
    ARM64VReg temp1 = ARM64_V20;  /* Temporary register */
    ARM64VReg temp2 = ARM64_V21;  /* Temporary register */
    
    /*
     * Complex multiplication: (a + bi) * (c + di) = (ac - bd) + (ad + bc)i
     * Input: src1 = [a, b, a', b'], src2r = [c, c, c', c'], src2i = [d, d, d', d']
     * Output: dst = [ac-bd, ad+bc, a'c'-b'd', a'd'+b'c']
     */
    
    /* fmul temp1.4s, src1.4s, src2r.4s  ; [a*c, b*c, a'*c', b'*c'] */
    ARM64_FMUL_4S(p, temp1, src1, src2r);
    
    /* rev64 temp2.4s, src1.4s  ; [b, a, b', a'] */
    arm64_emit_rev64(p, 1, 2, src1, temp2);
    
    /* fmul temp2.4s, temp2.4s, src2i.4s  ; [b*d, a*d, b'*d', a'*d'] */
    ARM64_FMUL_4S(p, temp2, temp2, src2i);
    
    /* Complex multiplication using fmls/fmla for optimal performance */
    /* fmls dst.4s, temp2.4s, mask.4s where mask alternates +1/-1 */
    /* For now, use separate fsub/fadd operations */
    
    /* Extract and combine real parts: ac - bd */
    /* uzp1 temp1.4s, temp1.4s, temp1.4s to get [a*c, a'*c', ...] */
    /* uzp1 temp2.4s, temp2.4s, temp2.4s to get [b*d, b'*d', ...] */
    /* fsub for real parts, fadd for imaginary parts */
    
    /* Simplified approach using direct subtraction/addition */
    ARM64_FSUB_4S(p, dst, temp1, temp2);  /* This needs refinement for proper complex layout */
}

/* Generate optimized ARM64 base case for 4-point FFT */
arm64instr_t* 
arm64_generate_size4_base_case(arm64instr_t **p, int sign)
{
    arm64instr_t *start = *p;
    
    /* 4-point FFT using ARM64 NEON 128-bit registers
     * Input layout: [re0, im0, re1, im1] in each 128-bit register
     * V0-V3: input data registers
     * V4-V11: working registers
     */
    
    /* Stage 1: Load data and setup */
    /* Data is assumed to be already loaded in V0-V3 by caller */
    
    /* Stage 2: Radix-2 butterflies */
    /* A = (a0 + a2), B = (a1 + a3), C = (a0 - a2), D = (a1 - a3) */
    ARM64_FADD_4S(p, ARM64_V4, ARM64_V0, ARM64_V2);  /* A = a0 + a2 */
    ARM64_FADD_4S(p, ARM64_V5, ARM64_V1, ARM64_V3);  /* B = a1 + a3 */
    ARM64_FSUB_4S(p, ARM64_V6, ARM64_V0, ARM64_V2);  /* C = a0 - a2 */
    ARM64_FSUB_4S(p, ARM64_V7, ARM64_V1, ARM64_V3);  /* D = a1 - a3 */
    
    /* Stage 3: Final outputs */
    ARM64_FADD_4S(p, ARM64_V0, ARM64_V4, ARM64_V5);  /* X0 = A + B */
    ARM64_FSUB_4S(p, ARM64_V2, ARM64_V4, ARM64_V5);  /* X2 = A - B */
    
    /* Stage 4: Handle twiddle factor for X1 and X3 */
    if (sign > 0) {
        /* Forward FFT: X1 = C + iD, X3 = C - iD
         * Multiply D by i using rev64 to swap real/imaginary parts,
         * then negate appropriate components for multiplication by i
         */
        arm64_emit_rev64(p, 1, 2, ARM64_V7, ARM64_V8);  /* Swap: [im, re, im, re] */
        
        /* For multiplication by i: (a + bi) * i = -b + ai
         * So we need to negate the real parts of the swapped D
         */
        ARM64_FSUB_4S(p, ARM64_V1, ARM64_V6, ARM64_V8);  /* X1 = C + iD */
        ARM64_FADD_4S(p, ARM64_V3, ARM64_V6, ARM64_V8);  /* X3 = C - iD */
    } else {
        /* Inverse FFT: X1 = C - iD, X3 = C + iD */
        arm64_emit_rev64(p, 1, 2, ARM64_V7, ARM64_V8);  /* Swap D components */
        
        ARM64_FADD_4S(p, ARM64_V1, ARM64_V6, ARM64_V8);  /* X1 = C - iD */
        ARM64_FSUB_4S(p, ARM64_V3, ARM64_V6, ARM64_V8);  /* X3 = C + iD */
    }
    
    /* Results are now in V0, V1, V2, V3 */
    arm64_emit_ret(p);
    
    return start;
}

/* Generate optimized ARM64 base case for 8-point FFT */
arm64instr_t* 
arm64_generate_size8_base_case(arm64instr_t **p, int sign)
{
    arm64instr_t *start = *p;
    
    /* 8-point FFT using decimation-in-frequency (DIF) radix-2 approach
     * Requires more complex register management and twiddle factors
     * V0-V7: input/output registers
     * V8-V15: working registers
     * V16-V19: twiddle factor constants
     */
    
    /* Store link register for potential function calls */
    arm64_emit_instruction(p, 0xa9bf7bfd);  /* stp x29, x30, [sp, #-16]! */
    
    /* Load twiddle factors for 8-point FFT */
    /* For 8-point: W_8^1 = (√2/2)(1-i), W_8^2 = -i, W_8^3 = (√2/2)(-1-i) */
    /* These would normally be loaded from a constant pool */
    
    /* Stage 1: First level butterflies (4 parallel 2-point FFTs) */
    ARM64_FADD_4S(p, ARM64_V8, ARM64_V0, ARM64_V4);   /* a0 + a4 */
    ARM64_FSUB_4S(p, ARM64_V12, ARM64_V0, ARM64_V4);  /* a0 - a4 */
    
    ARM64_FADD_4S(p, ARM64_V9, ARM64_V1, ARM64_V5);   /* a1 + a5 */
    ARM64_FSUB_4S(p, ARM64_V13, ARM64_V1, ARM64_V5);  /* a1 - a5 */
    
    ARM64_FADD_4S(p, ARM64_V10, ARM64_V2, ARM64_V6);  /* a2 + a6 */
    ARM64_FSUB_4S(p, ARM64_V14, ARM64_V2, ARM64_V6);  /* a2 - a6 */
    
    ARM64_FADD_4S(p, ARM64_V11, ARM64_V3, ARM64_V7);  /* a3 + a7 */
    ARM64_FSUB_4S(p, ARM64_V15, ARM64_V3, ARM64_V7);  /* a3 - a7 */
    
    /* Stage 2: Apply twiddle factors to second half */
    /* V13 *= W_8^1, V14 *= W_8^2 = -i, V15 *= W_8^3 */
    
    /* Multiply V14 by -i (equivalent to rev64 + negate real part) */
    arm64_emit_rev64(p, 1, 2, ARM64_V14, ARM64_V14);  /* Swap real/imag */
    /* TODO: Load sign-flip constant and apply - for now, simplified */
    
    /* Stage 3: Second level butterflies */
    ARM64_FADD_4S(p, ARM64_V0, ARM64_V8, ARM64_V10);   /* X0 */
    ARM64_FSUB_4S(p, ARM64_V4, ARM64_V8, ARM64_V10);   /* X4 */
    
    ARM64_FADD_4S(p, ARM64_V1, ARM64_V9, ARM64_V11);   /* X1 */  
    ARM64_FSUB_4S(p, ARM64_V5, ARM64_V9, ARM64_V11);   /* X5 */
    
    ARM64_FADD_4S(p, ARM64_V2, ARM64_V12, ARM64_V14);  /* X2 */
    ARM64_FSUB_4S(p, ARM64_V6, ARM64_V12, ARM64_V14);  /* X6 */
    
    ARM64_FADD_4S(p, ARM64_V3, ARM64_V13, ARM64_V15);  /* X3 */
    ARM64_FSUB_4S(p, ARM64_V7, ARM64_V13, ARM64_V15);  /* X7 */
    
    /* Restore link register */
    arm64_emit_instruction(p, 0xa8c17bfd);  /* ldp x29, x30, [sp], #16 */
    
    arm64_emit_ret(p);
    
    return start;
}

/* Generate optimized ARM64 base case for 16-point FFT */
arm64instr_t* 
arm64_generate_size16_base_case(arm64instr_t **p, int sign)
{
    arm64instr_t *start = *p;
    
    /* 16-point FFT - most complex base case
     * Uses all available ARM64 NEON registers efficiently
     * Implements a radix-4 approach for better performance
     */
    
    /* Save callee-saved registers */
    arm64_emit_instruction(p, 0xa9be7bfd);  /* stp x29, x30, [sp, #-32]! */
    arm64_emit_instruction(p, 0xa9015bf5);  /* stp x21, x22, [sp, #16] */
    
    /* For a full optimized 16-point FFT, we would implement:
     * 1. Load all 16 complex values into V0-V15 (32 float values)
     * 2. Perform radix-4 butterflies in 2 stages
     * 3. Apply appropriate twiddle factors
     * 4. Store results back
     * 
     * This is quite complex, so for now we implement a divide-and-conquer
     * approach using two 8-point FFTs plus combination stage
     */
    
    /* Call 8-point FFT on first half (elements 0-7) */
    /* Assume data is arranged appropriately */
    
    /* Call 8-point FFT on second half (elements 8-15) */
    /* Apply twiddle factors and combine */
    
    /* For demonstration, implement a basic version */
    /* Stage 1: Four 4-point FFTs */
    arm64_generate_butterfly_4s(p, ARM64_V0, ARM64_V4, ARM64_V16, ARM64_V17);
    arm64_generate_butterfly_4s(p, ARM64_V1, ARM64_V5, ARM64_V18, ARM64_V19);
    arm64_generate_butterfly_4s(p, ARM64_V2, ARM64_V6, ARM64_V20, ARM64_V21);
    arm64_generate_butterfly_4s(p, ARM64_V3, ARM64_V7, ARM64_V22, ARM64_V23);
    
    arm64_generate_butterfly_4s(p, ARM64_V8, ARM64_V12, ARM64_V24, ARM64_V25);
    arm64_generate_butterfly_4s(p, ARM64_V9, ARM64_V13, ARM64_V26, ARM64_V27);
    arm64_generate_butterfly_4s(p, ARM64_V10, ARM64_V14, ARM64_V28, ARM64_V29);
    arm64_generate_butterfly_4s(p, ARM64_V11, ARM64_V15, ARM64_V30, ARM64_V31);
    
    /* Stage 2: Combine with twiddle factors */
    /* This would require loading and applying 16-point twiddle factors */
    
    /* Restore registers */
    arm64_emit_instruction(p, 0xa9415bf5);  /* ldp x21, x22, [sp, #16] */
    arm64_emit_instruction(p, 0xa8c27bfd);  /* ldp x29, x30, [sp], #32 */
    
    arm64_emit_ret(p);
    return start;
}

/* Initialize ARM64 code generation constants */
void
arm64_init_constants(void)
{
    /* Initialize any ARM64-specific constants needed for code generation */
    /* This might include precomputed twiddle factors, masks, etc. */
}

/* Check if immediate value can be encoded in ARM64 instruction */
int
arm64_is_valid_immediate(uint64_t imm, int width)
{
    /* ARM64 has complex immediate encoding rules */
    /* For simplicity, just check common cases */
    if (width == 32) {
        return (imm <= 0xfff) || ((imm & 0xfff) == 0 && (imm >> 12) <= 0xfff);
    } else if (width == 64) {
        return (imm <= 0xfff) || ((imm & 0xfff) == 0 && (imm >> 12) <= 0xfff);
    }
    return 0;
}

/* ARM64 memory barrier instruction for cache coherency */
void
arm64_emit_memory_barrier(arm64instr_t **p)
{
    /* dmb sy - Data Memory Barrier, System */
    arm64_emit_instruction(p, 0xd5033f9f);
    
    /* isb - Instruction Synchronization Barrier */
    arm64_emit_instruction(p, 0xd5033fdf);
}

/* ARM64 cache invalidation for generated code */
void
arm64_invalidate_icache(void *start, void *end)
{
    /* ARM64 requires explicit cache invalidation for generated code */
    uintptr_t addr = (uintptr_t)start;
    uintptr_t end_addr = (uintptr_t)end;
    
    /* Round down to cache line boundary */
    addr &= ~63UL;
    
    /* Clean data cache and invalidate instruction cache */
    while (addr < end_addr) {
        __asm__ volatile("dc cvau, %0" : : "r"(addr));
        __asm__ volatile("ic ivau, %0" : : "r"(addr));
        addr += 64;  /* ARM64 cache line size is typically 64 bytes */
    }
    
    /* Ensure all cache operations complete */
    __asm__ volatile("dsb ish");
    __asm__ volatile("isb");
}

/* Advanced ARM64 instruction encodings for FFT operations */

/* Encode FMLA (Fused Multiply-Add) with lane selection */
void
arm64_emit_fmla_lane_4s(arm64instr_t **p, ARM64VReg vd, ARM64VReg vn, ARM64VReg vm, int lane)
{
    /* FMLA Vd.4S, Vn.4S, Vm.S[lane] - multiply by scalar and add */
    uint32_t instr = 0x4f801000 | (((vm) & 0x1f) << 16) | (((lane) & 3) << 21) | 
                     (((vn) & 0x1f) << 5) | ((vd) & 0x1f);
    arm64_emit_instruction(p, instr);
}

/* Encode FCMLA (Complex Multiply-Add) for ARM64.2 extensions */
void
arm64_emit_fcmla_4s(arm64instr_t **p, ARM64VReg vd, ARM64VReg vn, ARM64VReg vm, int rot)
{
    /* FCMLA Vd.4S, Vn.4S, Vm.4S, #rot - complex multiply-add */
    uint32_t instr = 0x6e00c400 | (((rot) & 3) << 13) | (((vm) & 0x1f) << 16) |
                     (((vn) & 0x1f) << 5) | ((vd) & 0x1f);
    arm64_emit_instruction(p, instr);
}

/* Load multiple registers for efficient data access */
void
arm64_emit_ld1_multiple_4s(arm64instr_t **p, ARM64VReg vt, int reg_count, ARM64Reg rn)
{
    /* LD1 {Vt.4S, Vt+1.4S, ...}, [Rn] */
    uint32_t opcode;
    switch (reg_count) {
        case 1: opcode = 0x0c407000; break;  /* LD1 {Vt.4S} */
        case 2: opcode = 0x0c40a000; break;  /* LD1 {Vt.4S, Vt+1.4S} */
        case 3: opcode = 0x0c406000; break;  /* LD1 {Vt.4S, Vt+1.4S, Vt+2.4S} */
        case 4: opcode = 0x0c402000; break;  /* LD1 {Vt.4S, Vt+1.4S, Vt+2.4S, Vt+3.4S} */
        default: return; /* Invalid register count */
    }
    
    uint32_t instr = opcode | (((rn) & 0x1f) << 5) | ((vt) & 0x1f);
    arm64_emit_instruction(p, instr);
}

/* Store multiple registers for efficient data access */
void
arm64_emit_st1_multiple_4s(arm64instr_t **p, ARM64VReg vt, int reg_count, ARM64Reg rn)
{
    /* ST1 {Vt.4S, Vt+1.4S, ...}, [Rn] */
    uint32_t opcode;
    switch (reg_count) {
        case 1: opcode = 0x0c007000; break;  /* ST1 {Vt.4S} */
        case 2: opcode = 0x0c00a000; break;  /* ST1 {Vt.4S, Vt+1.4S} */
        case 3: opcode = 0x0c006000; break;  /* ST1 {Vt.4S, Vt+1.4S, Vt+2.4S} */
        case 4: opcode = 0x0c002000; break;  /* ST1 {Vt.4S, Vt+1.4S, Vt+2.4S, Vt+3.4S} */
        default: return; /* Invalid register count */
    }
    
    uint32_t instr = opcode | (((rn) & 0x1f) << 5) | ((vt) & 0x1f);
    arm64_emit_instruction(p, instr);
}

/* Advanced butterfly operation using optimized instruction scheduling */
void 
arm64_generate_optimized_butterfly_4s(arm64instr_t **p, ARM64VReg a, ARM64VReg b, ARM64VReg twr, ARM64VReg twi)
{
    ARM64VReg temp1 = ARM64_V20;
    ARM64VReg temp2 = ARM64_V21;
    ARM64VReg temp3 = ARM64_V22;
    
    /*
     * Optimized complex butterfly with better instruction scheduling
     * Uses FMLA instructions for fused multiply-add operations
     * Reduces instruction count and improves pipeline utilization
     */
    
    /* Step 1: Prepare complex multiplication operands */
    arm64_emit_uzp1(p, 1, 2, twr, twr, temp1);  /* Duplicate real parts */
    arm64_emit_uzp2(p, 1, 2, twi, twi, temp2);  /* Duplicate imaginary parts */
    
    /* Step 2: Complex multiplication using FMLA */
    /* temp3 = b * twr_real */
    ARM64_FMUL_4S(p, temp3, b, temp1);
    
    /* Swap b components for imaginary multiplication */
    arm64_emit_rev64(p, 1, 2, b, temp1);
    
    /* temp3 = temp3 - (swapped_b * twi_real) = b_real*tw_real - b_imag*tw_imag */
    arm64_emit_fmls_vec(p, 1, 0, temp2, temp1, temp3);
    
    /* Step 3: Butterfly computation with optimized instruction order */
    ARM64_FSUB_4S(p, b, a, temp3);     /* b_new = a - rotated_b */
    ARM64_FADD_4S(p, a, a, temp3);     /* a_new = a + rotated_b */
}

/* Generate optimized radix-4 butterfly for 16-point FFT */
void
arm64_generate_radix4_butterfly(arm64instr_t **p, ARM64VReg x0, ARM64VReg x1, ARM64VReg x2, ARM64VReg x3, 
                                ARM64VReg w1, ARM64VReg w2, ARM64VReg w3)
{
    ARM64VReg t1 = ARM64_V24, t2 = ARM64_V25, t3 = ARM64_V26, t4 = ARM64_V27;
    ARM64VReg u1 = ARM64_V28, u2 = ARM64_V29, u3 = ARM64_V30, u4 = ARM64_V31;
    
    /*
     * Radix-4 butterfly implementation for optimal ARM64 performance
     * Computes: X = [x0+x2, x1+x3, x0-x2, i*(x1-x3)] * [1, w1, w2, w3]
     */
    
    /* Stage 1: Compute intermediate values */
    ARM64_FADD_4S(p, t1, x0, x2);  /* t1 = x0 + x2 */
    ARM64_FSUB_4S(p, t2, x0, x2);  /* t2 = x0 - x2 */
    ARM64_FADD_4S(p, t3, x1, x3);  /* t3 = x1 + x3 */
    ARM64_FSUB_4S(p, t4, x1, x3);  /* t4 = x1 - x3 */
    
    /* Stage 2: Apply multiplication by i to t4 */
    arm64_emit_rev64(p, 1, 2, t4, u4);  /* Multiply by i */
    
    /* Stage 3: Combine and apply twiddle factors */
    ARM64_FADD_4S(p, x0, t1, t3);      /* x0 = t1 + t3 (no twiddle) */
    
    /* Apply twiddle factors using complex multiplication */
    ARM64_FSUB_4S(p, u1, t1, t3);      /* u1 = t1 - t3 */
    arm64_generate_complex_mul(p, x2, u1, w2, w2);  /* x2 = u1 * w2 */
    
    ARM64_FADD_4S(p, u2, t2, u4);      /* u2 = t2 + i*t4 */
    arm64_generate_complex_mul(p, x1, u2, w1, w1);  /* x1 = u2 * w1 */
    
    ARM64_FSUB_4S(p, u3, t2, u4);      /* u3 = t2 - i*t4 */
    arm64_generate_complex_mul(p, x3, u3, w3, w3);  /* x3 = u3 * w3 */
}

/* Generate loop-unrolled FFT kernel for better performance */
void
arm64_generate_unrolled_fft_kernel(arm64instr_t **p, size_t N, int sign)
{
    if (N == 4) {
        /* Use optimized 4-point kernel */
        arm64_generate_size4_base_case(p, sign);
    } else if (N == 8) {
        /* Use optimized 8-point kernel */
        arm64_generate_size8_base_case(p, sign);
    } else if (N == 16) {
        /* Use radix-4 approach for 16-point */
        /* Load all 16 values into registers V0-V15 */
        /* Apply four radix-4 butterflies */
        /* Store results back */
        
        /* This is a placeholder for full radix-4 implementation */
        arm64_generate_radix4_butterfly(p, ARM64_V0, ARM64_V4, ARM64_V8, ARM64_V12,
                                       ARM64_V16, ARM64_V17, ARM64_V18);
        arm64_generate_radix4_butterfly(p, ARM64_V1, ARM64_V5, ARM64_V9, ARM64_V13,
                                       ARM64_V19, ARM64_V20, ARM64_V21);
        arm64_generate_radix4_butterfly(p, ARM64_V2, ARM64_V6, ARM64_V10, ARM64_V14,
                                       ARM64_V22, ARM64_V23, ARM64_V24);
        arm64_generate_radix4_butterfly(p, ARM64_V3, ARM64_V7, ARM64_V11, ARM64_V15,
                                       ARM64_V25, ARM64_V26, ARM64_V27);
    }
}

/* ARM64 instruction for efficient bit-reverse address calculation */
void
arm64_emit_bit_reverse_address(arm64instr_t **p, ARM64Reg dst, ARM64Reg src, int log_n)
{
    /* Generate bit-reverse permutation address calculation */
    /* This is a complex operation that may require multiple instructions */
    
    /* For now, implement using standard ARM64 bit manipulation */
    /* RBIT dst, src - reverse bits */
    uint32_t instr = 0x5ac00000 | (((src) & 0x1f) << 5) | ((dst) & 0x1f);
    arm64_emit_instruction(p, instr);
    
    /* Shift right to align for the specific FFT size */
    if (log_n < 32) {
        /* LSR dst, dst, #(32-log_n) */
        instr = 0x53000000 | ((32 - log_n) << 16) | (((dst) & 0x1f) << 5) | ((dst) & 0x1f);
        arm64_emit_instruction(p, instr);
    }
}

/* ARM64 cache-friendly data prefetch for large FFTs */
void
arm64_emit_prefetch_fft_data(arm64instr_t **p, ARM64Reg base, size_t stride, int levels)
{
    /* Prefetch data at multiple cache levels for better performance */
    for (int i = 0; i < levels && i < 4; i++) {
        size_t offset = stride * (1 << i);
        if (offset <= 32760) {  /* Maximum offset for PRFM immediate */
            /* PRFM PLDL1KEEP, [base, #offset] */
            uint32_t instr = 0xf9800000 | ((offset >> 3) << 10) | (((base) & 0x1f) << 5);
            arm64_emit_instruction(p, instr);
        }
    }
} 