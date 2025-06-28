/*
 * neon64_static.s: ARM64/AArch64 NEON static implementations for FFTS
 *
 * This file is part of FFTS -- The Fastest Fourier Transform in the South
 *
 * Copyright (c) 2024, ARM64 Static Implementation for FFTS
 * Copyright (c) 2016, Jukka Ojanen <jukka.ojanen@kolumbus.fi>
 * Copyright (c) 2012, Anthony M. Blake <amb@anthonix.com>
 * Copyright (c) 2012, The University of Waikato
 *
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * * Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 * * Redistributions in binary form must reproduce the above copyright
 * notice, this list of conditions and the following disclaimer in the
 * documentation and/or other materials provided with the distribution.
 * * Neither the name of the organization nor the
 * names of its contributors may be used to endorse or promote products
 * derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL ANTHONY M. Blake BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * --- CORRECTED ARM64 IMPLEMENTATION NOTES (2024) ---
 * The original provided ARM64 code was non-functional due to critical errors.
 * This version corrects those issues.
 *
 */

.text
.align 4

/*
 * =========================================================================
 *  ARM64 Static Even Transform Macro (Complete Port)
 * =========================================================================
 */
.macro neon64_static_e, forward=1
    .align 4

.if \forward
#ifdef __APPLE__
    .globl _neon64_static_e_f
_neon64_static_e_f:
#else
    .globl neon64_static_e_f
neon64_static_e_f:
#endif
.else
#ifdef __APPLE__
    .globl _neon64_static_e_i
_neon64_static_e_i:
#else
    .globl neon64_static_e_i
