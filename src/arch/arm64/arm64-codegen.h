/*
 * arm64-codegen.h: AArch64 (ARM64) code generation macros
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

#ifndef ARM64_CODEGEN_H
#define ARM64_CODEGEN_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

/* AArch64 instruction type */
typedef uint32_t arm64instr_t;

/* AArch64 General Purpose Registers */
typedef enum {
    ARM64_X0 = 0, ARM64_X1, ARM64_X2, ARM64_X3, ARM64_X4, ARM64_X5, ARM64_X6, ARM64_X7,
    ARM64_X8, ARM64_X9, ARM64_X10, ARM64_X11, ARM64_X12, ARM64_X13, ARM64_X14, ARM64_X15,
    ARM64_X16, ARM64_X17, ARM64_X18, ARM64_X19, ARM64_X20, ARM64_X21, ARM64_X22, ARM64_X23,
    ARM64_X24, ARM64_X25, ARM64_X26, ARM64_X27, ARM64_X28, ARM64_X29, ARM64_X30, ARM64_SP = 31,
    
    /* 32-bit register aliases */
    ARM64_W0 = 0, ARM64_W1, ARM64_W2, ARM64_W3, ARM64_W4, ARM64_W5, ARM64_W6, ARM64_W7,
    ARM64_W8, ARM64_W9, ARM64_W10, ARM64_W11, ARM64_W12, ARM64_W13, ARM64_W14, ARM64_W15,
    ARM64_W16, ARM64_W17, ARM64_W18, ARM64_W19, ARM64_W20, ARM64_W21, ARM64_W22, ARM64_W23,
    ARM64_W24, ARM64_W25, ARM64_W26, ARM64_W27, ARM64_W28, ARM64_W29, ARM64_W30, ARM64_WSP = 31,
    
    /* Aliases for common registers */
    ARM64_FP = ARM64_X29,    /* Frame Pointer */
    ARM64_LR = ARM64_X30,    /* Link Register */
    ARM64_XZR = 31           /* Zero Register */
} ARM64Reg;

/* AArch64 SIMD/FP Registers */
typedef enum {
    ARM64_V0 = 0, ARM64_V1, ARM64_V2, ARM64_V3, ARM64_V4, ARM64_V5, ARM64_V6, ARM64_V7,
    ARM64_V8, ARM64_V9, ARM64_V10, ARM64_V11, ARM64_V12, ARM64_V13, ARM64_V14, ARM64_V15,
    ARM64_V16, ARM64_V17, ARM64_V18, ARM64_V19, ARM64_V20, ARM64_V21, ARM64_V22, ARM64_V23,
    ARM64_V24, ARM64_V25, ARM64_V26, ARM64_V27, ARM64_V28, ARM64_V29, ARM64_V30, ARM64_V31,
    
    /* Alternative naming for different lane types */
    ARM64_Q0 = 0, ARM64_Q1, ARM64_Q2, ARM64_Q3, ARM64_Q4, ARM64_Q5, ARM64_Q6, ARM64_Q7,
    ARM64_Q8, ARM64_Q9, ARM64_Q10, ARM64_Q11, ARM64_Q12, ARM64_Q13, ARM64_Q14, ARM64_Q15,
    ARM64_Q16, ARM64_Q17, ARM64_Q18, ARM64_Q19, ARM64_Q20, ARM64_Q21, ARM64_Q22, ARM64_Q23,
    ARM64_Q24, ARM64_Q25, ARM64_Q26, ARM64_Q27, ARM64_Q28, ARM64_Q29, ARM64_Q30, ARM64_Q31,
    
    ARM64_D0 = 0, ARM64_D1, ARM64_D2, ARM64_D3, ARM64_D4, ARM64_D5, ARM64_D6, ARM64_D7,
    ARM64_D8, ARM64_D9, ARM64_D10, ARM64_D11, ARM64_D12, ARM64_D13, ARM64_D14, ARM64_D15,
    ARM64_D16, ARM64_D17, ARM64_D18, ARM64_D19, ARM64_D20, ARM64_D21, ARM64_D22, ARM64_D23,
    ARM64_D24, ARM64_D25, ARM64_D26, ARM64_D27, ARM64_D28, ARM64_D29, ARM64_D30, ARM64_D31,
    
    ARM64_S0 = 0, ARM64_S1, ARM64_S2, ARM64_S3, ARM64_S4, ARM64_S5, ARM64_S6, ARM64_S7,
    ARM64_S8, ARM64_S9, ARM64_S10, ARM64_S11, ARM64_S12, ARM64_S13, ARM64_S14, ARM64_S15,
    ARM64_S16, ARM64_S17, ARM64_S18, ARM64_S19, ARM64_S20, ARM64_S21, ARM64_S22, ARM64_S23,
    ARM64_S24, ARM64_S25, ARM64_S26, ARM64_S27, ARM64_S28, ARM64_S29, ARM64_S30, ARM64_S31
} ARM64VReg;

