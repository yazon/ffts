/*

 This file is part of FFTS -- The Fastest Fourier Transform in the South

 Copyright (c) 2012, Anthony M. Blake <amb@anthonix.com>
 Copyright (c) 2012, The University of Waikato

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

#include "codegen.h"
#include "macros.h"

#if defined(HAVE_ARM64) && defined(__aarch64__)
/* Use 32-bit instructions for ARM64 */
typedef uint32_t insns_t;
#elif defined(__arm__)
typedef uint32_t insns_t;
#else
typedef uint8_t insns_t;
#endif

#if defined(HAVE_ARM64) && defined(__aarch64__)
#include "codegen_arm64.h"
#include "ffts_runtime_arm64.h"
#elif defined(HAVE_NEON)
#include "codegen_arm.h"
#include "neon.h"
#elif HAVE_VFP
#include "vfp.h"
#include "codegen_arm.h"
#else
#include "codegen_sse.h"
#endif

#include <assert.h>
#include <errno.h>
#include <stddef.h>
/* #include <stdio.h> */
#include <stdint.h>

#ifdef HAVE_STDLIB_H
#include <stdlib.h>
#endif

#ifdef HAVE_STRING_H
#include <string.h>
#endif

#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif

static int ffts_tree_count(int N, int leaf_N, int offset)
{
    int count;

    if (N <= leaf_N) {
        return 0;
    }

    count  = ffts_tree_count(N/4, leaf_N, offset);
    count += ffts_tree_count(N/8, leaf_N, offset + N/4);
    count += ffts_tree_count(N/8, leaf_N, offset + N/4 + N/8);
    count += ffts_tree_count(N/4, leaf_N, offset + N/2);
    count += ffts_tree_count(N/4, leaf_N, offset + 3*N/4);

    return 1 + count;
}

static void ffts_elaborate_tree(size_t **p, int N, int leaf_N, int offset)
{
    if (N <= leaf_N) {
        return;
    }

    ffts_elaborate_tree(p, N/4, leaf_N, offset);
    ffts_elaborate_tree(p, N/8, leaf_N, offset + N/4);
    ffts_elaborate_tree(p, N/8, leaf_N, offset + N/4 + N/8);
    ffts_elaborate_tree(p, N/4, leaf_N, offset + N/2);
    ffts_elaborate_tree(p, N/4, leaf_N, offset + 3*N/4);

    (*p)[0] = N;
    (*p)[1] = 2 * offset;

    (*p) += 2;
}

