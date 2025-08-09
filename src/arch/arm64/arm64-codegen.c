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
#include "codegen_arm64_macros.h"

#ifdef HAVE_STRING_H
#include <string.h>
#endif

/* ARM64 FFT Constants - forward transform */
const float arm64_neon_constants[] = {
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
const float arm64_neon_constants_inv[] = {
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
    ARM64VReg t_re = ARM64_V20;
    ARM64VReg t_im = ARM64_V21;
    ARM64VReg swap = ARM64_V22;
    /* re = src1 * src2r */
    ARM64_FMUL_4S(p, t_re, src1, src2r);
    /* swap = rev64(src1) -> [i0,r0,i1,r1] */
    arm64_emit_rev64(p, 1, 2, src1, swap);
    /* im = swap * src2i */
    ARM64_FMUL_4S(p, t_im, swap, src2i);
    /* dst = re - im (interleaved form preserved) */
    ARM64_FSUB_4S(p, dst, t_re, t_im);
}

/* Generate optimized ARM64 base case for 4-point FFT */
arm64instr_t* 
arm64_generate_size4_base_case(arm64instr_t **p, int sign)
{
    /* Reuse the hand-written assembly blob from neon64.s.  The code region
     * starts at the symbol neon64_x4 and ends at neon64_x8 (the beginning of
     * the next kernel).  We simply copy the bytes into the output stream and
     * return the address such that the run-time code generator can branch to
     * it later. */
    extern const uint8_t neon64_x4[];
    extern const uint8_t neon64_x8[];

    return (arm64instr_t*)arm64_copy_blob((uint32_t**)p, neon64_x4, neon64_x8);
}

/* Generate optimized ARM64 base case for 8-point FFT */
arm64instr_t* 
arm64_generate_size8_base_case(arm64instr_t **p, int sign)
{
    /* Copy ONLY the size-8 kernel body. The specialised twiddle-stage
     * kernel (neon64_x8_t) is emitted separately by the caller when needed.
     * Copying past x8_t previously pulled in unrelated code and risked
     * invalid fall-throughs / patch indices mismatches. */
    extern const uint8_t neon64_x8[];
    extern const uint8_t neon64_x8_t[];

    uint32_t *dst = arm64_copy_blob((uint32_t**)p,
                                     neon64_x8,
                                     neon64_x8_t);
    arm64_patch_neon64_x8_t(dst, sign); /* keep legacy sign flips aligned */
    return (arm64instr_t*)dst;
}

/* Generate optimized ARM64 base case for 16-point FFT */
arm64instr_t* 
arm64_generate_size16_base_case(arm64instr_t **p, int sign)
{
    arm64instr_t *start = *p;
    
    /* NOTE: This placeholder kernel does not save callee-saved vector registers. */
    /* Save a small GPR frame to match call/return and keep stack aligned */
    arm64_emit_instruction(p, 0xa9be7bfd);  /* stp x29, x30, [sp, #-32]! */
    arm64_emit_instruction(p, 0xa9015bf5);  /* stp x21, x22, [sp, #16] */

    /* TODO: Implement full radix-4 kernel; avoid incorrect ±i math here. */

    arm64_emit_instruction(p, 0xa9415bf5);  /* ldp x21, x22, [sp, #16] */
    arm64_emit_instruction(p, 0xa8c27bfd);  /* ldp x29, x30, [sp], #32 */
    arm64_emit_ret(p);
    return start;
}

/* ARM64 std prologue/epilogue with local stack allocation (parity with ARM32) */
void
arm64_emit_std_prologue(arm64instr_t **p, unsigned int local_size)
{
    /* stp x29, x30, [sp, #-16]! */
    arm64_emit_instruction(p, 0xa9bf7bfd);
    /* mov x29, sp */
    arm64_emit_instruction(p, 0x910003fd);
    /* Allocate local_size bytes if non-zero, using 12-bit immediate chunks */
    unsigned int remaining = local_size;
    while (remaining) {
        unsigned int chunk = remaining > 0xfff ? 0xfff : remaining;
        /* sub sp, sp, #chunk */
        arm64_emit_sub_imm(p, 1, ARM64_SP, ARM64_SP, chunk);
        remaining -= chunk;
    }
}

void
arm64_emit_std_epilogue(arm64instr_t **p, unsigned int local_size)
{
    /* Deallocate locals in 12-bit chunks: add sp, sp, #chunk */
    unsigned int remaining = local_size;
    while (remaining) {
        unsigned int chunk = remaining > 0xfff ? 0xfff : remaining;
        arm64_emit_add_imm(p, 1, ARM64_SP, ARM64_SP, chunk);
        remaining -= chunk;
    }
    /* ldp x29, x30, [sp], #16 */
    arm64_emit_instruction(p, 0xa8c17bfd);
    /* ret */
    arm64_emit_ret(p);
}

void
arm64_emit_lean_prologue(arm64instr_t **p, unsigned int local_size, uint32_t push_mask)
{
    /* Save a subset of callee-saved x19-x29 according to push_mask bits 19..29 */
    /* For simplicity save x19-x22 as a block if any of them requested */
    if (push_mask & ((1u<<19)|(1u<<20)|(1u<<21)|(1u<<22))) {
        /* stp x19, x20, [sp, #-16]! */
        arm64_emit_instruction(p, 0xa9bf53f3);
        /* stp x21, x22, [sp, #-16]! */
        arm64_emit_instruction(p, 0xa9bf5bf5);
    }
    /* Allocate locals */
    unsigned int remaining = local_size;
    while (remaining) {
        unsigned int chunk = remaining > 0xfff ? 0xfff : remaining;
        arm64_emit_sub_imm(p, 1, ARM64_SP, ARM64_SP, chunk);
        remaining -= chunk;
    }
}

/* Bit operations and constants */
int
arm64_bsf_u64(uint64_t val)
{
    if (val == 0) return 0;
    /* count trailing zeros using builtin */
#if defined(__GNUC__)
    return __builtin_ctzll(val) + 1;
#else
    /* Fallback: loop */
    int i = 1; uint64_t mask = 1;
    while ((i <= 64) && ((val & mask) == 0)) { ++i; mask <<= 1; }
    return i;
#endif
}

int
arm64_is_power_of_2_u64(uint64_t val)
{
    return val && ((val & (val - 1)) == 0);
}

int
arm64_const_movk_steps(uint64_t imm)
{
    /* Count distinct 16-bit halfwords needed to materialize with MOVZ/MOVK */
    int steps = 0;
    for (int i = 0; i < 4; ++i) {
        if (((imm >> (i * 16)) & 0xffffu) != 0) steps++;
    }
    if (steps == 0) steps = 1; /* MOVZ #0 */
    return steps;
}

arm64_imm_classes_t
arm64_classify_immediate(uint64_t imm, int width)
{
    arm64_imm_classes_t r = {0, 0};
    /* ADD/SUB: 12-bit immediate, optional left shift by 12 */
    uint64_t mask12 = (1u << 12) - 1u;
    if (((imm & ~mask12) == 0) || (((imm & ~((uint64_t)mask12 << 12)) == 0) && (imm & mask12) == 0)) {
        r.is_addsub_imm = 1;
    }
    /* Logical-immediate: complex; omit full check for now (caller should prefer MOVZ/MOVK) */
    r.is_logical_imm = 0;
    (void)width;
    return r;
}

/* Correct bit-reverse address emission for 64-bit */
void
arm64_emit_bit_reverse_address(arm64instr_t **p, ARM64Reg dst, ARM64Reg src, int log_n)
{
    /* RBIT Xd, Xn: 64-bit reverse bits: opcode 0xDAC00000 | (Xn<<5) | Xd */
    uint32_t rbit = 0xDAC00000 | (((src) & 0x1f) << 5) | ((dst) & 0x1f);
    arm64_emit_instruction(p, rbit);
    /* Logical shift right by (64 - log_n): use UBFM Xd, Xd, immr=(64-log_n), imms=63 */
    int sh = 64 - (log_n & 63);
    if (sh < 0) sh = 0;
    uint32_t ubfm = 0xD3400000 | (((sh) & 0x3f) << 16) | (63 << 10) | (((dst) & 0x1f) << 5) | ((dst) & 0x1f);
    arm64_emit_instruction(p, ubfm);
}

/* ARM64-specific helpers */
void
arm64_init_constants(void)
{
    /* Empty */
}

int
arm64_is_valid_immediate(uint64_t imm, int width)
{
    /* This bears no relation to any AArch64 immediate class (neither MOVZ/MOVN/MOVK assembly of 16-bit halves nor logical-immediate bitmask patterns). As a validator, it's incorrect and misleading. */
    (void)imm; (void)width;
    return 0;
}

void
arm64_emit_memory_barrier(arm64instr_t **p)
{
    /* dmb sy - Data Memory Barrier, System */
    arm64_emit_instruction(p, 0xd5033f9f);
    
    /* isb - Instruction Synchronization Barrier */
    arm64_emit_instruction(p, 0xd5033fdf);
}

void
arm64_invalidate_icache(void *start, void *end)
{
    /* CPU cache maintenance for generated code regions */
    uintptr_t addr = (uintptr_t)start;
    uintptr_t end_addr = (uintptr_t)end;
    addr &= ~63UL;
    while (addr < end_addr) {
        __asm__ volatile("dc cvau, %0" : : "r"(addr));
        __asm__ volatile("ic ivau, %0" : : "r"(addr));
        addr += 64;
    }
    __asm__ volatile("dsb ish");
    __asm__ volatile("isb");
}

void
arm64_emit_fmla_lane_4s(arm64instr_t **p, ARM64VReg dst, ARM64VReg src1, ARM64VReg src2, int lane)
{
    /* Manual encoding of FMLA (lane) */
    uint32_t op = 0x9E200000 | (lane << 12) | (src2 << 16) | (src1 << 5) | dst;
    arm64_emit_instruction(p, op);
}

void
arm64_emit_fcmla_4s(arm64instr_t **p, ARM64VReg dst, ARM64VReg src1, ARM64VReg src2, int lane)
{
    /* Manual encoding of FCMLA (lane) */
    uint32_t op = 0x9E600000 | (lane << 12) | (src2 << 16) | (src1 << 5) | dst;
    arm64_emit_instruction(p, op);
}

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

void
arm64_generate_optimized_butterfly_4s(arm64instr_t **p, ARM64VReg a, ARM64VReg b, ARM64VReg twr, ARM64VReg twi)
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

void
arm64_generate_radix4_butterfly(arm64instr_t **p, ARM64VReg x0, ARM64VReg x1, ARM64VReg x2, ARM64VReg x3,
                                ARM64VReg w1, ARM64VReg w2, ARM64VReg w3)
{
    /* Placeholder: wiring kept for API compatibility; full implementation TBD */
    (void)p; (void)x0; (void)x1; (void)x2; (void)x3; (void)w1; (void)w2; (void)w3;
}

void
arm64_generate_unrolled_fft_kernel(arm64instr_t **p, size_t N, int sign)
{
    if (N == 4) {
        arm64_generate_size4_base_case(p, sign);
    } else if (N == 8) {
        arm64_generate_size8_base_case(p, sign);
    } else {
        /* Not implemented */
    }
}
    