/* AArch64 Condition Codes */
typedef enum {
    ARM64_CC_EQ = 0x0,    /* Equal */
    ARM64_CC_NE = 0x1,    /* Not equal */
    ARM64_CC_CS = 0x2,    /* Carry set */
    ARM64_CC_CC = 0x3,    /* Carry clear */
    ARM64_CC_MI = 0x4,    /* Minus */
    ARM64_CC_PL = 0x5,    /* Plus */
    ARM64_CC_VS = 0x6,    /* Overflow set */
    ARM64_CC_VC = 0x7,    /* Overflow clear */
    ARM64_CC_HI = 0x8,    /* Higher */
    ARM64_CC_LS = 0x9,    /* Lower or same */
    ARM64_CC_GE = 0xA,    /* Greater or equal */
    ARM64_CC_LT = 0xB,    /* Less than */
    ARM64_CC_GT = 0xC,    /* Greater than */
    ARM64_CC_LE = 0xD,    /* Less or equal */
    ARM64_CC_AL = 0xE,    /* Always */
    ARM64_CC_NV = 0xF     /* Never */
} ARM64CondCode;

/* AArch64 Shift Types */
typedef enum {
    ARM64_SHIFT_LSL = 0,  /* Logical shift left */
    ARM64_SHIFT_LSR = 1,  /* Logical shift right */
    ARM64_SHIFT_ASR = 2,  /* Arithmetic shift right */
    ARM64_SHIFT_ROR = 3   /* Rotate right */
} ARM64ShiftType;

/* AArch64 SIMD Arrangement Specifiers */
typedef enum {
    ARM64_8B = 0,   /* 8 × 8-bit */
    ARM64_16B = 1,  /* 16 × 8-bit */
    ARM64_4H = 2,   /* 4 × 16-bit */
    ARM64_8H = 3,   /* 8 × 16-bit */
    ARM64_2S = 4,   /* 2 × 32-bit */
    ARM64_4S = 5,   /* 4 × 32-bit */
    ARM64_1D = 6,   /* 1 × 64-bit */
    ARM64_2D = 7    /* 2 × 64-bit */
} ARM64Arrangement;

/* Instruction emission helper */
#define ARM64_EMIT(p, instr) do { *(arm64instr_t*)(p) = (arm64instr_t)(instr); (p) = (arm64instr_t*)(p) + 1; } while(0)

/* Basic instruction encoding helpers */

/* Branch instructions */
#define ARM64_B_ENCODE(offset) \
    (0x14000000 | (((offset) >> 2) & 0x3ffffff))

#define ARM64_BL_ENCODE(offset) \
    (0x94000000 | (((offset) >> 2) & 0x3ffffff))

#define ARM64_BR_ENCODE(rn) \
    (0xd61f0000 | ((rn) << 5))

#define ARM64_BLR_ENCODE(rn) \
    (0xd63f0000 | ((rn) << 5))

#define ARM64_RET_ENCODE() \
    (0xd65f03c0)

/* Data processing instructions */
#define ARM64_ADD_IMM_ENCODE(sf, rd, rn, imm12) \
    ((sf) << 31 | 0x11000000 | ((imm12) & 0xfff) << 10 | ((rn) & 0x1f) << 5 | ((rd) & 0x1f))