transform_func_t ffts_generate_func_code(ffts_plan_t *p, size_t N, size_t leaf_N, int sign)
{
    uint32_t offsets[8] = {0, 4*N, 2*N, 6*N, N, 5*N, 7*N, 3*N};
    uint32_t offsets_o[8] = {0, 4*N, 2*N, 6*N, 7*N, 3*N, N, 5*N};

    int32_t pAddr = 0;
    int32_t pN = 0;
    int32_t pLUT = 0;

    insns_t  *fp;
    insns_t  *start;
    insns_t  *x_4_addr;
    insns_t  *x_8_addr;
    uint32_t  loop_count;

    int       count;
    ptrdiff_t len;

    size_t   *ps;
    size_t   *pps;

    count = ffts_tree_count(N, leaf_N, 0) + 1;

    ps = pps = malloc(2 * count * sizeof(*ps));
    if (!ps) {
        return NULL;
    }

    ffts_elaborate_tree(&pps, N, leaf_N, 0);

    pps[0] = 0;
    pps[1] = 0;

    pps = ps;

#ifdef HAVE_SSE
    if (sign < 0) {
        p->constants = (const void*) sse_constants;
    } else {
        p->constants = (const void*) sse_constants_inv;
    }
#elif defined(__aarch64__) || defined(_M_ARM64)
    if (sign < 0) {
        p->constants = (const void*) arm64_neon_constants;
    } else {
        p->constants = (const void*) arm64_neon_constants_inv;
    }
#endif

    fp = (insns_t*) p->transform_base;

    /* generate base cases */
#if defined(HAVE_ARM64) && defined(__aarch64__)
    x_4_addr = (insns_t*)generate_size4_base_case_arm64((ffts_insn_t**)&fp, sign);
    x_8_addr = (insns_t*)generate_size8_base_case_arm64((ffts_insn_t**)&fp, sign);
#else
    x_4_addr = generate_size4_base_case(&fp, sign);
    x_8_addr = generate_size8_base_case(&fp, sign);
#endif

#ifdef __arm__
    start = generate_prologue(&fp, p);

#ifdef HAVE_NEON
    /* Optional: ARM32 minimal GPR snapshot to plan->buf for diagnostics */
    do {
        const char *dbg = getenv("FFTS_DEBUG_BUF");
        if (dbg && *dbg) {
            /* r0 holds plan; compute &p->buf into r2, load, and if nonzero store r0(out), r12(offsets), and first two off2 */
            /* r2 = r0 + offsetof(buf) */
            ADDI((uint32_t**)&fp, 2, 0, (int32_t)offsetof(struct _ffts_plan_t, buf));
            /* r2 = [r2] */
            *fp++ = LDRI(2, 2, 0);
            /* cmp r2, #0 ; beq skip (+8 insns ahead) */
            *fp++ = 0xe3520000; /* cmp r2, #0 */
            *fp++ = 0x0a000008; /* beq +8 */
            /* str r0, [r2,#0] */
            *fp++ = 0xe5820000;
            /* str r12,[r2,#4] */
            *fp++ = 0xe582c004;
            /* r3 = [r12,#0] ; r4 = [r12,#4] */
            *fp++ = 0xe59c3000;
            *fp++ = 0xe59c4004;
            /* str r3,[r2,#8] ; str r4,[r2,#12] */
            *fp++ = 0xe5823008;
            *fp++ = 0xe5824010;
        }
    } while (0);

    memcpy(fp, neon_ee, neon_oo - neon_ee);
    if (sign < 0) {
        fp[33] ^= 0x00200000;
        fp[37] ^= 0x00200000;
        fp[38] ^= 0x00200000;
        fp[39] ^= 0x00200000;
        fp[40] ^= 0x00200000;
        fp[41] ^= 0x00200000;
        fp[44] ^= 0x00200000;
        fp[45] ^= 0x00200000;
        fp[46] ^= 0x00200000;
        fp[47] ^= 0x00200000;
        fp[48] ^= 0x00200000;
        fp[57] ^= 0x00200000;
    }

    fp += (neon_oo - neon_ee) / 4;
#else
    memcpy(fp, vfp_e, vfp_o - vfp_e);

    if (sign > 0) {
        fp[64] ^= 0x00000040;
        fp[65] ^= 0x00000040;
        fp[68] ^= 0x00000040;
        fp[75] ^= 0x00000040;
        fp[76] ^= 0x00000040;
        fp[79] ^= 0x00000040;
        fp[80] ^= 0x00000040;
        fp[83] ^= 0x00000040;
        fp[84] ^= 0x00000040;
        fp[87] ^= 0x00000040;
        fp[91] ^= 0x00000040;
        fp[93] ^= 0x00000040;
    }
    fp += (vfp_o - vfp_e) / 4;
#endif
#elif defined(HAVE_ARM64) && defined(__aarch64__)
    /* ARM64 code generation path */
    start = (insns_t*)generate_prologue_arm64((ffts_insn_t**)&fp, p);

    /* Ensure X2 holds p->ws base (twiddle base), X1 will be used for stride bytes per base-case */
    ARM64_LDRI_X((ffts_insn_t**)&fp, ARM64_X2, ARM64_X19, (uint32_t)offsetof(struct _ffts_plan_t, ws));

    loop_count = p->i0;
    /* ee/oo leaves use x11 as loop counter */
    generate_leaf_init_arm64((ffts_insn_t**)&fp, loop_count);


    /* Optional: stage ws base diagnostic for N=32 */
    do {
        const char *dbg_ws = getenv("FFTS_DEBUG_STAGE_WS");
        if (dbg_ws && *dbg_ws && N == 32) {
            /* Store stage0 and stage1 twiddle bases and return */
            ARM64_LDRI_X((ffts_insn_t**)&fp, ARM64_X20, ARM64_X19, (uint32_t)offsetof(struct _ffts_plan_t, buf));
            /* stage0: ws base in X2 -> buf+80 */
            arm64_emit_instruction((ffts_insn_t**)&fp, ARM64_STR_X_UOFF(ARM64_X2, ARM64_X20, 10 /*80/8*/));
            /* stage1: load ws_is[1], compute ws + 8*ws_is[1] into X21, store at buf+96 */
            ARM64_LDRI_X((ffts_insn_t**)&fp, ARM64_X21, ARM64_X19, (uint32_t)offsetof(struct _ffts_plan_t, ws_is));
            /* LDR X22, [X21, #8] -> ws_is[1] (size_t on AArch64) */
            arm64_emit_instruction((ffts_insn_t**)&fp, ARM64_LDR_X_UOFF(ARM64_X22, ARM64_X21, 1 /*8/8*/));
            /* ADD X21, X2, X22, LSL #3 => ws + 8*ws_is[1] */
            arm64_emit_add_shifted_reg((ffts_insn_t**)&fp, ARM64_X21, ARM64_X2, ARM64_X22, ARM64_SHIFT_LSL, 2);
            arm64_emit_instruction((ffts_insn_t**)&fp, ARM64_STR_X_UOFF(ARM64_X21, ARM64_X20, 12 /*96/8*/));
            generate_epilogue_arm64((ffts_insn_t**)&fp);
        }
    } while (0);

    /* Optional: debug leaf prelude for N=32 (disabled for now) */
    do {
        const char *dbg_leaf = getenv("FFTS_DEBUG_LEAF");
        if (dbg_leaf && *dbg_leaf && N == 32) {
            /* Load plan->buf into x20 */
            ARM64_LDRI_X((ffts_insn_t**)&fp, ARM64_X20, ARM64_X19, (uint32_t)offsetof(struct _ffts_plan_t, buf));
            /* Store x3..x10 at buf + 0,8,...,56 (imm is scaled by 8 bytes) */
            arm64_emit_instruction((ffts_insn_t**)&fp, ARM64_STR_X_UOFF(ARM64_X3,  ARM64_X20, 0));
            arm64_emit_instruction((ffts_insn_t**)&fp, ARM64_STR_X_UOFF(ARM64_X4,  ARM64_X20, 1));
            arm64_emit_instruction((ffts_insn_t**)&fp, ARM64_STR_X_UOFF(ARM64_X5,  ARM64_X20, 2));
            arm64_emit_instruction((ffts_insn_t**)&fp, ARM64_STR_X_UOFF(ARM64_X6,  ARM64_X20, 3));
            arm64_emit_instruction((ffts_insn_t**)&fp, ARM64_STR_X_UOFF(ARM64_X7,  ARM64_X20, 4));
            arm64_emit_instruction((ffts_insn_t**)&fp, ARM64_STR_X_UOFF(ARM64_X8,  ARM64_X20, 5));
            arm64_emit_instruction((ffts_insn_t**)&fp, ARM64_STR_X_UOFF(ARM64_X9,  ARM64_X20, 6));
            arm64_emit_instruction((ffts_insn_t**)&fp, ARM64_STR_X_UOFF(ARM64_X10, ARM64_X20, 7));
            /* Store x12 (plan->offsets) at buf+64 (imm = 64/8 = 8) */
            arm64_emit_instruction((ffts_insn_t**)&fp, ARM64_STR_X_UOFF(ARM64_X12, ARM64_X20, 8));
            /* Load first two 32-bit off2 values from plan->offsets and store at buf+72, buf+76 */
            arm64_emit_instruction((ffts_insn_t**)&fp, ARM64_LDR_W_UOFF(21 /*W21*/, ARM64_X12, 0));
            arm64_emit_instruction((ffts_insn_t**)&fp, ARM64_STR_W_UOFF(21 /*W21*/, ARM64_X20, 18 /*72/4*/));
            arm64_emit_instruction((ffts_insn_t**)&fp, ARM64_LDR_W_UOFF(21 /*W21*/, ARM64_X12, 2 /*8/4*/));
            arm64_emit_instruction((ffts_insn_t**)&fp, ARM64_STR_W_UOFF(21 /*W21*/, ARM64_X20, 19 /*76/4*/));
            /* Emit epilogue and return early to avoid executing leaves */
            generate_epilogue_arm64((ffts_insn_t**)&fp);
        }
    } while (0);

    if (ffts_ctzl(N) & 1) {
        /* x2 = p->ee_ws for ee leaf */
        ARM64_LDRI_X((ffts_insn_t**)&fp, ARM64_X2, ARM64_X19, (uint32_t)offsetof(struct _ffts_plan_t, ee_ws));

        /* Ensure x12 points to the start of the offsets stream before ee leaf */
        ARM64_LDRI_X((ffts_insn_t**)&fp, ARM64_X12, ARM64_X19, (uint32_t)offsetof(struct _ffts_plan_t, offsets));

        /* Rebuild stream pointers x3..x10 for ee with ARM32 order and stride = N*8 bytes */
        ARM64_LDRI_X((ffts_insn_t**)&fp, ARM64_X20, ARM64_X19, (uint32_t)offsetof(struct _ffts_plan_t, N));
        /* Base input pointer is in X22 at this point */
        ARM64_MOV_X((ffts_insn_t**)&fp, ARM64_X3,  ARM64_X22);                                              /* x3  = base + 0*N */
        arm64_emit_add_shifted_reg((ffts_insn_t**)&fp, ARM64_X7,  ARM64_X22, ARM64_X20, ARM64_SHIFT_LSL, 3); /* x7  = base + 1*N */
        arm64_emit_add_shifted_reg((ffts_insn_t**)&fp, ARM64_X5,  ARM64_X7,  ARM64_X20, ARM64_SHIFT_LSL, 3); /* x5  = base + 2*N */
        arm64_emit_add_shifted_reg((ffts_insn_t**)&fp, ARM64_X10, ARM64_X5,  ARM64_X20, ARM64_SHIFT_LSL, 3); /* x10 = base + 3*N */
        arm64_emit_add_shifted_reg((ffts_insn_t**)&fp, ARM64_X4,  ARM64_X10, ARM64_X20, ARM64_SHIFT_LSL, 3); /* x4  = base + 4*N */
        arm64_emit_add_shifted_reg((ffts_insn_t**)&fp, ARM64_X8,  ARM64_X4,  ARM64_X20, ARM64_SHIFT_LSL, 3); /* x8  = base + 5*N */
        arm64_emit_add_shifted_reg((ffts_insn_t**)&fp, ARM64_X6,  ARM64_X8,  ARM64_X20, ARM64_SHIFT_LSL, 3); /* x6  = base + 6*N */
        arm64_emit_add_shifted_reg((ffts_insn_t**)&fp, ARM64_X9,  ARM64_X6,  ARM64_X20, ARM64_SHIFT_LSL, 3); /* x9  = base + 7*N */

        generate_leaf_ee_arm64((ffts_insn_t**)&fp, N, p->i1 ? 6 : 0, sign);

        if (p->i1) {
            loop_count = p->i1;
            /* refresh loop counter before next oo leaf */
            generate_leaf_init_arm64((ffts_insn_t**)&fp, loop_count);
            generate_leaf_oo_arm64((ffts_insn_t**)&fp, N, loop_count, sign);
        }

        loop_count += 4;
        /* LUT for oe leaf: default x11; allow override to x12 if FFTS_OE_WS_IN_X12=1 */
        ARM64_LDRI_X((ffts_insn_t**)&fp, ARM64_X11, ARM64_X19, (uint32_t)offsetof(struct _ffts_plan_t, oe_ws));

        /* CRITICAL: After EE, OE reads from the EE output buffer (x0).
           Rebuild stream pointers x3..x10 based on x0 with stride = N*8 bytes. */
        ARM64_LDRI_X((ffts_insn_t**)&fp, ARM64_X20, ARM64_X19, (uint32_t)offsetof(struct _ffts_plan_t, N));
        ARM64_MOV_X((ffts_insn_t**)&fp, ARM64_X3,  ARM64_X0);                                               /* x3  = base + 0*N */
        arm64_emit_add_shifted_reg((ffts_insn_t**)&fp, ARM64_X7,  ARM64_X0, ARM64_X20, ARM64_SHIFT_LSL, 3); /* x7  = base + 1*N */
        arm64_emit_add_shifted_reg((ffts_insn_t**)&fp, ARM64_X5,  ARM64_X7,  ARM64_X20, ARM64_SHIFT_LSL, 3); /* x5  = base + 2*N */
        arm64_emit_add_shifted_reg((ffts_insn_t**)&fp, ARM64_X10, ARM64_X5,  ARM64_X20, ARM64_SHIFT_LSL, 3); /* x10 = base + 3*N */
        arm64_emit_add_shifted_reg((ffts_insn_t**)&fp, ARM64_X4,  ARM64_X10, ARM64_X20, ARM64_SHIFT_LSL, 3); /* x4  = base + 4*N */
        arm64_emit_add_shifted_reg((ffts_insn_t**)&fp, ARM64_X8,  ARM64_X4,  ARM64_X20, ARM64_SHIFT_LSL, 3); /* x8  = base + 5*N */
        arm64_emit_add_shifted_reg((ffts_insn_t**)&fp, ARM64_X6,  ARM64_X8,  ARM64_X20, ARM64_SHIFT_LSL, 3); /* x6  = base + 6*N */
        arm64_emit_add_shifted_reg((ffts_insn_t**)&fp, ARM64_X9,  ARM64_X6,  ARM64_X20, ARM64_SHIFT_LSL, 3); /* x9  = base + 7*N */

        generate_leaf_oe_arm64((ffts_insn_t**)&fp, N, 0, sign);
    } else {
        /* x2 = p->ee_ws for ee leaf */
        ARM64_LDRI_X((ffts_insn_t**)&fp, ARM64_X2, ARM64_X19, (uint32_t)offsetof(struct _ffts_plan_t, ee_ws));

        /* Recompute stream pointers x3..x10 with ARM32-compatible register order and stride.
           ARM32 order: r3=0*N, r7=1*N, r5=2*N, r10=3*N, r4=4*N, r8=5*N, r6=6*N, r9=7*N; each step is N*8 bytes */
        ARM64_LDRI_X((ffts_insn_t**)&fp, ARM64_X20, ARM64_X19, (uint32_t)offsetof(struct _ffts_plan_t, N));
        /* Base input pointer is X22 here as well */
        ARM64_MOV_X((ffts_insn_t**)&fp, ARM64_X3, ARM64_X22);                                              /* x3  = base + 0*N */
        arm64_emit_add_shifted_reg((ffts_insn_t**)&fp, ARM64_X7,  ARM64_X22, ARM64_X20, ARM64_SHIFT_LSL, 3); /* x7  = base + 1*N */
        arm64_emit_add_shifted_reg((ffts_insn_t**)&fp, ARM64_X5,  ARM64_X7,  ARM64_X20, ARM64_SHIFT_LSL, 3); /* x5  = base + 2*N */
        arm64_emit_add_shifted_reg((ffts_insn_t**)&fp, ARM64_X10, ARM64_X5,  ARM64_X20, ARM64_SHIFT_LSL, 3); /* x10 = base + 3*N */
        arm64_emit_add_shifted_reg((ffts_insn_t**)&fp, ARM64_X4,  ARM64_X10, ARM64_X20, ARM64_SHIFT_LSL, 3); /* x4  = base + 4*N */
        arm64_emit_add_shifted_reg((ffts_insn_t**)&fp, ARM64_X8,  ARM64_X4,  ARM64_X20, ARM64_SHIFT_LSL, 3); /* x8  = base + 5*N */
        arm64_emit_add_shifted_reg((ffts_insn_t**)&fp, ARM64_X6,  ARM64_X8,  ARM64_X20, ARM64_SHIFT_LSL, 3); /* x6  = base + 6*N */
        arm64_emit_add_shifted_reg((ffts_insn_t**)&fp, ARM64_X9,  ARM64_X6,  ARM64_X20, ARM64_SHIFT_LSL, 3); /* x9  = base + 7*N */

        /* Ensure x12 points to the start of the offsets stream before ee leaf */
        ARM64_LDRI_X((ffts_insn_t**)&fp, ARM64_X12, ARM64_X19, (uint32_t)offsetof(struct _ffts_plan_t, offsets));
        generate_leaf_ee_arm64((ffts_insn_t**)&fp, N, N >= 256 ? 2 : 8, sign);

        loop_count += 4;
        /* LUT for eo leaf: default x11; allow override to x12 if FFTS_OE_WS_IN_X12=1 */
        {
            ARM64_LDRI_X((ffts_insn_t**)&fp, ARM64_X11, ARM64_X19, (uint32_t)offsetof(struct _ffts_plan_t, eo_ws));
            const char *oe_in_x12 = getenv("FFTS_OE_WS_IN_X12");
            if (oe_in_x12 && *oe_in_x12 && N == 32) {
                ARM64_MOV_X((ffts_insn_t**)&fp, ARM64_X12, ARM64_X11);
            } else {
                /* CRITICAL FIX: Set x12 to point to offsets array + 2 entries (16 bytes) for 
                
                
                / (uint32_t)offsetof(struct _ffts_plan_t, offsets));
                arm64_emit_add_imm((ffts_insn_t**)&fp, 1, ARM64_X12, ARM64_X12, 16); // Skip 2 x 8-byte entries */
            }
        }

        /* Recompute stream pointers x3..x10 again before eo leaf with ARM32-compatible order and N*8 stride. */
        ARM64_LDRI_X((ffts_insn_t**)&fp, ARM64_X20, ARM64_X19, (uint32_t)offsetof(struct _ffts_plan_t, N));
        ARM64_MOV_X((ffts_insn_t**)&fp, ARM64_X3, ARM64_X22);                                              /* x3  = base + 0*N */
        arm64_emit_add_shifted_reg((ffts_insn_t**)&fp, ARM64_X7,  ARM64_X22, ARM64_X20, ARM64_SHIFT_LSL, 3); /* x7  = base + 1*N */
        arm64_emit_add_shifted_reg((ffts_insn_t**)&fp, ARM64_X5,  ARM64_X7,  ARM64_X20, ARM64_SHIFT_LSL, 3); /* x5  = base + 2*N */
        arm64_emit_add_shifted_reg((ffts_insn_t**)&fp, ARM64_X10, ARM64_X5,  ARM64_X20, ARM64_SHIFT_LSL, 3); /* x10 = base + 3*N */
        arm64_emit_add_shifted_reg((ffts_insn_t**)&fp, ARM64_X4,  ARM64_X10, ARM64_X20, ARM64_SHIFT_LSL, 3); /* x4  = base + 4*N */
        arm64_emit_add_shifted_reg((ffts_insn_t**)&fp, ARM64_X8,  ARM64_X4,  ARM64_X20, ARM64_SHIFT_LSL, 3); /* x8  = base + 5*N */
        arm64_emit_add_shifted_reg((ffts_insn_t**)&fp, ARM64_X6,  ARM64_X8,  ARM64_X20, ARM64_SHIFT_LSL, 3); /* x6  = base + 6*N */
        arm64_emit_add_shifted_reg((ffts_insn_t**)&fp, ARM64_X9,  ARM64_X6,  ARM64_X20, ARM64_SHIFT_LSL, 3); /* x9  = base + 7*N */

        generate_leaf_eo_arm64((ffts_insn_t**)&fp, N, 0, sign);

        if (p->i1) {
            loop_count = p->i1;
            /* refresh loop counter for oo */
            generate_leaf_init_arm64((ffts_insn_t**)&fp, loop_count);
            generate_leaf_oo_arm64((ffts_insn_t**)&fp, N, loop_count, sign);
        }
    }

    if (p->i1) {
        loop_count = p->i1;
        /* ee uses x11 as loop counter again */
        generate_leaf_init_arm64((ffts_insn_t**)&fp, loop_count);

        /* Rotate stream pointers as in ARM32 before the final ee leaf
           (use X2 as temporary):
           - swap x3 <-> x7
           - swap x4 <-> x8
           - swap x5 <-> x9
           - swap x6 <-> x10
           - swap x9 <-> x10 */
        ARM64_MOV_X((ffts_insn_t**)&fp, ARM64_X2, ARM64_X3);
        ARM64_MOV_X((ffts_insn_t**)&fp, ARM64_X3, ARM64_X7);
        ARM64_MOV_X((ffts_insn_t**)&fp, ARM64_X7, ARM64_X2);

        ARM64_MOV_X((ffts_insn_t**)&fp, ARM64_X2, ARM64_X4);
        ARM64_MOV_X((ffts_insn_t**)&fp, ARM64_X4, ARM64_X8);
        ARM64_MOV_X((ffts_insn_t**)&fp, ARM64_X8, ARM64_X2);

        ARM64_MOV_X((ffts_insn_t**)&fp, ARM64_X2, ARM64_X5);
        ARM64_MOV_X((ffts_insn_t**)&fp, ARM64_X5, ARM64_X9);
        ARM64_MOV_X((ffts_insn_t**)&fp, ARM64_X9, ARM64_X2);

        ARM64_MOV_X((ffts_insn_t**)&fp, ARM64_X2, ARM64_X6);
        ARM64_MOV_X((ffts_insn_t**)&fp, ARM64_X6, ARM64_X10);
        ARM64_MOV_X((ffts_insn_t**)&fp, ARM64_X10, ARM64_X2);

        ARM64_MOV_X((ffts_insn_t**)&fp, ARM64_X2, ARM64_X9);
        ARM64_MOV_X((ffts_insn_t**)&fp, ARM64_X9, ARM64_X10);
        ARM64_MOV_X((ffts_insn_t**)&fp, ARM64_X10, ARM64_X2);

        /* x2 = p->ee_ws for final ee leaf */
        ARM64_LDRI_X((ffts_insn_t**)&fp, ARM64_X2, ARM64_X19, (uint32_t)offsetof(struct _ffts_plan_t, ee_ws));
        /* Ensure x12 points to the start of the offsets stream before final ee leaf */
        ARM64_LDRI_X((ffts_insn_t**)&fp, ARM64_X12, ARM64_X19, (uint32_t)offsetof(struct _ffts_plan_t, offsets));
        generate_leaf_ee_arm64((ffts_insn_t**)&fp, N, 0, sign);
    }

    /* generate subtransform calls for ARM64 */
    count = 2;
    while (pps[0]) {
        size_t ws_is;

        /* Materialize stride (bytes) for base cases: X1 = pps[0] * 8 */
        {
            uint64_t strideBytes = ((uint64_t)pps[0]) << 3;
            ARM64_MOV_IMM64((ffts_insn_t**)&fp, ARM64_X1, strideBytes);
        }

        if (!pN) {
            /* Load transform size into register (kept for parity, not used by base case) */
            arm64_emit_instruction((ffts_insn_t**)&fp, 0x52800000 | (pps[0] << 5) | 3);  /* mov w3, #pps[0] */
        } else {
            int offset = (4 * pps[1]) - pAddr;
            if (offset) {
                /* Add offset to output and input data pointers (handle large/negative immediates) */
                int rem = offset;
                if (rem > 0) {
                    while (rem > 0) {
                        int chunk = rem > 0x0fff ? 0x0fff : rem;
                        ARM64_ADD_X((ffts_insn_t**)&fp, ARM64_X0,  ARM64_X0,  chunk);
                        ARM64_ADD_X((ffts_insn_t**)&fp, ARM64_X22, ARM64_X22, chunk);
                        rem -= chunk;
                    }
                } else { /* rem < 0 */
                    while (rem < 0) {
                        int chunk = (-rem) > 0x0fff ? 0x0fff : (-rem);
                        ARM64_SUB_X((ffts_insn_t**)&fp, ARM64_X0,  ARM64_X0,  chunk);
                        ARM64_SUB_X((ffts_insn_t**)&fp, ARM64_X22, ARM64_X22, chunk);
                        rem += chunk;
                    }
                }
            }

            if (pps[0] > leaf_N && pps[0] - pN) {
                int factor = ffts_ctzl(pps[0]) - ffts_ctzl(pN);
                if (factor > 0) {
                    /* lsl w3, w3, #factor */
                    arm64_emit_instruction((ffts_insn_t**)&fp, 0x53003c63 | (factor << 16));
                } else {
                    /* lsr w3, w3, #(-factor) */
                    arm64_emit_instruction((ffts_insn_t**)&fp, 0x53003c63 | ((-factor) << 16));
                }
            }
        }

        size_t ws_index = ffts_ctzl(pps[0] / leaf_N) - 1;
        ws_is = 8 * p->ws_is[ws_index];
#ifdef __aarch64__
        /* Temporary diagnostic: allow alt scaling for second LUT at N=32 */
        if (N == 32 && ws_index == 1) {
            const char *alt4 = getenv("FFTS_WSIS_ALT4");
            if (alt4 && *alt4) {
                ws_is = 4 * p->ws_is[ws_index];
            }
        }
#endif
        /* Reset twiddle base to plan->ws before each base-case stage */
        ARM64_LDRI_X((ffts_insn_t**)&fp, ARM64_X2, ARM64_X19, (uint32_t)offsetof(struct _ffts_plan_t, ws));
        if (ws_is) {
            /* Apply stage offset (bytes) from ws base */
            ARM64_ADD_X((ffts_insn_t**)&fp, ARM64_X2, ARM64_X2, (int)ws_is);
        }

        if (pps[0] == 2 * leaf_N) {
            /* Call 4-point base case */
            /* Map base-case expectation: x0 must be input base; preserve current x0 in x20 */
            /* x2 already set to plan->ws + stage offset for base-case */
            ARM64_MOV_X((ffts_insn_t**)&fp, ARM64_X20, ARM64_X0);
            ARM64_MOV_X((ffts_insn_t**)&fp, ARM64_X0, ARM64_X22);
            arm64_emit_bl((ffts_insn_t**)&fp, (int32_t)(((ffts_insn_t*)x_4_addr - (ffts_insn_t*)fp - 1) * 4));
            /* Restore x0 to prior base (out/current destination base) */
            ARM64_MOV_X((ffts_insn_t**)&fp, ARM64_X0, ARM64_X20);
        } else {
            /* For the first x8 stage when there is no sibling (pps[2] == 0),
               inline-copy the specialized x8_t blob like ARM32 does to match
               data re-/interleaving semantics; otherwise call the x8 subroutine. */
            if (!pps[2]) {
                /* Map base-case expectation: x0 must be input base; preserve current x0 in x20 */
                /* x2 already set to plan->ws + stage offset for x8_t */
                /* If diagnostic is enabled for N=32, return early before executing x8_t */
                if (N == 32 && getenv("FFTS_DEBUG_EARLY_RETURN_X8T")) {
                    generate_epilogue_arm64((ffts_insn_t**)&fp);
                }
                ARM64_MOV_X((ffts_insn_t**)&fp, ARM64_X20, ARM64_X0);
                /* x8_t expects x1 = bytes per stream = N (since each stream has N/8 complex pairs) */
                ARM64_MOV_IMM64((ffts_insn_t**)&fp, ARM64_X1, (uint64_t)N);
                extern const uint8_t neon64_x8_t[];
                extern const uint8_t neon64_ee[];
                uint32_t *dst = arm64_copy_blob((uint32_t**)&fp, neon64_x8_t, neon64_ee);
                // arm64_patch_neon64_x8_t(dst, sign);
                /* x0 remains the output base; restore is a no-op */
                ARM64_MOV_X((ffts_insn_t**)&fp, ARM64_X0, ARM64_X20);
            } else {
                /* Call 8-point base case */
                /* Map base-case expectation: x0 must be input base; preserve current x0 in x20 */
                /* x2 already set to plan->ws + stage offset for x8 */
                ARM64_MOV_X((ffts_insn_t**)&fp, ARM64_X20, ARM64_X0);
                ARM64_MOV_X((ffts_insn_t**)&fp, ARM64_X0, ARM64_X22);
                arm64_emit_bl((ffts_insn_t**)&fp, (int32_t)(((ffts_insn_t*)x_8_addr - (ffts_insn_t*)fp - 1) * 4));
                /* Restore x0 to prior base (out/current destination base) */
                ARM64_MOV_X((ffts_insn_t**)&fp, ARM64_X0, ARM64_X20);
            }
        }

        pAddr = 4 * pps[1];
        if (pps[0] > leaf_N) {
            pN = pps[0];
        }

        pLUT = ws_is;
        count += 4;
        pps += 2;
    }

    generate_epilogue_arm64((ffts_insn_t**)&fp);

#else
    /* generate functions for x86/x64 */
    start = generate_prologue(&fp, p);

    loop_count = 4 * p->i0;
    generate_leaf_init(&fp, loop_count);

    if (ffts_ctzl(N) & 1) {
        generate_leaf_ee(&fp, offsets, p->i1 ? 6 : 0);

        if (p->i1) {
            loop_count += 4 * p->i1;
            generate_leaf_oo(&fp, loop_count, offsets_o, 7);
        }

        loop_count += 4;
        generate_leaf_oe(&fp, offsets_o);
    } else {
        generate_leaf_ee(&fp, offsets, N >= 256 ? 2 : 8);

        loop_count += 4;
        generate_leaf_eo(&fp, offsets);

        if (p->i1) {
            loop_count += 4 * p->i1;
            generate_leaf_oo(&fp, loop_count, offsets_o, N >= 256 ? 4 : 7);
        }
    }

    if (p->i1) {
        uint32_t offsets_oe[8] = {7*N, 3*N, N, 5*N, 0, 4*N, 6*N, 2*N};

        loop_count += 4 * p->i1;

        /* align loop/jump destination */
#ifdef _M_X64
        x86_mov_reg_imm(fp, X86_EBX, loop_count);
#else
        x86_mov_reg_imm(fp, X86_ECX, loop_count);
        ffts_align_mem16(&fp, 9);
#endif

        generate_leaf_ee(&fp, offsets_oe, 0);
    }

    generate_transform_init(&fp);

    /* generate subtransform calls */
    count = 2;
    while (pps[0]) {
        size_t ws_is;

        if (!pN) {
#ifdef _M_X64
            x86_mov_reg_imm(fp, X86_EBX, pps[0]);
#else
            x86_mov_reg_imm(fp, X86_ECX, pps[0] / 4);
#endif
        } else {
            int offset = (4 * pps[1]) - pAddr;
            if (offset) {
#ifdef _M_X64
                x64_alu_reg_imm_size(fp, X86_ADD, X64_R8, offset, 8);
#else
                x64_alu_reg_imm_size(fp, X86_ADD, X64_RDX, offset, 8);
#endif
            }

            if (pps[0] > leaf_N && pps[0] - pN) {
                int factor = ffts_ctzl(pps[0]) - ffts_ctzl(pN);

#ifdef _M_X64
                if (factor > 0) {
                    x86_shift_reg_imm(fp, X86_SHL, X86_EBX, factor);
                } else {
                    x86_shift_reg_imm(fp, X86_SHR, X86_EBX, -factor);
                }
#else
                if (factor > 0) {
                    x86_shift_reg_imm(fp, X86_SHL, X86_ECX, factor);
                } else {
                    x86_shift_reg_imm(fp, X86_SHR, X86_ECX, -factor);
                }
#endif
            }
        }

        ws_is = 8 * p->ws_is[ffts_ctzl(pps[0] / leaf_N) - 1];
        if (ws_is != pLUT) {
            int offset = (int) (ws_is - pLUT);

#ifdef _M_X64
            x64_alu_reg_imm_size(fp, X86_ADD, X64_R9, offset, 8);
#else
            x64_alu_reg_imm_size(fp, X86_ADD, X64_R8, offset, 8);
#endif
        }

        if (pps[0] == 2 * leaf_N) {
            x64_call_code(fp, x_4_addr);
        } else {
            x64_call_code(fp, x_8_addr);
        }

        pAddr = 4 * pps[1];
        if (pps[0] > leaf_N) {
            pN = pps[0];
        }

        pLUT = ws_is;//LUT_offset(pps[0], leafN);
        //fprintf(stderr, "LUT offset for %d is %d\n", pN, pLUT);
        count += 4;
        pps += 2;
    }

    generate_epilogue(&fp);
#endif

#ifdef __arm__
#ifdef HAVE_NEON
    if (ffts_ctzl(N) & 1) {
        ADDI(&fp, 2, 7, 0);
        ADDI(&fp, 7, 9, 0);
        ADDI(&fp, 9, 2, 0);

        ADDI(&fp, 2, 8, 0);
        ADDI(&fp, 8, 10, 0);
        ADDI(&fp, 10, 2, 0);

        if(p->i1) {
            MOVI(&fp, 11, p->i1);
            memcpy(fp, neon_oo, neon_eo - neon_oo);
            if(sign < 0) {
                fp[12] ^= 0x00200000;
                fp[13] ^= 0x00200000;
                fp[14] ^= 0x00200000;
                fp[15] ^= 0x00200000;
                fp[27] ^= 0x00200000;
                fp[29] ^= 0x00200000;
                fp[30] ^= 0x00200000;
                fp[31] ^= 0x00200000;
                fp[46] ^= 0x00200000;
                fp[47] ^= 0x00200000;
                fp[48] ^= 0x00200000;
                fp[57] ^= 0x00200000;
            }
            fp += (neon_oo - neon_oo) / 4;
        }

        *fp = LDRI(11, 1, ((uint32_t)&p->oe_ws) - ((uint32_t)p));
        fp++;

        memcpy(fp, neon_oe, neon_end - neon_oe);
        if(sign < 0) {
            fp[19] ^= 0x00200000;
            fp[20] ^= 0x00200000;
            fp[22] ^= 0x00200000;
            fp[23] ^= 0x00200000;
            fp[37] ^= 0x00200000;
            fp[38] ^= 0x00200000;
            fp[40] ^= 0x00200000;
            fp[41] ^= 0x00200000;
            fp[64] ^= 0x00200000;
            fp[65] ^= 0x00200000;
            fp[66] ^= 0x00200000;
            fp[67] ^= 0x00200000;
        }
        fp += (neon_end - neon_oe) / 4;

    } else {

        *fp = LDRI(11, 1, ((uint32_t)&p->eo_ws) - ((uint32_t)p));
        fp++;

        memcpy(fp, neon_eo, neon_oe - neon_eo);
        if(sign < 0) {
            fp[10] ^= 0x00200000;
            fp[11] ^= 0x00200000;
            fp[13] ^= 0x00200000;
            fp[14] ^= 0x00200000;
            fp[31] ^= 0x00200000;
            fp[33] ^= 0x00200000;
            fp[34] ^= 0x00200000;
            fp[35] ^= 0x00200000;
            fp[59] ^= 0x00200000;
            fp[60] ^= 0x00200000;
            fp[61] ^= 0x00200000;
            fp[62] ^= 0x00200000;
        }
        fp += (neon_oe - neon_eo) / 4;

        ADDI(&fp, 2, 7, 0);
        ADDI(&fp, 7, 9, 0);
        ADDI(&fp, 9, 2, 0);

        ADDI(&fp, 2, 8, 0);
        ADDI(&fp, 8, 10, 0);
        ADDI(&fp, 10, 2, 0);

        if(p->i1) {
            MOVI(&fp, 11, p->i1);
            memcpy(fp, neon_oo, neon_eo - neon_oo);
            if(sign < 0) {
                fp[12] ^= 0x00200000;
                fp[13] ^= 0x00200000;
                fp[14] ^= 0x00200000;
                fp[15] ^= 0x00200000;
                fp[27] ^= 0x00200000;
                fp[29] ^= 0x00200000;
                fp[30] ^= 0x00200000;
                fp[31] ^= 0x00200000;
                fp[46] ^= 0x00200000;
                fp[47] ^= 0x00200000;
                fp[48] ^= 0x00200000;
                fp[57] ^= 0x00200000;
            }
            fp += (neon_eo - neon_oo) / 4;
        }
    }

    if(p->i1) {
        ADDI(&fp, 2, 3, 0);
        ADDI(&fp, 3, 7, 0);
        ADDI(&fp, 7, 2, 0);

        ADDI(&fp, 2, 4, 0);
        ADDI(&fp, 4, 8, 0);
        ADDI(&fp, 8, 2, 0);

        ADDI(&fp, 2, 5, 0);
        ADDI(&fp, 5, 9, 0);
        ADDI(&fp, 9, 2, 0);

        ADDI(&fp, 2, 6, 0);
        ADDI(&fp, 6, 10, 0);
        ADDI(&fp, 10, 2, 0);

        ADDI(&fp, 2, 9, 0);
        ADDI(&fp, 9, 10, 0);
        ADDI(&fp, 10, 2, 0);

        *fp = LDRI(2, 1, ((uint32_t)&p->ee_ws) - ((uint32_t)p));
        fp++;
        MOVI(&fp, 11, p->i1);
        memcpy(fp, neon_ee, neon_oo - neon_ee);
        if(sign < 0) {
            fp[33] ^= 0x00200000;
            fp[37] ^= 0x00200000;
            fp[38] ^= 0x00200000;
            fp[39] ^= 0x00200000;
            fp[40] ^= 0x00200000;
            fp[41] ^= 0x00200000;
            fp[44] ^= 0x00200000;
            fp[45] ^= 0x00200000;
            fp[46] ^= 0x00200000;
            fp[47] ^= 0x00200000;
            fp[48] ^= 0x00200000;
            fp[57] ^= 0x00200000;
        }
        fp += (neon_oo - neon_ee) / 4;
    }
#else
    ADDI(&fp, 2, 7, 0);
    ADDI(&fp, 7, 9, 0);
    ADDI(&fp, 9, 2, 0);

    ADDI(&fp, 2, 8, 0);
    ADDI(&fp, 8, 10, 0);
    ADDI(&fp, 10, 2, 0);

    MOVI(&fp, 11, (p->i1>0) ? p->i1 : 1);
    memcpy(fp, vfp_o, vfp_x4 - vfp_o);
    if(sign > 0) {
        fp[22] ^= 0x00000040;
        fp[24] ^= 0x00000040;
        fp[25] ^= 0x00000040;
        fp[26] ^= 0x00000040;
        fp[62] ^= 0x00000040;
        fp[64] ^= 0x00000040;
        fp[65] ^= 0x00000040;
        fp[66] ^= 0x00000040;
    }
    fp += (vfp_x4 - vfp_o) / 4;

    ADDI(&fp, 2, 3, 0);
    ADDI(&fp, 3, 7, 0);
    ADDI(&fp, 7, 2, 0);

    ADDI(&fp, 2, 4, 0);
    ADDI(&fp, 4, 8, 0);
    ADDI(&fp, 8, 2, 0);

    ADDI(&fp, 2, 5, 0);
    ADDI(&fp, 5, 9, 0);
    ADDI(&fp, 9, 2, 0);

    ADDI(&fp, 2, 6, 0);
    ADDI(&fp, 6, 10, 0);
    ADDI(&fp, 10, 2, 0);

    ADDI(&fp, 2, 9, 0);
    ADDI(&fp, 9, 10, 0);
    ADDI(&fp, 10, 2, 0);

    *fp = LDRI(2, 1, ((uint32_t)&p->ee_ws) - ((uint32_t)p));
    fp++;
    MOVI(&fp, 11, (p->i2>0) ? p->i2 : 1);
    memcpy(fp, vfp_e, vfp_o - vfp_e);
    if(sign > 0) {
        fp[64] ^= 0x00000040;
        fp[65] ^= 0x00000040;
        fp[68] ^= 0x00000040;
        fp[75] ^= 0x00000040;
        fp[76] ^= 0x00000040;
        fp[79] ^= 0x00000040;
        fp[80] ^= 0x00000040;
        fp[83] ^= 0x00000040;
        fp[84] ^= 0x00000040;
        fp[87] ^= 0x00000040;
        fp[91] ^= 0x00000040;
        fp[93] ^= 0x00000040;
    }
    fp += (vfp_o - vfp_e) / 4;

#endif
    *fp = LDRI(2, 1, ((uint32_t)&p->ws) - ((uint32_t)p));
    fp++; // load offsets into r12
    //ADDI(&fp, 2, 1, 0);
    MOVI(&fp, 1, 0);

    // args: r0 - out
    //       r1 - N
    //       r2 - ws
    //	ADDI(&fp, 3, 1, 0); // put N into r3 for counter

    count = 2;
    while(pps[0]) {

        //	fprintf(stderr, "size %zu at %zu - diff %zu\n", pps[0], pps[1]*4, (pps[1]*4) - pAddr);
        if(!pN) {
            MOVI(&fp, 1, pps[0]);
        } else {
            if((pps[1]*4)-pAddr) ADDI(&fp, 0, 0, (pps[1] * 4)- pAddr);
            if(pps[0] - pN) ADDI(&fp, 1, 1, pps[0] - pN);
        }

        if (p->ws_is[ffts_ctzl(pps[0]/leaf_N)-1]*8 - pLUT) {
            ADDI(&fp, 2, 2, p->ws_is[ffts_ctzl(pps[0]/leaf_N)-1]*8 - pLUT);
        }

        if(pps[0] == 2 * leaf_N) {
            *fp = BL(fp+2, x_4_addr);
            fp++;
        } else if(!pps[2]) {
            //uint32_t *x_8_t_addr = fp;
#ifdef HAVE_NEON
            memcpy(fp, neon_x8_t, neon_ee - neon_x8_t);
            if(sign < 0) {
                fp[31] ^= 0x00200000;
                fp[32] ^= 0x00200000;
                fp[33] ^= 0x00200000;
                fp[34] ^= 0x00200000;
                fp[65] ^= 0x00200000;
                fp[66] ^= 0x00200000;
                fp[70] ^= 0x00200000;
                fp[74] ^= 0x00200000;
                fp[97] ^= 0x00200000;
                fp[98] ^= 0x00200000;
                fp[102] ^= 0x00200000;
                fp[104] ^= 0x00200000;
            }
            fp += (neon_ee - neon_x8_t) / 4;
            //*fp++ = BL(fp+2, x_8_t_addr);

#else
            *fp = BL(fp+2, x_8_addr);
            fp++;
#endif
        } else {
            *fp = BL(fp+2, x_8_addr);
            fp++;
        }

        pAddr = pps[1] * 4;
        pN = pps[0];
        pLUT = p->ws_is[ffts_ctzl(pps[0]/leaf_N)-1]*8;//LUT_offset(pps[0], leafN);
        //	fprintf(stderr, "LUT offset for %d is %d\n", pN, pLUT);
        count += 4;
        pps += 2;
    }

    *fp++ = 0xecbd8b10;
    *fp++ = POP_LR();
    count++;
#endif

    //	*fp++ = B(14); count++;

    //for(int i=0;i<(neon_x8 - neon_x4)/4;i++)
    //	fprintf(stderr, "%08x\n", x_4_addr[i]);
    //fprintf(stderr, "\n");
    //for(int i=0;i<count;i++)

    //fprintf(stderr, "size of transform %u = %d\n", N, (fp - x_8_addr) * sizeof(*fp));

    free(ps);

#if defined(_MSC_VER)
#pragma warning(push)

    /* disable type cast warning from data pointer to function pointer */
#pragma warning(disable : 4055)
#endif

    return (transform_func_t) start;

#if defined(_MSC_VER)
#pragma warning(pop)
#endif
}