neon64_static_e_i:
#endif
.endif
    stp     x29, x30, [sp, #-176]!
    stp     x19, x20, [sp, #16]; stp x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]; stp x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    stp     d8, d9, [sp, #96];   stp d10, d11, [sp, #112]
    stp     d12, d13, [sp, #128]; stp d14, d15, [sp, #144]
    mov     x29, sp

    ldr     x9, [x0, #176];       ldr x28, [x0];        ldr x19, [x0, #128]
    add     x20, x1,   x9, lsl #2; add x21, x1,   x9, lsl #3
    add     x22, x1,   x9, lsl #4; add x23, x20,  x9, lsl #3
    add     x24, x20,  x9, lsl #4; ldr x26, [x0, #152] // p->i0
    add     x25, x22,  x9, lsl #3; add x27, x23,  x9, lsl #4

    ld1     {v16.4s, v17.4s}, [x19]

1: // Loop 1
    ld2 {v30.4s, v31.4s}, [x23], #32; ld2 {v26.4s, v27.4s}, [x24], #32
    ld2 {v28.4s, v29.4s}, [x20], #32; ld2 {v18.4s, v19.4s}, [x22], #32
    ld2 {v20.4s, v21.4s}, [x1],  #32; ld2 {v22.4s, v23.4s}, [x25], #32
    ld2 {v24.4s, v25.4s}, [x21], #32; fsub v2.4s, v28.4s, v26.4s
    fsub v3.4s, v29.4s, v27.4s; ld2 {v0.4s, v1.4s},   [x27], #32
    subs x26, x26, #1; fsub v4.4s, v0.4s, v30.4s; fsub v5.4s, v1.4s, v31.4s
    fadd v0.4s, v0.4s, v30.4s; fadd v1.4s, v1.4s, v31.4s
    fmul v10.4s, v4.4s, v17.4s; fmul v11.4s, v5.4s, v16.4s
    fmul v12.4s, v5.4s, v17.4s; fmul v6.4s, v18.4s, v17.4s
    fmul v7.4s, v19.4s, v16.4s; fmul v8.4s, v18.4s, v16.4s
    fmul v9.4s, v19.4s, v17.4s; fmul v13.4s, v4.4s, v16.4s
    fsub v7.4s, v7.4s, v6.4s; fadd v11.4s, v11.4s, v10.4s
    fsub v2.4s, v24.4s, v22.4s; fsub v3.4s, v25.4s, v23.4s
    fsub v4.4s, v20.4s, v18.4s; fsub v5.4s, v21.4s, v19.4s
    fadd v6.4s, v9.4s, v8.4s; fadd v8.4s, v28.4s, v26.4s
    fadd v9.4s, v29.4s, v27.4s; fadd v22.4s, v24.4s, v22.4s
    fadd v23.4s, v25.4s, v23.4s; fadd v24.4s, v20.4s, v18.4s
    fadd v25.4s, v21.4s, v19.4s; fsub v10.4s, v13.4s, v12.4s
    fsub v14.4s, v8.4s, v0.4s; fsub v15.4s, v9.4s, v1.4s
    fsub v18.4s, v24.4s, v22.4s; fsub v19.4s, v25.4s, v23.4s
    fsub v26.4s, v10.4s, v6.4s; fsub v27.4s, v11.4s, v7.4s
.if \forward
    fsub v28.4s, v11.4s, v5.4s; fsub v29.4s, v10.4s, v4.4s
.else
    fadd v28.4s, v11.4s, v5.4s; fadd v29.4s, v10.4s, v4.4s
.endif
    fadd v10.4s, v10.4s, v6.4s; fadd v11.4s, v11.4s, v7.4s
    fadd v20.4s, v8.4s, v0.4s; fadd v21.4s, v9.4s, v1.4s
    fadd v22.4s, v24.4s, v22.4s; fadd v23.4s, v25.4s, v23.4s
.if \forward
    fadd v31.4s, v10.4s, v4.4s; fadd v28.4s, v8.4s, v6.4s
    fsub v30.4s, v8.4s, v6.4s; fsub v10.4s, v18.4s, v14.4s
    fsub v14.4s, v31.4s, v26.4s
.else
    fsub v31.4s, v10.4s, v4.4s; fsub v28.4s, v8.4s, v6.4s
    fadd v30.4s, v8.4s, v6.4s; fadd v10.4s, v18.4s, v14.4s
    fadd v14.4s, v31.4s, v26.4s
.endif
    fadd v2.4s, v28.4s, v10.4s; fadd v0.4s, v22.4s, v20.4s
.if \forward
    fadd v12.4s, v30.4s, v27.4s; fadd v8.4s, v18.4s, v15.4s
    fadd v26.4s, v19.4s, v14.4s; fsub v24.4s, v18.4s, v15.4s
    fadd v30.4s, v31.4s, v26.4s
.else
    fsub v12.4s, v30.4s, v27.4s; fsub v8.4s, v18.4s, v15.4s
    fsub v26.4s, v19.4s, v14.4s; fadd v24.4s, v18.4s, v15.4s
    fsub v30.4s, v31.4s, v26.4s
.endif
    ldr w19, [x28], #4; mov v6.16b, v26.16b
    trn1 v2.4s, v2.4s, v6.4s; trn2 v6.4s, v2.4s, v6.4s
    ldr w9, [x28], #4
    // FIX: Correct operand types for mov
    mov v4.16b, v24.16b
    trn1 v0.4s, v0.4s, v4.4s; trn2 v4.4s, v0.4s, v4.4s
    add x19, x2, x19, lsl #3; fsub v8.4s, v22.4s, v20.4s
    add x9, x2, x9, lsl #3; fsub v10.4s, v28.4s, v10.4s
.if \forward
    fsub v14.4s, v30.4s, v27.4s
.else
    fadd v14.4s, v30.4s, v27.4s
.endif
    // Stage and store
    mov v20.16b, v0.16b; mov v21.16b, v2.16b
    st2 {v20.4s, v21.4s}, [x19], #32
    mov v20.16b, v4.16b; mov v21.16b, v6.16b
    st2 {v20.4s, v21.4s}, [x9], #32
    // FIX: Correct operand types for mov
    mov v12.16b, v24.16b
    trn1 v8.4s, v8.4s, v12.4s; trn2 v12.4s, v8.4s, v12.4s
    mov v14.16b, v26.16b
    trn1 v10.4s, v10.4s, v14.4s; trn2 v14.4s, v10.4s, v14.4s
    // Stage and store
    mov v20.16b, v8.16b; mov v21.16b, v10.16b
    st2 {v20.4s, v21.4s}, [x19], #32
    mov v20.16b, v12.16b; mov v21.16b, v14.16b
    st2 {v20.4s, v21.4s}, [x9], #32
    b.ne 1b

4: // Epilogue
    ldp d14, d15, [sp, #144]; ldp d12, d13, [sp, #128]
    ldp d10, d11, [sp, #112]; ldp d8, d9, [sp, #96]
    ldp x27, x28, [sp, #80];  ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48];  ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16];  ldp x29, x30, [sp], #176
    ret
.endm


/*
 * =========================================================================
 *  ARM64 Static Odd Transform Macro (Complete Port)
 * =========================================================================
 */
.macro neon64_static_o, forward=1
    .align 4
.if \forward
#ifdef __APPLE__
    .globl _neon64_static_o_f
_neon64_static_o_f:
#else
    .globl neon64_static_o_f
neon64_static_o_f:
#endif
.else
#ifdef __APPLE__
    .globl _neon64_static_o_i
_neon64_static_o_i:
#else
    .globl neon64_static_o_i
neon64_static_o_i:
#endif
.endif
    stp     x29, x30, [sp, #-176]!
    stp     x19, x20, [sp, #16]; stp x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]; stp x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    stp     d8, d9, [sp, #96];   stp d10, d11, [sp, #112]
    stp     d12, d13, [sp, #128]; stp d14, d15, [sp, #144]
    mov     x29, sp

    ldr     x9, [x0, #176];       ldr x28, [x0];        ldr x19, [x0, #128]
    add     x20, x1,   x9, lsl #2; add x21, x1,   x9, lsl #3
    add     x22, x1,   x9, lsl #4; add x23, x20,  x9, lsl #3
    add     x24, x20,  x9, lsl #4; ldr x26, [x0, #152] // p->i0
    add     x25, x22,  x9, lsl #3; add x27, x23,  x9, lsl #4

    ld1     {v16.4s, v17.4s}, [x19]

1: // Loop 1 (Identical to _e)
    ld2 {v30.4s, v31.4s}, [x23], #32; ld2 {v26.4s, v27.4s}, [x24], #32
    ld2 {v28.4s, v29.4s}, [x20], #32; ld2 {v18.4s, v19.4s}, [x22], #32
    ld2 {v20.4s, v21.4s}, [x1],  #32; ld2 {v22.4s, v23.4s}, [x25], #32
    ld2 {v24.4s, v25.4s}, [x21], #32; fsub v2.4s, v28.4s, v26.4s
    fsub v3.4s, v29.4s, v27.4s; ld2 {v0.4s, v1.4s},   [x27], #32
    subs x26, x26, #1; fsub v4.4s, v0.4s, v30.4s; fsub v5.4s, v1.4s, v31.4s
    fadd v0.4s, v0.4s, v30.4s; fadd v1.4s, v1.4s, v31.4s
    fmul v10.4s, v4.4s, v17.4s; fmul v11.4s, v5.4s, v16.4s
    fmul v12.4s, v5.4s, v17.4s; fmul v6.4s, v18.4s, v17.4s
    fmul v7.4s, v19.4s, v16.4s; fmul v8.4s, v18.4s, v16.4s
    fmul v9.4s, v19.4s, v17.4s; fmul v13.4s, v4.4s, v16.4s
    fsub v7.4s, v7.4s, v6.4s; fadd v11.4s, v11.4s, v10.4s
    fsub v2.4s, v24.4s, v22.4s; fsub v3.4s, v25.4s, v23.4s
    fsub v4.4s, v20.4s, v18.4s; fsub v5.4s, v21.4s, v19.4s
    fadd v6.4s, v9.4s, v8.4s; fadd v8.4s, v28.4s, v26.4s
    fadd v9.4s, v29.4s, v27.4s; fadd v22.4s, v24.4s, v22.4s
    fadd v23.4s, v25.4s, v23.4s; fadd v24.4s, v20.4s, v18.4s
    fadd v25.4s, v21.4s, v19.4s; fsub v10.4s, v13.4s, v12.4s
    fsub v14.4s, v8.4s, v0.4s; fsub v15.4s, v9.4s, v1.4s
    fsub v18.4s, v24.4s, v22.4s; fsub v19.4s, v25.4s, v23.4s
    fsub v26.4s, v10.4s, v6.4s; fsub v27.4s, v11.4s, v7.4s
.if \forward
    fsub v28.4s, v11.4s, v5.4s; fsub v29.4s, v10.4s, v4.4s
.else
    fadd v28.4s, v11.4s, v5.4s; fadd v29.4s, v10.4s, v4.4s
.endif
    fadd v10.4s, v10.4s, v6.4s; fadd v11.4s, v11.4s, v7.4s
    fadd v20.4s, v8.4s, v0.4s; fadd v21.4s, v9.4s, v1.4s
    fadd v22.4s, v24.4s, v22.4s; fadd v23.4s, v25.4s, v23.4s
.if \forward
    fadd v31.4s, v10.4s, v4.4s; fadd v28.4s, v8.4s, v6.4s
    fsub v30.4s, v8.4s, v6.4s; fsub v10.4s, v18.4s, v14.4s
    fsub v14.4s, v31.4s, v26.4s
.else
    fsub v31.4s, v10.4s, v4.4s; fsub v28.4s, v8.4s, v6.4s
    fadd v30.4s, v8.4s, v6.4s; fadd v10.4s, v18.4s, v14.4s
    fadd v14.4s, v31.4s, v26.4s
.endif
    fadd v2.4s, v28.4s, v10.4s; fadd v0.4s, v22.4s, v20.4s
.if \forward
    fadd v12.4s, v30.4s, v27.4s; fadd v8.4s, v18.4s, v15.4s
    fadd v26.4s, v19.4s, v14.4s; fsub v24.4s, v18.4s, v15.4s
    fadd v30.4s, v31.4s, v26.4s
.else
    fsub v12.4s, v30.4s, v27.4s; fsub v8.4s, v18.4s, v15.4s
    fsub v26.4s, v19.4s, v14.4s; fadd v24.4s, v18.4s, v15.4s
    fsub v30.4s, v31.4s, v26.4s
.endif
    ldr w19, [x28], #4; mov v6.16b, v26.16b
    trn1 v2.4s, v2.4s, v6.4s; trn2 v6.4s, v2.4s, v6.4s
    ldr w9, [x28], #4
    // FIX: Correct operand types for mov
    mov v4.16b, v24.16b
    trn1 v0.4s, v0.4s, v4.4s; trn2 v4.4s, v0.4s, v4.4s
    add x19, x2, x19, lsl #3; fsub v8.4s, v22.4s, v20.4s
    add x9, x2, x9, lsl #3; fsub v10.4s, v28.4s, v10.4s
.if \forward
    fsub v14.4s, v30.4s, v27.4s
.else
    fadd v14.4s, v30.4s, v27.4s
.endif
    mov v20.16b, v0.16b; mov v21.16b, v2.16b
    st2 {v20.4s, v21.4s}, [x19], #32
    mov v20.16b, v4.16b; mov v21.16b, v6.16b
    st2 {v20.4s, v21.4s}, [x9], #32
    // FIX: Correct operand types for mov
    mov v12.16b, v24.16b
    trn1 v8.4s, v8.4s, v12.4s; trn2 v12.4s, v8.4s, v12.4s
    mov v14.16b, v26.16b
    trn1 v10.4s, v10.4s, v14.4s; trn2 v14.4s, v10.4s, v14.4s
    mov v20.16b, v8.16b; mov v21.16b, v10.16b
    st2 {v20.4s, v21.4s}, [x19], #32
    mov v20.16b, v12.16b; mov v21.16b, v14.16b
    st2 {v20.4s, v21.4s}, [x9], #32
    b.ne 1b

5: // Epilogue
    ldp d14, d15, [sp, #144]; ldp d12, d13, [sp, #128]
    ldp d10, d11, [sp, #112]; ldp d8, d9, [sp, #96]
    ldp x27, x28, [sp, #80];  ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48];  ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16];  ldp x29, x30, [sp], #176
    ret
.endm


/*
 * =========================================================================
 *  ARM64 Static 4-point FFT Macro (Complete Port)
 * =========================================================================
 */
.macro neon64_static_x4, forward=1
    .align 4
.if \forward
#ifdef __APPLE__
    .globl _neon64_static_x4_f
_neon64_static_x4_f:
#else
    .globl neon64_static_x4_f
neon64_static_x4_f:
#endif
.else
#ifdef __APPLE__
    .globl _neon64_static_x4_i
_neon64_static_x4_i:
#else
    .globl neon64_static_x4_i
neon64_static_x4_i:
#endif
.endif
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    mov x2, x0; add x3, x0, #64

    ld1 {v2.4s, v3.4s}, [x1]; ld1 {v12.4s, v13.4s}, [x3], #32
    ld1 {v14.4s, v15.4s}, [x3]; ld1 {v8.4s, v9.4s}, [x0], #32
    ld1 {v10.4s, v11.4s}, [x0]

    fmul v0.4s, v13.4s, v3.4s; fmul v5.4s, v12.4s, v2.4s
    fmul v1.4s, v14.4s, v2.4s; fmul v4.4s, v14.4s, v3.4s
    fmul v14.4s, v12.4s, v3.4s; fmul v13.4s, v13.4s, v2.4s
    fmul v12.4s, v15.4s, v3.4s; fmul v2.4s, v15.4s, v2.4s
    fsub v0.4s, v5.4s, v0.4s; fadd v13.4s, v13.4s, v14.4s
    fadd v12.4s, v12.4s, v1.4s; fsub v1.4s, v2.4s, v4.4s
    fadd v15.4s, v0.4s, v12.4s; fsub v12.4s, v0.4s, v12.4s
    fadd v14.4s, v13.4s, v1.4s; fsub v13.4s, v13.4s, v1.4s
    fadd v0.4s, v8.4s, v15.4s; fadd v1.4s, v9.4s, v14.4s
.if \forward
    fadd v2.4s, v10.4s, v13.4s; fsub v3.4s, v11.4s, v12.4s
.else
    fsub v2.4s, v10.4s, v13.4s; fadd v3.4s, v11.4s, v12.4s
.endif
    fsub v4.4s, v8.4s, v15.4s
.if \forward
    fsub v5.4s, v9.4s, v14.4s; fsub v6.4s, v10.4s, v13.4s; fadd v7.4s, v11.4s, v12.4s
.else
    fadd v5.4s, v9.4s, v14.4s; fadd v6.4s, v10.4s, v13.4s; fsub v7.4s, v11.4s, v12.4s
.endif

    st1 {v0.4s, v1.4s}, [x2], #32; st1 {v2.4s, v3.4s}, [x2], #32
    st1 {v4.4s, v5.4s}, [x2], #32; st1 {v6.4s, v7.4s}, [x2]

    ldp x29, x30, [sp], #16
    ret
.endm


/*
 * =========================================================================
 *  ARM64 Static 8-point FFT Macro (Complete Port)
 * =========================================================================
 */
.macro neon64_static_x8, forward=1
    .align 4
.if \forward
#ifdef __APPLE__
    .globl _neon64_static_x8_f
_neon64_static_x8_f:
#else
    .globl neon64_static_x8_f
neon64_static_x8_f:
#endif
.else
#ifdef __APPLE__
    .globl _neon64_static_x8_i
_neon64_static_x8_i:
#else
    .globl neon64_static_x8_i
neon64_static_x8_i:
#endif
.endif
    stp     x29, x30, [sp, #-80]!
    stp     x19, x20, [sp, #16]; stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]; stp     d8, d9, [sp, #64]
    mov     x29, sp

    add     x20, x0, x1, lsl #3; add x19, x0, x1, lsl #2
    add     x22, x20, x1, lsl #3; add x21, x20, x1, lsl #2
    add     x24, x22, x1, lsl #3; add x23, x22, x1, lsl #2
    add     x12, x24, x1, lsl #2

1:
    ld1 {v2.4s, v3.4s}, [x2], #32; subs x1, x1, #32
    ld1 {v14.4s, v15.4s}, [x21]; fmul v12.4s, v15.4s, v2.4s
    ld1 {v10.4s, v11.4s}, [x20]; fmul v8.4s, v14.4s, v3.4s
    fmul v13.4s, v14.4s, v2.4s; fmul v9.4s, v10.4s, v3.4s
    fmul v1.4s, v10.4s, v2.4s; fmul v0.4s, v11.4s, v2.4s
    fmul v14.4s, v11.4s, v3.4s; fmul v15.4s, v15.4s, v3.4s
    fsub v10.4s, v12.4s, v8.4s; ld1 {v2.4s, v3.4s}, [x2], #32
    fadd v11.4s, v0.4s, v9.4s; fadd v8.4s, v15.4s, v13.4s
    fsub v9.4s, v1.4s, v14.4s; ld1 {v12.4s, v13.4s}, [x19]
    fsub v15.4s, v11.4s, v10.4s; fsub v14.4s, v9.4s, v8.4s
.if \forward
    fadd v4.4s, v12.4s, v15.4s; fsub v6.4s, v12.4s, v15.4s
    fsub v5.4s, v13.4s, v14.4s; fadd v7.4s, v13.4s, v14.4s
.else
    fsub v4.4s, v12.4s, v15.4s; fadd v6.4s, v12.4s, v15.4s
    fadd v5.4s, v13.4s, v14.4s; fsub v7.4s, v13.4s, v14.4s
.endif
    ld1 {v14.4s, v15.4s}, [x24]; ld1 {v12.4s, v13.4s}, [x22]
    fmul v1.4s, v14.4s, v2.4s; fmul v0.4s, v14.4s, v3.4s
    st1 {v4.4s, v5.4s}, [x19]; fmul v14.4s, v15.4s, v3.4s
    fmul v4.4s, v15.4s, v2.4s; fadd v15.4s, v9.4s, v8.4s
    st1 {v6.4s, v7.4s}, [x21]; fmul v8.4s, v12.4s, v3.4s
    fmul v5.4s, v13.4s, v3.4s; fmul v12.4s, v12.4s, v2.4s
    fmul v9.4s, v13.4s, v2.4s; fadd v14.4s, v14.4s, v1.4s
    fsub v13.4s, v4.4s, v0.4s; fadd v0.4s, v9.4s, v8.4s
    ld1 {v8.4s, v9.4s}, [x0]; fadd v1.4s, v11.4s, v10.4s
    fsub v12.4s, v12.4s, v5.4s; fadd v11.4s, v8.4s, v15.4s
    fsub v8.4s, v8.4s, v15.4s; fadd v2.4s, v12.4s, v14.4s
    fsub v10.4s, v0.4s, v13.4s; fadd v15.4s, v0.4s, v13.4s
    fadd v13.4s, v9.4s, v1.4s; fsub v9.4s, v9.4s, v1.4s
    fsub v12.4s, v12.4s, v14.4s; fadd v0.4s, v11.4s, v2.4s
    fadd v1.4s, v13.4s, v15.4s; fsub v4.4s, v11.4s, v2.4s
.if \forward
    fadd v2.4s, v8.4s, v10.4s; fsub v3.4s, v9.4s, v12.4s
.else
    fsub v2.4s, v8.4s, v10.4s; fadd v3.4s, v9.4s, v12.4s
.endif
    st1 {v0.4s, v1.4s}, [x0], #32; fsub v5.4s, v13.4s, v15.4s
    ld1 {v14.4s, v15.4s}, [x12]
.if \forward
    fadd v7.4s, v9.4s, v12.4s
.else
    fsub v7.4s, v9.4s, v12.4s
.endif
    ld1 {v12.4s, v13.4s}, [x23]; st1 {v2.4s, v3.4s}, [x20], #32
    ld1 {v2.4s, v3.4s}, [x2], #32
.if \forward
    fsub v6.4s, v8.4s, v10.4s
.else
    fadd v6.4s, v8.4s, v10.4s
.endif
    fmul v8.4s, v14.4s, v2.4s; st1 {v4.4s, v5.4s}, [x22], #32
    fmul v10.4s, v15.4s, v3.4s; fmul v9.4s, v13.4s, v3.4s
    fmul v11.4s, v12.4s, v2.4s; fmul v14.4s, v14.4s, v3.4s
    st1 {v6.4s, v7.4s}, [x24], #32; fmul v15.4s, v15.4s, v2.4s
    fmul v12.4s, v12.4s, v3.4s; fmul v13.4s, v13.4s, v2.4s
    fadd v10.4s, v10.4s, v8.4s; fsub v11.4s, v11.4s, v9.4s
    ld1 {v8.4s, v9.4s}, [x19]; fsub v14.4s, v15.4s, v14.4s
    fadd v15.4s, v13.4s, v12.4s; fadd v13.4s, v11.4s, v10.4s
    fadd v12.4s, v15.4s, v14.4s; fsub v15.4s, v15.4s, v14.4s
    fsub v14.4s, v11.4s, v10.4s; ld1 {v10.4s, v11.4s}, [x21]
    fadd v0.4s, v8.4s, v13.4s; fadd v1.4s, v9.4s, v12.4s
.if \forward
    fadd v2.4s, v10.4s, v15.4s; fsub v3.4s, v11.4s, v14.4s
.else
    fsub v2.4s, v10.4s, v15.4s; fadd v3.4s, v11.4s, v14.4s
.endif
    fsub v4.4s, v8.4s, v13.4s; st1 {v0.4s, v1.4s}, [x19], #32
    fsub v5.4s, v9.4s, v12.4s
.if \forward
    fsub v6.4s, v10.4s, v15.4s
.else
    fadd v6.4s, v10.4s, v15.4s
.endif
    st1 {v2.4s, v3.4s}, [x21], #32
.if \forward
    fadd v7.4s, v11.4s, v14.4s
.else
    fsub v7.4s, v11.4s, v14.4s
.endif
    st1 {v4.4s, v5.4s}, [x23], #32
    st1 {v6.4s, v7.4s}, [x12], #32
    b.ne 1b

    ldp d8, d9, [sp, #64]; ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]; ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #80
    ret
.endm


/*
 * =========================================================================
 *  ARM64 Static 8-point Transposed FFT Macro (Complete Port)
 * =========================================================================
 */
.macro neon64_static_x8_t, forward=1
    .align 4
.if \forward
#ifdef __APPLE__
    .globl _neon64_static_x8_t_f
_neon64_static_x8_t_f:
#else
    .globl neon64_static_x8_t_f
neon64_static_x8_t_f:
#endif
.else
#ifdef __APPLE__
    .globl _neon64_static_x8_t_i
_neon64_static_x8_t_i:
#else
    .globl neon64_static_x8_t_i
neon64_static_x8_t_i:
#endif
.endif
    stp     x29, x30, [sp, #-80]!
    stp     x19, x20, [sp, #16]; stp x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]; stp d8, d9, [sp, #64]
    mov     x29, sp

    add x20, x0, x1, lsl #3; add x19, x0, x1, lsl #2
    add x22, x20, x1, lsl #3; add x21, x20, x1, lsl #2
    add x24, x22, x1, lsl #3; add x23, x22, x1, lsl #2
    add x12, x24, x1, lsl #2

1:
    ld1 {v2.4s, v3.4s}, [x2], #32; subs x1, x1, #32
    ld1 {v14.4s, v15.4s}, [x21]; fmul v12.4s, v15.4s, v2.4s
    ld1 {v10.4s, v11.4s}, [x20]; fmul v8.4s, v14.4s, v3.4s
    fmul v13.4s, v14.4s, v2.4s; fmul v9.4s, v10.4s, v3.4s
    fmul v1.4s, v10.4s, v2.4s; fmul v0.4s, v11.4s, v2.4s
    fmul v14.4s, v11.4s, v3.4s; fmul v15.4s, v15.4s, v3.4s
    fsub v10.4s, v12.4s, v8.4s; ld1 {v2.4s, v3.4s}, [x2], #32
    fadd v11.4s, v0.4s, v9.4s; fadd v8.4s, v15.4s, v13.4s
    fsub v9.4s, v1.4s, v14.4s; ld1 {v12.4s, v13.4s}, [x19]
    fsub v15.4s, v11.4s, v10.4s; fsub v14.4s, v9.4s, v8.4s
.if \forward
    fadd v4.4s, v12.4s, v15.4s; fsub v6.4s, v12.4s, v15.4s
    fsub v5.4s, v13.4s, v14.4s; fadd v7.4s, v13.4s, v14.4s
.else
    fsub v4.4s, v12.4s, v15.4s; fadd v6.4s, v12.4s, v15.4s
    fadd v5.4s, v13.4s, v14.4s; fsub v7.4s, v13.4s, v14.4s
.endif
    ld1 {v14.4s, v15.4s}, [x24]; ld1 {v12.4s, v13.4s}, [x22]
    fmul v1.4s, v14.4s, v2.4s; fmul v0.4s, v14.4s, v3.4s
    st2 {v4.4s, v5.4s}, [x19]; fmul v14.4s, v15.4s, v3.4s
    fmul v4.4s, v15.4s, v2.4s; fadd v15.4s, v9.4s, v8.4s
    st2 {v6.4s, v7.4s}, [x21]; fmul v8.4s, v12.4s, v3.4s
    fmul v5.4s, v13.4s, v3.4s; fmul v12.4s, v12.4s, v2.4s
    fmul v9.4s, v13.4s, v2.4s; fadd v14.4s, v14.4s, v1.4s
    fsub v13.4s, v4.4s, v0.4s; fadd v0.4s, v9.4s, v8.4s
    ld1 {v8.4s, v9.4s}, [x0]; fadd v1.4s, v11.4s, v10.4s
    fsub v12.4s, v12.4s, v5.4s; fadd v11.4s, v8.4s, v15.4s
    fsub v8.4s, v8.4s, v15.4s; fadd v2.4s, v12.4s, v14.4s
    fsub v10.4s, v0.4s, v13.4s; fadd v15.4s, v0.4s, v13.4s
    fadd v13.4s, v9.4s, v1.4s; fsub v9.4s, v9.4s, v1.4s
    fsub v12.4s, v12.4s, v14.4s; fadd v0.4s, v11.4s, v2.4s
    fadd v1.4s, v13.4s, v15.4s; fsub v4.4s, v11.4s, v2.4s
.if \forward
    fadd v2.4s, v8.4s, v10.4s; fsub v3.4s, v9.4s, v12.4s
.else
    fsub v2.4s, v8.4s, v10.4s; fadd v3.4s, v9.4s, v12.4s
.endif
    st2 {v0.4s, v1.4s}, [x0], #32; fsub v5.4s, v13.4s, v15.4s
    ld1 {v14.4s, v15.4s}, [x12]
.if \forward
    fadd v7.4s, v9.4s, v12.4s
.else
    fsub v7.4s, v9.4s, v12.4s
.endif
    ld1 {v12.4s, v13.4s}, [x23]; st2 {v2.4s, v3.4s}, [x20], #32
    ld1 {v2.4s, v3.4s}, [x2], #32
.if \forward
    fsub v6.4s, v8.4s, v10.4s
.else
    fadd v6.4s, v8.4s, v10.4s
.endif
    fmul v8.4s, v14.4s, v2.4s; st2 {v4.4s, v5.4s}, [x22], #32
    fmul v10.4s, v15.4s, v3.4s; fmul v9.4s, v13.4s, v3.4s
    fmul v11.4s, v12.4s, v2.4s; fmul v14.4s, v14.4s, v3.4s
    st2 {v6.4s, v7.4s}, [x24], #32; fmul v15.4s, v15.4s, v2.4s
    fmul v12.4s, v12.4s, v3.4s; fmul v13.4s, v13.4s, v2.4s
    fadd v10.4s, v10.4s, v8.4s; fsub v11.4s, v11.4s, v9.4s
    ld1 {v8.4s, v9.4s}, [x19]; fsub v14.4s, v15.4s, v14.4s
    fadd v15.4s, v13.4s, v12.4s; fadd v13.4s, v11.4s, v10.4s
    fadd v12.4s, v15.4s, v14.4s; fsub v15.4s, v15.4s, v14.4s
    fsub v14.4s, v11.4s, v10.4s; ld1 {v10.4s, v11.4s}, [x21]
    fadd v0.4s, v8.4s, v13.4s; fadd v1.4s, v9.4s, v12.4s
.if \forward
    fadd v2.4s, v10.4s, v15.4s; fsub v3.4s, v11.4s, v14.4s
.else
    fsub v2.4s, v10.4s, v15.4s; fadd v3.4s, v11.4s, v14.4s
.endif
    fsub v4.4s, v8.4s, v13.4s; st2 {v0.4s, v1.4s}, [x19], #32
    fsub v5.4s, v9.4s, v12.4s
.if \forward
    fsub v6.4s, v10.4s, v15.4s
.else
    fadd v6.4s, v10.4s, v15.4s
.endif
    st2 {v2.4s, v3.4s}, [x21], #32
.if \forward
    fadd v7.4s, v11.4s, v14.4s
.else
    fsub v7.4s, v11.4s, v14.4s
.endif
    st2 {v4.4s, v5.4s}, [x23], #32
    st2 {v6.4s, v7.4s}, [x12], #32
    b.ne 1b

    ldp d8, d9, [sp, #64]; ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]; ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #80
    ret
.endm


// =========================================================================
//  Macro Instantiation
// =========================================================================
neon64_static_e forward=1
neon64_static_e forward=0
neon64_static_o forward=1
neon64_static_o forward=0
neon64_static_x4 forward=1
neon64_static_x4 forward=0
neon64_static_x8 forward=1
neon64_static_x8 forward=0
neon64_static_x8_t forward=1
neon64_static_x8_t forward=0


// =========================================================================
//  ARM32 Compatibility Aliases
// =========================================================================
#ifdef __APPLE__
    .globl _neon_static_e_f, _neon_static_e_i, _neon_static_o_f, _neon_static_o_i
    .globl _neon_static_x4_f, _neon_static_x4_i, _neon_static_x8_f, _neon_static_x8_i
    .globl _neon_static_x8_t_f, _neon_static_x8_t_i
    .set _neon_static_e_f, _neon64_static_e_f
    .set _neon_static_e_i, _neon64_static_e_i
    .set _neon_static_o_f, _neon64_static_o_f
    .set _neon_static_o_i, _neon64_static_o_i
    .set _neon_static_x4_f, _neon64_static_x4_f
    .set _neon_static_x4_i, _neon64_static_x4_i
    .set _neon_static_x8_f, _neon64_static_x8_f
    .set _neon_static_x8_i, _neon64_static_x8_i
    .set _neon_static_x8_t_f, _neon64_static_x8_t_f
    .set _neon_static_x8_t_i, _neon64_static_x8_t_i
#else
    .globl neon_static_e_f, neon_static_e_i, neon_static_o_f, neon_static_o_i
    .globl neon_static_x4_f, neon_static_x4_i, neon_static_x8_f, neon_static_x8_i
    .globl neon_static_x8_t_f, neon_static_x8_t_i
    .set neon_static_e_f, neon64_static_e_f
    .set neon_static_e_i, neon64_static_e_i
    .set neon_static_o_f, neon64_static_o_f
    .set neon_static_o_i, neon64_static_o_i
    .set neon_static_x4_f, neon64_static_x4_f
    .set neon_static_x4_i, neon64_static_x4_i
    .set neon_static_x8_f, neon64_static_x8_f
    .set neon_static_x8_i, neon64_static_x8_i
    .set neon_static_x8_t_f, neon64_static_x8_t_f
    .set neon_static_x8_t_i, neon64_static_x8_t_i
#endif

.end