#define ARM64_SUB_IMM_ENCODE(sf, rd, rn, imm12) \
    ((sf) << 31 | 0x51000000 | ((imm12) & 0xfff) << 10 | ((rn) & 0x1f) << 5 | ((rd) & 0x1f))

#define ARM64_MOV_REG_ENCODE(sf, rd, rm) \
    ((sf) << 31 | 0x2a000000 | ((rm) & 0x1f) << 16 | 0x1f << 5 | ((rd) & 0x1f))

/* Load/Store instructions */
#define ARM64_LDR_IMM_ENCODE(size, rt, rn, imm12) \
    ((size) << 30 | 0x39000000 | ((imm12) & 0xfff) << 10 | ((rn) & 0x1f) << 5 | ((rt) & 0x1f))

#define ARM64_STR_IMM_ENCODE(size, rt, rn, imm12) \
    ((size) << 30 | 0x39000000 | 1 << 22 | ((imm12) & 0xfff) << 10 | ((rn) & 0x1f) << 5 | ((rt) & 0x1f))

/* SIMD Load/Store Pair instructions */
#define ARM64_LDP_SIMD_ENCODE(opc, rt, rt2, rn, imm7) \
    ((opc) << 30 | 0x2d400000 | ((imm7) & 0x7f) << 15 | ((rt2) & 0x1f) << 10 | ((rn) & 0x1f) << 5 | ((rt) & 0x1f))

#define ARM64_STP_SIMD_ENCODE(opc, rt, rt2, rn, imm7) \
    ((opc) << 30 | 0x2d000000 | ((imm7) & 0x7f) << 15 | ((rt2) & 0x1f) << 10 | ((rn) & 0x1f) << 5 | ((rt) & 0x1f))

/* SIMD arithmetic instructions */
#define ARM64_FADD_VEC_ENCODE(q, sz, rm, rn, rd) \
    ((q) << 30 | 0x0e200000 | ((sz) & 1) << 22 | ((rm) & 0x1f) << 16 | 0xd4 << 10 | ((rn) & 0x1f) << 5 | ((rd) & 0x1f))

#define ARM64_FSUB_VEC_ENCODE(q, sz, rm, rn, rd) \
    ((q) << 30 | 0x0ea00000 | ((sz) & 1) << 22 | ((rm) & 0x1f) << 16 | 0xd4 << 10 | ((rn) & 0x1f) << 5 | ((rd) & 0x1f))

#define ARM64_FMUL_VEC_ENCODE(q, sz, rm, rn, rd) \
    ((q) << 30 | 0x2e200000 | ((sz) & 1) << 22 | ((rm) & 0x1f) << 16 | 0xdc << 10 | ((rn) & 0x1f) << 5 | ((rd) & 0x1f))

#define ARM64_FMLA_VEC_ENCODE(q, sz, rm, rn, rd) \
    ((q) << 30 | 0x0e200000 | ((sz) & 1) << 22 | ((rm) & 0x1f) << 16 | 0xcc << 10 | ((rn) & 0x1f) << 5 | ((rd) & 0x1f))

#define ARM64_FMLS_VEC_ENCODE(q, sz, rm, rn, rd) \
    ((q) << 30 | 0x0ea00000 | ((sz) & 1) << 22 | ((rm) & 0x1f) << 16 | 0xcc << 10 | ((rn) & 0x1f) << 5 | ((rd) & 0x1f))

/* SIMD data movement instructions */
#define ARM64_UZP1_ENCODE(q, size, rm, rn, rd) \
    ((q) << 30 | 0x0e000000 | ((size) & 3) << 22 | ((rm) & 0x1f) << 16 | 0x18 << 10 | ((rn) & 0x1f) << 5 | ((rd) & 0x1f))

#define ARM64_UZP2_ENCODE(q, size, rm, rn, rd) \
    ((q) << 30 | 0x0e000000 | ((size) & 3) << 22 | ((rm) & 0x1f) << 16 | 0x58 << 10 | ((rn) & 0x1f) << 5 | ((rd) & 0x1f))

#define ARM64_ZIP1_ENCODE(q, size, rm, rn, rd) \
    ((q) << 30 | 0x0e000000 | ((size) & 3) << 22 | ((rm) & 0x1f) << 16 | 0x38 << 10 | ((rn) & 0x1f) << 5 | ((rd) & 0x1f))

#define ARM64_ZIP2_ENCODE(q, size, rm, rn, rd) \
    ((q) << 30 | 0x0e000000 | ((size) & 3) << 22 | ((rm) & 0x1f) << 16 | 0x78 << 10 | ((rn) & 0x1f) << 5 | ((rd) & 0x1f))

#define ARM64_TRN1_ENCODE(q, size, rm, rn, rd) \
    ((q) << 30 | 0x0e000000 | ((size) & 3) << 22 | ((rm) & 0x1f) << 16 | 0x28 << 10 | ((rn) & 0x1f) << 5 | ((rd) & 0x1f))

#define ARM64_TRN2_ENCODE(q, size, rm, rn, rd) \
    ((q) << 30 | 0x0e000000 | ((size) & 3) << 22 | ((rm) & 0x1f) << 16 | 0x68 << 10 | ((rn) & 0x1f) << 5 | ((rd) & 0x1f))

#define ARM64_REV64_ENCODE(q, size, rn, rd) \
    ((q) << 30 | 0x0e200000 | ((size) & 3) << 22 | 0x00 << 16 | 0x08 << 10 | ((rn) & 0x1f) << 5 | ((rd) & 0x1f))

/* High-level instruction generation macros */

/* Emit ARM64 instruction */
static inline void
arm64_emit_instruction(arm64instr_t **p, arm64instr_t instr)
{
    **p = instr;
    (*p)++;
}

/* Branch instructions */
static inline void
arm64_emit_b(arm64instr_t **p, int32_t offset)
{
    arm64_emit_instruction(p, ARM64_B_ENCODE(offset));
}

static inline void
arm64_emit_bl(arm64instr_t **p, int32_t offset)
{
    arm64_emit_instruction(p, ARM64_BL_ENCODE(offset));
}

static inline void
arm64_emit_br(arm64instr_t **p, ARM64Reg rn)
{
    arm64_emit_instruction(p, ARM64_BR_ENCODE(rn));
}

static inline void
arm64_emit_blr(arm64instr_t **p, ARM64Reg rn)
{
    arm64_emit_instruction(p, ARM64_BLR_ENCODE(rn));
}

static inline void
arm64_emit_ret(arm64instr_t **p)
{
    arm64_emit_instruction(p, ARM64_RET_ENCODE());
}

/* Data processing instructions */
static inline void
arm64_emit_add_imm(arm64instr_t **p, int sf, ARM64Reg rd, ARM64Reg rn, uint32_t imm12)
{
    arm64_emit_instruction(p, ARM64_ADD_IMM_ENCODE(sf, rd, rn, imm12));
}

static inline void
arm64_emit_sub_imm(arm64instr_t **p, int sf, ARM64Reg rd, ARM64Reg rn, uint32_t imm12)
{
    arm64_emit_instruction(p, ARM64_SUB_IMM_ENCODE(sf, rd, rn, imm12));
}

static inline void
arm64_emit_mov_reg(arm64instr_t **p, int sf, ARM64Reg rd, ARM64Reg rm)
{
    arm64_emit_instruction(p, ARM64_MOV_REG_ENCODE(sf, rd, rm));
}

/* SIMD Load/Store pair instructions */
static inline void
arm64_emit_ldp_simd(arm64instr_t **p, int opc, ARM64VReg rt, ARM64VReg rt2, ARM64Reg rn, int32_t imm7)
{
    arm64_emit_instruction(p, ARM64_LDP_SIMD_ENCODE(opc, rt, rt2, rn, imm7));
}

static inline void
arm64_emit_stp_simd(arm64instr_t **p, int opc, ARM64VReg rt, ARM64VReg rt2, ARM64Reg rn, int32_t imm7)
{
    arm64_emit_instruction(p, ARM64_STP_SIMD_ENCODE(opc, rt, rt2, rn, imm7));
}

/* SIMD arithmetic instructions */
static inline void
arm64_emit_fadd_vec(arm64instr_t **p, int q, int sz, ARM64VReg rm, ARM64VReg rn, ARM64VReg rd)
{
    arm64_emit_instruction(p, ARM64_FADD_VEC_ENCODE(q, sz, rm, rn, rd));
}

static inline void
arm64_emit_fsub_vec(arm64instr_t **p, int q, int sz, ARM64VReg rm, ARM64VReg rn, ARM64VReg rd)
{
    arm64_emit_instruction(p, ARM64_FSUB_VEC_ENCODE(q, sz, rm, rn, rd));
}

static inline void
arm64_emit_fmul_vec(arm64instr_t **p, int q, int sz, ARM64VReg rm, ARM64VReg rn, ARM64VReg rd)
{
    arm64_emit_instruction(p, ARM64_FMUL_VEC_ENCODE(q, sz, rm, rn, rd));
}

static inline void
arm64_emit_fmla_vec(arm64instr_t **p, int q, int sz, ARM64VReg rm, ARM64VReg rn, ARM64VReg rd)
{
    arm64_emit_instruction(p, ARM64_FMLA_VEC_ENCODE(q, sz, rm, rn, rd));
}

static inline void
arm64_emit_fmls_vec(arm64instr_t **p, int q, int sz, ARM64VReg rm, ARM64VReg rn, ARM64VReg rd)
{
    arm64_emit_instruction(p, ARM64_FMLS_VEC_ENCODE(q, sz, rm, rn, rd));
}

/* SIMD data movement instructions */
static inline void
arm64_emit_uzp1(arm64instr_t **p, int q, int size, ARM64VReg rm, ARM64VReg rn, ARM64VReg rd)
{
    arm64_emit_instruction(p, ARM64_UZP1_ENCODE(q, size, rm, rn, rd));
}

static inline void
arm64_emit_uzp2(arm64instr_t **p, int q, int size, ARM64VReg rm, ARM64VReg rn, ARM64VReg rd)
{
    arm64_emit_instruction(p, ARM64_UZP2_ENCODE(q, size, rm, rn, rd));
}

static inline void
arm64_emit_zip1(arm64instr_t **p, int q, int size, ARM64VReg rm, ARM64VReg rn, ARM64VReg rd)
{
    arm64_emit_instruction(p, ARM64_ZIP1_ENCODE(q, size, rm, rn, rd));
}

static inline void
arm64_emit_zip2(arm64instr_t **p, int q, int size, ARM64VReg rm, ARM64VReg rn, ARM64VReg rd)
{
    arm64_emit_instruction(p, ARM64_ZIP2_ENCODE(q, size, rm, rn, rd));
}

static inline void
arm64_emit_trn1(arm64instr_t **p, int q, int size, ARM64VReg rm, ARM64VReg rn, ARM64VReg rd)
{
    arm64_emit_instruction(p, ARM64_TRN1_ENCODE(q, size, rm, rn, rd));
}

static inline void
arm64_emit_trn2(arm64instr_t **p, int q, int size, ARM64VReg rm, ARM64VReg rn, ARM64VReg rd)
{
    arm64_emit_instruction(p, ARM64_TRN2_ENCODE(q, size, rm, rn, rd));
}

static inline void
arm64_emit_rev64(arm64instr_t **p, int q, int size, ARM64VReg rn, ARM64VReg rd)
{
    arm64_emit_instruction(p, ARM64_REV64_ENCODE(q, size, rn, rd));
}

/* Helper macros for common instruction patterns */

/* 128-bit SIMD operations (Q=1, 4×32-bit float) */
#define ARM64_FADD_4S(p, rd, rn, rm) arm64_emit_fadd_vec(p, 1, 0, rm, rn, rd)
#define ARM64_FSUB_4S(p, rd, rn, rm) arm64_emit_fsub_vec(p, 1, 0, rm, rn, rd)
#define ARM64_FMUL_4S(p, rd, rn, rm) arm64_emit_fmul_vec(p, 1, 0, rm, rn, rd)
#define ARM64_FMLA_4S(p, rd, rn, rm) arm64_emit_fmla_vec(p, 1, 0, rm, rn, rd)
#define ARM64_FMLS_4S(p, rd, rn, rm) arm64_emit_fmls_vec(p, 1, 0, rm, rn, rd)

/* 128-bit load/store pair (128-bit registers) */
#define ARM64_LDP_Q(p, rt, rt2, rn, imm) arm64_emit_ldp_simd(p, 2, rt, rt2, rn, imm)
#define ARM64_STP_Q(p, rt, rt2, rn, imm) arm64_emit_stp_simd(p, 2, rt, rt2, rn, imm)

/* 64-bit operations */
#define ARM64_ADD_X(p, rd, rn, imm) arm64_emit_add_imm(p, 1, rd, rn, imm)
#define ARM64_SUB_X(p, rd, rn, imm) arm64_emit_sub_imm(p, 1, rd, rn, imm)
#define ARM64_MOV_X(p, rd, rm) arm64_emit_mov_reg(p, 1, rd, rm)

/* Function prototypes for FFT-specific operations */
void arm64_generate_butterfly_4s(arm64instr_t **p, ARM64VReg a, ARM64VReg b, ARM64VReg twr, ARM64VReg twi);
void arm64_generate_complex_mul(arm64instr_t **p, ARM64VReg dst, ARM64VReg src1, ARM64VReg src2r, ARM64VReg src2i);
void arm64_generate_prologue(arm64instr_t **p, ARM64Reg data_ptr, ARM64Reg lut_ptr);
void arm64_generate_epilogue(arm64instr_t **p);

/* Base case generators */
arm64instr_t* arm64_generate_size4_base_case(arm64instr_t **p, int sign);
arm64instr_t* arm64_generate_size8_base_case(arm64instr_t **p, int sign);
arm64instr_t* arm64_generate_size16_base_case(arm64instr_t **p, int sign);

/* Utility functions */
void arm64_init_constants(void);
int arm64_is_valid_immediate(uint64_t imm, int width);
void arm64_emit_memory_barrier(arm64instr_t **p);
void arm64_invalidate_icache(void *start, void *end);

/* Advanced ARM64 instruction encodings */
void arm64_emit_fmla_lane_4s(arm64instr_t **p, ARM64VReg vd, ARM64VReg vn, ARM64VReg vm, int lane);
void arm64_emit_fcmla_4s(arm64instr_t **p, ARM64VReg vd, ARM64VReg vn, ARM64VReg vm, int rot);
void arm64_emit_ld1_multiple_4s(arm64instr_t **p, ARM64VReg vt, int reg_count, ARM64Reg rn);
void arm64_emit_st1_multiple_4s(arm64instr_t **p, ARM64VReg vt, int reg_count, ARM64Reg rn);

/* Advanced FFT operations */
void arm64_generate_optimized_butterfly_4s(arm64instr_t **p, ARM64VReg a, ARM64VReg b, ARM64VReg twr, ARM64VReg twi);
void arm64_generate_radix4_butterfly(arm64instr_t **p, ARM64VReg x0, ARM64VReg x1, ARM64VReg x2, ARM64VReg x3, 
                                    ARM64VReg w1, ARM64VReg w2, ARM64VReg w3);
void arm64_generate_unrolled_fft_kernel(arm64instr_t **p, size_t N, int sign);

/* ARM64 utility functions */
void arm64_emit_bit_reverse_address(arm64instr_t **p, ARM64Reg dst, ARM64Reg src, int log_n);
void arm64_emit_prefetch_fft_data(arm64instr_t **p, ARM64Reg base, size_t stride, int levels);

#ifdef __cplusplus
}
#endif

#endif /* ARM64_CODEGEN_H */


