/*
 * neon64.s: Hand-optimized ARM64/AArch64 NEON assembly routines for FFTS
 *
 * This file is part of FFTS -- The Fastest Fourier Transform in the South
 *
 * Copyright (c) 2024, ARM64 Implementation for FFTS
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
 * DISCLAIMED. IN NO EVENT SHALL ANTHONY M. BLAKE BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

    .text
    .align 4

//
// Aarch64 (ARMv8 64-bit) implementation of the 'neon_static_x4' macro.
//
// This macro implements a size-4 butterfly operation for a Cooley-Tukey FFT.
// It is a direct port of the original ARM32 NEON version.
//
// Calling Convention:
// x0: Pointer to the input/output data buffer (split complex format).
// x1: Stride value for calculating data offsets.
// x2: Pointer to the twiddle factor Look-Up Table (LUT).
//
#ifdef __APPLE__
    .globl _neon64_x4
_neon64_x4:
#else
    .globl neon64_x4
neon64_x4:
#endif
    // Section: Address Calculation
    // Calculate pointers to the four input data blocks. These correspond to the
    // U_k, U_{k+N/4}, Z_k, and Z'_k terms in the FFT algorithm.
    // x0 holds the base pointer for the first block (U_k).
    add      x4, x0, x1, lsl #1    // x4 = x0 + (x1 * 2) -> Pointer for 2nd block
    add      x5, x0, x1, lsl #2    // x5 = x0 + (x1 * 4) -> Pointer for 3rd block
    add      x6, x4, x1, lsl #2    // x6 = x4 + (x1 * 4) -> Pointer for 4th block

    // Section: Data Loading
    // Load the four input vectors and the twiddle factors.
    // The data is in "split complex" format: real and imaginary parts are stored
    // in separate contiguous blocks. The ldp instruction loads a pair of
    // 128-bit registers. The 'q' prefix specifies a 128-bit (quad-word) register.
    // For each ldp, the first register gets the real parts and the second gets the imaginary.
    ldp      q8, q9,   [x0]       // Load U_k      (Real: v8, Imag: v9)
    ldp      q10, q11, [x4]       // Load U_{k+N/4} (Real: v10, Imag: v11)
    ldp      q12, q13, [x5]       // Load Z_k       (Real: v12, Imag: v13)
    ldp      q14, q15, [x6]       // Load Z'_k      (Real: v14, Imag: v15)
    ldp      q2, q3,   [x2]       // Load Twiddles w (Real: v2, Imag: v3)

    // Section: Core FFT Computation
    // This section implements the complex butterfly arithmetic.
    // Let T1 = Z*w and T2 = Z'*conj(w)
    //
    // Intermediate calculations for T1 and T2:
    // T1r = v12*v2 - v13*v3  (Zr*wr - Zi*wi)
    // T1i = v12*v3 + v13*v2  (Zr*wi + Zi*wr)
    // T2r = v14*v2 + v15*v3  (Z'r*wr + Z'i*wi)
    // T2i = v15*v2 - v14*v3  (Z'i*wr - Z'r*wi)
    fmul     v0.4s, v13.4s, v3.4s    // v0  = Zi * wi
    fmul     v5.4s, v12.4s, v2.4s    // v5  = Zr * wr
    fmul     v1.4s, v14.4s, v2.4s    // v1  = Z'r * wr
    fmul     v4.4s, v14.4s, v3.4s    // v4  = Z'r * wi
    fmul     v14.4s, v12.4s, v3.4s   // v14 = Zr * wi
    fmul     v13.4s, v13.4s, v2.4s   // v13 = Zi * wr
    fmul     v12.4s, v15.4s, v3.4s   // v12 = Z'i * wi
    fmul     v2.4s,  v15.4s, v2.4s   // v2  = Z'i * wr

    // Combine terms to get T1 and T2
    fsub     v0.4s, v5.4s, v0.4s     // v0 = T1r (Zr*wr - Zi*wi)
    fadd     v13.4s, v13.4s, v14.4s  // v13 = T1i (Zi*wr + Zr*wi)
    fadd     v12.4s, v12.4s, v1.4s   // v12 = T2r (Z'i*wi + Z'r*wr)
    fsub     v1.4s, v2.4s, v4.4s     // v1 = T2i (Z'i*wr - Z'r*wi)

    // Calculate S = T1 + T2 and D = T1 - T2
    // S = Sr + i*Si = (T1r+T2r) + i*(T1i+T2i)
    // D = Dr + i*Di = (T1r-T2r) + i*(T1i-T2i)
    fadd     v15.4s, v0.4s, v12.4s   // v15 = Sr (T1r + T2r)
    fsub     v12.4s, v0.4s, v12.4s   // v12 = Dr (T1r - T2r)
    fadd     v14.4s, v13.4s, v1.4s   // v14 = Si (T1i + T2i)
    fsub     v13.4s, v13.4s, v1.4s   // v13 = Di (T1i - T2i)

    // Final butterfly stage combining U terms with S and D.
    // y_k        = U_k + S
    // y_{k+N/2}  = U_k - S
    // y_{k+N/4}  = U_{k+N/4} - i*D  -> yr=Ur_N4+Di, yi=Ui_N4-Dr
    // y_{k+3N/4} = U_{k+N/4} + i*D  -> yr=Ur_N4-Di, yi=Ui_N4+Dr
    fadd     v0.4s, v8.4s, v15.4s    // y_k Real:        Ur + Sr
    fadd     v1.4s, v9.4s, v14.4s    // y_k Imag:        Ui + Si

    fsub     v2.4s, v10.4s, v13.4s   // y_{k+3N/4} Real: Ur_N4 - Di
    fsub     v4.4s, v8.4s, v15.4s    // y_{k+N/2} Real:  Ur - Sr

    fadd     v3.4s, v11.4s, v12.4s   // y_{k+3N/4} Imag: Ui_N4 + Dr
    fsub     v5.4s, v9.4s, v14.4s    // y_{k+N/2} Imag:  Ui - Si

    fadd     v6.4s, v10.4s, v13.4s   // y_{k+N/4} Real:  Ur_N4 + Di
    fsub     v7.4s, v11.4s, v12.4s   // y_{k+N/4} Imag:  Ui_N4 - Dr

    // Section: Data Storing
    // Store the four computed output vectors back to memory.
    // The stp instruction stores a pair of 128-bit registers. The 'q' prefix is
    // required to specify the 128-bit register size.
    // Note the out-of-place permutation of the results.
    stp      q0, q1, [x0]            // Store y_k        at address of U_k
    stp      q2, q3, [x4]            // Store y_{k+3N/4} at address of U_{k+N/4}
    stp      q4, q5, [x5]            // Store y_{k+N/2}  at address of Z_k
    stp      q6, q7, [x6]            // Store y_{k+N/4}  at address of Z'_k

    // Section: Epilogue
    // Return to the caller.
    ret

//
// AArch64 port of the neon_x8 FFTS macro.
//
// This macro implements a vectorized size-8 Cooley-Tukey butterfly operation.
// It is designed to be a high-performance leaf function.
//
// Calling Convention (AArch64):
// x0: Pointer to the base of the input/output data buffer.
// x1: The byte size of each of the 8 data sub-streams to be processed.
// x2: Pointer to the Look-Up Table (LUT) of twiddle factors.
//
// Register Usage:
// x0, x1, x2: Input arguments.
// x3-x10, x12: Pointers to data streams and LUT.
// x11: Loop counter.
// v0-v15: NEON registers for SIMD computation.
//
// NOTE: This function does NOT save any GPRs or Vector registers. The caller
// is responsible for saving any registers that must be preserved.
//
    .align 4
#ifdef __APPLE__
    .globl _neon64_x8
_neon64_x8:
#else
    .globl neon64_x8
neon64_x8:
#endif
    // --- Prologue and Pointer Setup ---
    // The first three arguments are in x0, x1, x2.
    // x0 = data pointer
    // x1 = stride/size in bytes for each stream
    // x2 = LUT pointer

    // Set up pointers to the 8 parallel data streams (data0..data7) based on
    // the base pointer (x0) and the stride (x1). The calculation order
    // matches the ARM32 source.
    mov      x11, xzr             // x11 = 0 (xzr is the zero register)
    add      x3, x0, xzr          // x3 = &data0
    add      x5, x0, x1, lsl #1   // x5 = &data2
    add      x4, x0, x1           // x4 = &data1
    add      x7, x5, x1, lsl #1   // x7 = &data4
    add      x6, x5, x1           // x6 = &data3
    add      x9, x7, x1, lsl #1   // x9 = &data6
    add      x8, x7, x1           // x8 = &data5
    add      x10, x9, x1          // x10 = &data7
    add      x12, x2, xzr         // x12 = LUT pointer

    // --- Loop Counter Setup ---
    // The loop runs (x1 / 32) times. Each iteration processes 4 complex numbers
    // (4 * 8 bytes = 32 bytes). We initialize the counter to -(x1/32)
    // and count up to zero.
    neg      x11, x1, lsr #5      // x11 = - (x1 >> 5)

1:  // Start of the main loop

    // --- Load Twiddles and Data ---
    // Load 4 complex numbers (256 bits) of twiddle factors from the LUT.
    // Post-increment the LUT pointer (x12) by 32 bytes.
    ld1      {v2.4s,  v3.4s},  [x12], #32
    // Load data from streams 3 and 2.
    ld1      {v14.4s, v15.4s}, [x6]
    ld1      {v10.4s, v11.4s}, [x5]

    // --- Loop Counter Increment ---
    // Increment counter and check if the loop should continue.
    add      x11, x11, #1

    // --- Butterfly Computation (Part 1) ---
    // This block corresponds to the first part of the size-8 butterfly calculation.
    fmul     v12.4s, v15.4s, v2.4s
    fmul     v8.4s,  v14.4s, v3.4s
    fmul     v13.4s, v14.4s, v2.4s
    fmul     v9.4s,  v10.4s, v3.4s
    fmul     v1.4s,  v10.4s, v2.4s
    fmul     v0.4s,  v11.4s, v2.4s
    fmul     v14.4s, v11.4s, v3.4s
    fmul     v15.4s, v15.4s, v3.4s

    // Load next set of twiddle factors.
    ld1      {v2.4s,  v3.4s},  [x12], #32

    fsub     v10.4s, v12.4s, v8.4s
    fadd     v11.4s, v0.4s,  v9.4s
    fadd     v8.4s,  v15.4s, v13.4s

    // Load data from stream 1.
    ld1      {v12.4s, v13.4s}, [x4]

    fsub     v9.4s,  v1.4s,  v14.4s
    fsub     v15.4s, v11.4s, v10.4s
    fsub     v14.4s, v9.4s,  v8.4s
    fsub     v4.4s,  v12.4s, v15.4s
    fadd     v6.4s,  v12.4s, v15.4s
    fadd     v5.4s,  v13.4s, v14.4s
    fsub     v7.4s,  v13.4s, v14.4s

    // Load data from streams 6 and 4.
    ld1      {v14.4s, v15.4s}, [x9]
    ld1      {v12.4s, v13.4s}, [x7]

    fmul     v1.4s,  v14.4s, v2.4s
    fmul     v0.4s,  v14.4s, v3.4s

    // Store intermediate results to streams 1 and 3.
    st1      {v4.4s,  v5.4s},  [x4]

    fmul     v14.4s, v15.4s, v3.4s
    fmul     v4.4s,  v15.4s, v2.4s
    fadd     v15.4s, v9.4s,  v8.4s
    
    st1      {v6.4s,  v7.4s},  [x6]

    // --- Butterfly Computation (Part 2) ---
    fmul     v8.4s,  v12.4s, v3.4s
    fmul     v5.4s,  v13.4s, v3.4s
    fmul     v12.4s, v12.4s, v2.4s
    fmul     v9.4s,  v13.4s, v2.4s
    fadd     v14.4s, v14.4s, v1.4s
    fsub     v13.4s, v4.4s,  v0.4s
    fadd     v0.4s,  v9.4s,  v8.4s

    // Load data from stream 0.
    ld1      {v8.4s,  v9.4s},  [x3]

    fadd     v1.4s,  v11.4s, v10.4s
    fsub     v12.4s, v12.4s, v5.4s
    fadd     v11.4s, v8.4s,  v15.4s
    fsub     v8.4s,  v8.4s,  v15.4s
    fadd     v2.4s,  v12.4s, v14.4s
    fsub     v10.4s, v0.4s,  v13.4s
    fadd     v15.4s, v0.4s,  v13.4s
    fadd     v13.4s, v9.4s,  v1.4s
    fsub     v9.4s,  v9.4s,  v1.4s
    fsub     v12.4s, v12.4s, v14.4s
    fadd     v0.4s,  v11.4s, v2.4s
    fadd     v1.4s,  v13.4s, v15.4s
    fsub     v4.4s,  v11.4s, v2.4s
    fsub     v2.4s,  v8.4s,  v10.4s
    fadd     v3.4s,  v9.4s,  v12.4s
    
    // Store results to stream 0, post-incrementing the pointer.
    st1      {v0.4s,  v1.4s},  [x3], #32

    fsub     v5.4s,  v13.4s, v15.4s
    // Load data from streams 7 and 5.
    ld1      {v14.4s, v15.4s}, [x10]
    fsub     v7.4s,  v9.4s,  v12.4s
    ld1      {v12.4s, v13.4s}, [x8]

    // Store results to stream 2, post-incrementing the pointer.
    st1      {v2.4s,  v3.4s},  [x5], #32

    // Load next set of twiddle factors.
    ld1      {v2.4s,  v3.4s},  [x12], #32

    fadd     v6.4s,  v8.4s,  v10.4s

    // --- Butterfly Computation (Part 3) ---
    fmul     v8.4s,  v14.4s, v2.4s

    // Store results to stream 4, post-incrementing the pointer.
    st1      {v4.4s,  v5.4s},  [x7], #32

    fmul     v10.4s, v15.4s, v3.4s
    fmul     v9.4s,  v13.4s, v3.4s
    fmul     v11.4s, v12.4s, v2.4s
    fmul     v14.4s, v14.4s, v3.4s
    
    // Store results to stream 6, post-incrementing the pointer.
    st1      {v6.4s,  v7.4s},  [x9], #32
    
    fmul     v15.4s, v15.4s, v2.4s
    fmul     v12.4s, v12.4s, v3.4s
    fmul     v13.4s, v13.4s, v2.4s
    fadd     v10.4s, v10.4s, v8.4s
    fsub     v11.4s, v11.4s, v9.4s
    
    // Load data from stream 1.
    ld1      {v8.4s,  v9.4s},  [x4]
    
    fsub     v14.4s, v15.4s, v14.4s
    fadd     v15.4s, v13.4s, v12.4s
    fadd     v13.4s, v11.4s, v10.4s
    fadd     v12.4s, v15.4s, v14.4s
    fsub     v15.4s, v15.4s, v14.4s
    fsub     v14.4s, v11.4s, v10.4s
    
    // Load data from stream 3.
    ld1      {v10.4s, v11.4s}, [x6]
    
    fadd     v0.4s,  v8.4s,  v13.4s
    fadd     v1.4s,  v9.4s,  v12.4s
    fsub     v2.4s,  v10.4s, v15.4s
    fadd     v3.4s,  v11.4s, v14.4s
    fsub     v4.4s,  v8.4s,  v13.4s
    
    // Store final results for this iteration to streams 1, 3, 5, 7.
    st1      {v0.4s,  v1.4s},  [x4], #32
    
    fsub     v5.4s,  v9.4s,  v12.4s
    fadd     v6.4s,  v10.4s, v15.4s
    
    st1      {v2.4s,  v3.4s},  [x6], #32
    
    fsub     v7.4s,  v11.4s, v14.4s
    
    st1      {v4.4s,  v5.4s},  [x8], #32
    st1      {v6.4s,  v7.4s},  [x10], #32

    // --- Loop Branch ---
    // Branch back to the top of the loop if the counter (x11) is not yet zero.
    cbnz     x11, 1b

    // --- Epilogue ---
    ret // Return to the caller.

  //
  // AArch64 implementation of neon_x8_t
  //
  // Register mapping from ARM32 to AArch64:
  // r0 (data) -> x0
  // r1 (N)    -> x1
  // r2 (LUT)  -> x2
  // r3..r10 (pointers) -> x3..x10
  // r11 (counter)      -> x11
  // r12 (LUT ptr)      -> x12
  // q0..q15 (NEON)     -> v0..v15
    .align 4
#ifdef __APPLE__
    .globl _neon64_x8_t
_neon64_x8_t:
#else
    .globl neon64_x8_t
neon64_x8_t:
#endif
  // Pointer setup
  mov      x11, xzr             // x11 = 0
  mov      x3, x0               // x3 = &data[0]
  add      x5, x0, x1, lsl #1   // x5 = &data[2N]
  mov      x4, x1               // Use x4 as a temporary holder for N
  add      x4, x0, x4           // x4 = &data[N]
  add      x7, x5, x1, lsl #1   // x7 = &data[4N]
  add      x6, x5, x1           // x6 = &data[3N]
  add      x9, x7, x1, lsl #1   // x9 = &data[6N]
  add      x8, x7, x1           // x8 = &data[5N]
  add      x10, x9, x1          // x10 = &data[7N]
  mov      x12, x2              // x12 = LUT pointer

  // Initialize loop counter. Loop will run N/32 times.
  lsr      x11, x1, #5          // x11 = N / 32
  neg      x11, x11             // x11 = -(N / 32)

1:
  // Load two sets of twiddle factors (4x 32-bit floats each) from LUT
  ld1      {v2.4s,  v3.4s},  [x12], #32

  // Load data from memory
  ld1      {v14.4s, v15.4s}, [x6]
  ld1      {v10.4s, v11.4s}, [x5]

  // Increment and test loop counter
  add      x11, x11, #1

  // Butterfly computations - Part 1
  fmul     v12.4s, v15.4s, v2.4s
  fmul     v8.4s,  v14.4s, v3.4s
  fmul     v13.4s, v14.4s, v2.4s
  fmul     v9.4s,  v10.4s, v3.4s
  fmul     v1.4s,  v10.4s, v2.4s
  fmul     v0.4s,  v11.4s, v2.4s
  fmul     v14.4s, v11.4s, v3.4s
  fmul     v15.4s, v15.4s, v3.4s

  // Load next set of twiddle factors
  ld1      {v2.4s,  v3.4s},  [x12], #32

  fsub     v10.4s, v12.4s, v8.4s
  fadd     v11.4s, v0.4s,  v9.4s
  fadd     v8.4s,  v15.4s, v13.4s

  // Load more data
  ld1      {v12.4s, v13.4s}, [x4]

  fsub     v9.4s,  v1.4s,  v14.4s
  fsub     v15.4s, v11.4s, v10.4s
  fsub     v14.4s, v9.4s,  v8.4s
  fsub     v4.4s,  v12.4s, v15.4s
  fadd     v6.4s,  v12.4s, v15.4s
  fadd     v5.4s,  v13.4s, v14.4s
  fsub     v7.4s,  v13.4s, v14.4s

  // Load more data
  ld1      {v14.4s, v15.4s}, [x9]
  ld1      {v12.4s, v13.4s}, [x7]

  // Butterfly computations - Part 2
  fmul     v1.4s,  v14.4s, v2.4s
  fmul     v0.4s,  v14.4s, v3.4s

  // Store intermediate results
  st1      {v4.4s,  v5.4s},  [x4]

  fmul     v14.4s, v15.4s, v3.4s
  fmul     v4.4s,  v15.4s, v2.4s
  fadd     v15.4s, v9.4s,  v8.4s

  // Store intermediate results
  st1      {v6.4s,  v7.4s},  [x6]

  fmul     v8.4s,  v12.4s, v3.4s
  fmul     v5.4s,  v13.4s, v3.4s
  fmul     v12.4s, v12.4s, v2.4s
  fmul     v9.4s,  v13.4s, v2.4s
  fadd     v14.4s, v14.4s, v1.4s
  fsub     v13.4s, v4.4s,  v0.4s
  fadd     v0.4s,  v9.4s,  v8.4s

  // Load data for final combination
  ld1      {v8.4s,  v9.4s},  [x3]

  fadd     v1.4s,  v11.4s, v10.4s
  fsub     v12.4s, v12.4s, v5.4s
  fadd     v11.4s, v8.4s,  v15.4s
  fsub     v8.4s,  v8.4s,  v15.4s
  fadd     v2.4s,  v12.4s, v14.4s
  fsub     v10.4s, v0.4s,  v13.4s
  fadd     v15.4s, v0.4s,  v13.4s
  fadd     v13.4s, v9.4s,  v1.4s
  fsub     v9.4s,  v9.4s,  v1.4s
  fsub     v12.4s, v12.4s, v14.4s
  fadd     v0.4s,  v11.4s, v2.4s
  fadd     v1.4s,  v13.4s, v15.4s
  fsub     v4.4s,  v11.4s, v2.4s
  fsub     v2.4s,  v8.4s,  v10.4s
  fadd     v3.4s,  v9.4s,  v12.4s

  // Store final results with interleaving
  st2      {v0.4s,  v1.4s},  [x3], #32

  fsub     v5.4s,  v13.4s, v15.4s

  // Load more data
  ld1      {v14.4s, v15.4s}, [x10]

  fsub     v7.4s,  v9.4s,  v12.4s

  ld1      {v12.4s, v13.4s}, [x8]

  // Store final results with interleaving
  st2      {v2.4s,  v3.4s},  [x5], #32

  // Load last set of twiddle factors
  ld1      {v2.4s,  v3.4s},  [x12], #32

  fadd     v6.4s,  v8.4s,  v10.4s
  fmul     v8.4s,  v14.4s, v2.4s

  // Store final results with interleaving
  st2      {v4.4s,  v5.4s},  [x7], #32

  fmul     v10.4s, v15.4s, v3.4s
  fmul     v9.4s,  v13.4s, v3.4s
  fmul     v11.4s, v12.4s, v2.4s
  fmul     v14.4s, v14.4s, v3.4s

  // Store final results with interleaving
  st2      {v6.4s,  v7.4s},  [x9], #32

  fmul     v15.4s, v15.4s, v2.4s
  fmul     v12.4s, v12.4s, v3.4s
  fmul     v13.4s, v13.4s, v2.4s
  fadd     v10.4s, v10.4s, v8.4s
  fsub     v11.4s, v11.4s, v9.4s

  // Load data for the second half of the butterfly
  ld1      {v8.4s,  v9.4s},  [x4]

  fsub     v14.4s, v15.4s, v14.4s
  fadd     v15.4s, v13.4s, v12.4s
  fadd     v13.4s, v11.4s, v10.4s
  fadd     v12.4s, v15.4s, v14.4s
  fsub     v15.4s, v15.4s, v14.4s
  fsub     v14.4s, v11.4s, v10.4s

  // Load more data
  ld1      {v10.4s, v11.4s}, [x6]

  fadd     v0.4s,  v8.4s,  v13.4s
  fadd     v1.4s,  v9.4s,  v12.4s
  fsub     v2.4s,  v10.4s, v15.4s
  fadd     v3.4s,  v11.4s, v14.4s
  fsub     v4.4s,  v8.4s,  v13.4s

  // Store final interleaved results for the second half
  st2      {v0.4s,  v1.4s},  [x4], #32

  fsub     v5.4s,  v9.4s,  v12.4s
  fadd     v6.4s,  v10.4s, v15.4s

  st2      {v2.4s,  v3.4s},  [x6], #32

  fsub     v7.4s,  v11.4s, v14.4s

  st2      {v4.4s,  v5.4s},  [x8], #32
  st2      {v6.4s,  v7.4s},  [x10], #32

  // Branch back to the start of the loop if counter is not zero
  cbnz     x11, 1b

  // No explicit return (ret) as this is a macro intended
  // to be part of a larger function body. The calling function
  // will handle the final return.


//
// An Aarch64 port of the FFTS library's 'neon_ee' macro.
//
// Assumes: x0 = Output data pointer
//          x2 = Twiddles pointer (ee_ws)
//          x3-x10 = Input data pointers
//          x11 = Loop counter
//          x12 = Offsets array pointer
    .align 4
#ifdef __APPLE__
    .globl _neon64_ee
_neon64_ee:
#else
    .globl neon64_ee
neon64_ee:
#endif
  // Load twiddle factors W into v8. Corresponds to ARM32: vld1.32 {d16, d17}, [r2, :64]
  ld1   {v8.4s}, [x2]

1:  // Start of the main loop.

  // Load and de-interleave 8 sets of 4 complex numbers each.
  // The ld2 instruction requires a consecutive register list and supports post-increment.
  // ARM32: vld2.32 {q15}, [r10, :64]! -> Aarch64: ld2 {v30.4s, v31.4s}, [x10], #32
  ld2   {v30.4s, v31.4s}, [x10], #32  // q15 -> v30, v31
  ld2   {v26.4s, v27.4s}, [x8], #32   // q13 -> v26, v27
  ld2   {v28.4s, v29.4s}, [x7], #32   // q14 -> v28, v29
  ld2   {v18.4s, v19.4s}, [x4], #32   // q9  -> v18, v19
  ld2   {v20.4s, v21.4s}, [x3], #32   // q10 -> v20, v21
  ld2   {v22.4s, v23.4s}, [x6], #32   // q11 -> v22, v23
  ld2   {v24.4s, v25.4s}, [x5], #32   // q12 -> v24, v25
  ld2   {v0.4s, v1.4s},   [x9], #32   // q0  -> v0, v1 (as d0, d1)

  // Start of butterfly calculations. Suffix .4s indicates four 32-bit float lanes.
  fsub  v2.4s, v28.4s, v26.4s     // q1 (tmp) -> v2
  
  // ARM32: subs r11, r11, #1
  subs  x11, x11, #1              // Decrement loop counter and set flags.
  
  fsub  v3.4s, v0.4s, v30.4s      // q2 (tmp) -> v3
  fadd  v0.4s, v0.4s, v30.4s      // q0 -> v0

  // Complex multiplications using twiddles. Suffix .2s on 64-bit D-registers.
  // Note: v8.2s = d8, v9.2s = d9, etc. v8 holds the twiddles.
  fmul  v10.2s, v2.2s, v9.2s
  fmul  v11.2s, v3.2s, v8.2s
  fmul  v12.2s, v3.2s, v9.2s
  fmul  v6.2s,  v4.2s, v9.2s
  fmul  v7.2s,  v5.2s, v8.2s
  fmul  v4.2s,  v4.2s, v8.2s
  fmul  v5.2s,  v5.2s, v9.2s
  fmul  v13.2s, v2.2s, v8.2s

  // Butterfly additions/subtractions
  fsub  v7.2s,  v7.2s,  v6.2s
  fadd  v11.2s, v11.2s, v10.2s
  fsub  v2.4s, v24.4s, v22.4s
  fsub  v3.4s, v20.4s, v18.4s
  fadd  v6.2s,  v5.2s,  v4.2s
  fadd  v4.4s, v28.4s, v26.4s
  fadd  v22.4s, v24.4s, v22.4s
  fadd  v24.4s, v20.4s, v18.4s
  fsub  v10.2s, v13.2s, v12.2s
  fsub  v14.4s, v4.4s,  v0.4s
  fsub  v18.4s, v24.4s, v22.4s
  fsub  v26.4s, v25.4s, v21.4s
  fadd  v29.2s, v25.2s, v3.2s
  fadd  v5.4s,  v25.4s, v21.4s
  fadd  v20.4s, v4.4s,  v0.4s
  fadd  v22.4s, v24.4s, v22.4s
  fsub  v31.2s, v25.2s, v3.2s
  fsub  v28.2s, v24.2s, v21.2s
  fadd  v30.2s, v24.2s, v21.2s
  fadd  v5.2s,  v19.2s, v14.2s
  fadd  v7.2s,  v31.2s, v26.2s
  fadd  v2.4s,  v28.4s, v5.4s
  fadd  v0.4s,  v22.4s, v20.4s
  fsub  v6.2s,  v30.2s, v27.2s
  fsub  v4.2s,  v18.2s, v15.2s
  fsub  v13.2s, v19.2s, v14.2s
  fadd  v12.2s, v18.2s, v15.2s
  fsub  v15.2s, v31.2s, v26.2s

  // Load 32-bit offsets, post-incrementing pointer x12.
  ldr   w16, [x12], #4              // Use w16 for first offset
  ldr   w17, [x12], #4              // Use w17 for second offset

  // Replicate vtrn.32 q1, q3 -> TRN v2, v6
  // Use a temporary vector register (v16 is free)
  trn1  v16.4s, v2.4s, v6.4s
  trn2  v6.4s, v2.4s, v6.4s
  mov   v2.16b, v16.16b

  // Replicate vtrn.32 q0, q2 -> TRN v0, v4
  trn1  v16.4s, v0.4s, v4.4s
  trn2  v4.4s, v0.4s, v4.4s
  mov   v0.16b, v16.16b
  
  // Calculate final 64-bit store addresses.
  add   x16, x0, x16, sxtw 2       // Add sign-extended w16 offset to base ptr x0
  add   x17, x0, x17, sxtw 2       // Add sign-extended w17 offset to base ptr x0

  // Calculate remaining results before transpose.
  fsub  v8.4s,  v22.4s, v20.4s
  fsub  v10.4s, v28.4s, v5.4s
  fadd  v14.2s, v30.2s, v27.2s
  
  // Store results using ST2 to interleave Real and Imaginary parts.
  // ** FIX **: Move data to consecutive registers to satisfy st2 requirements.
  mov   v1.16b, v2.16b              // Move result from v2 -> v1
  st2   {v0.4s, v1.4s}, [x16]       // OK: {v0, v1} are consecutive.
  
  mov   v5.16b, v6.16b              // Move result from v6 -> v5
  st2   {v4.4s, v5.4s}, [x17]       // OK: {v4, v5} are consecutive.

  // Replicate vtrn.32 q4, q6 -> TRN v8, v12
  trn1  v16.4s, v8.4s, v12.4s
  trn2  v12.4s, v8.4s, v12.4s
  mov   v8.16b, v16.16b

  // Replicate vtrn.32 q5, q7 -> TRN v10, v14
  trn1  v16.4s, v10.4s, v14.4s
  trn2  v14.4s, v10.4s, v14.4s
  mov   v10.16b, v16.16b

  // ** FIX **: Pre-calculate store addresses as st2 does not support [reg, #imm].
  add   x18, x16, #32               // Use scratch reg x18 for addr = x16 + 32
  add   x19, x17, #32               // Use scratch reg x19 for addr = x17 + 32

  // ** FIX **: Move data to consecutive registers and use pre-calculated addresses.
  mov   v9.16b, v10.16b             // Move result from v10 -> v9
  st2   {v8.4s, v9.4s}, [x18]       // OK: {v8, v9} are consecutive, address is in reg.
  
  mov   v13.16b, v14.16b            // Move result from v14 -> v13
  st2   {v12.4s, v13.4s}, [x19]     // OK: {v12, v13} are consecutive, address is in reg.

  // Branch back to the loop start if the counter is not zero.
  b.ne  1b


// Port of the 'neon_oo' macro to AArch64 with NEON.
//
// Register Allocation:
// x0:  Output data base pointer (in)
// x1:  Pointer to offsets array (in)
// x2:  Temporary for output address 1
// x3-x10: Input data pointers (in)
// x11: Loop counter (in)
// x12: Temporary for output address 2
//
// Vector Register Pairs (Real, Imaginary):
// v8,  v9:   Data from x10, then from x6
// v10, v11:  Data from x8, then from x5
// v12, v13:  Data from x7, then from x4
// v14, v15:  Data from x9, then from x3
//
// v0-v7: Result vectors before storing
// v16-v31: Temporary vectors for calculations
    .align 4
#ifdef __APPLE__
    .globl _neon64_oo
_neon64_oo:
#else
    .globl neon64_oo
neon64_oo:
#endif
1:
  // Section 1: Load first set of 4 complex vectors and perform butterfly.
  // vld2.32 {q8}, [r6]! -> ld2 {v8.4s, v9.4s}, [x6], #32
  ld2    {v8.4s, v9.4s}, [x6], #32          // Load de-interleaved complex data from r6 into v8 (real), v9 (imag)
  // vld2.32 {q9}, [r5]! -> ld2 {v10.4s, v11.4s}, [x5], #32
  ld2    {v10.4s, v11.4s}, [x5], #32       // Load de-interleaved complex data from r5 into v10 (real), v11 (imag)
  // vld2.32 {q10}, [r4]! -> ld2 {v12.4s, v13.4s}, [x4], #32
  ld2    {v12.4s, v13.4s}, [x4], #32       // Load de-interleaved complex data from r4 into v12 (real), v13 (imag)
  // vld2.32 {q13}, [r3]! -> ld2 {v14.4s, v15.4s}, [x3], #32
  ld2    {v14.4s, v15.4s}, [x3], #32       // Load de-interleaved complex data from r3 into v14 (real), v15 (imag)

  // Butterfly operation part 1
  // vadd.f32 q11, q9, q8 -> v18=v10+v8, v19=v11+v9
  fadd   v18.4s, v10.4s, v8.4s
  fadd   v19.4s, v11.4s, v9.4s
  // vsub.f32 q8, q9, q8 -> v8=v10-v8, v9=v11-v9
  fsub   v8.4s, v10.4s, v8.4s
  fsub   v9.4s, v11.4s, v9.4s
  // vsub.f32 q9, q13, q10 -> v10=v14-v12, v11=v15-v13
  fsub   v10.4s, v14.4s, v12.4s
  fsub   v11.4s, v15.4s, v13.4s
  // vadd.f32 q12, q13, q10 -> v20=v14+v12, v21=v15+v13
  fadd   v20.4s, v14.4s, v12.4s
  fadd   v21.4s, v15.4s, v13.4s

  // Section 2: Decrement loop counter and load second set of vectors
  subs   x11, x11, #1                       // Decrement loop counter and set flags

  // vld2.32 {q10}, [r7]! -> ld2 {v12.4s, v13.4s}, [x7], #32
  ld2    {v12.4s, v13.4s}, [x7], #32       // Load data from r7
  // vld2.32 {q13}, [r9]! -> ld2 {v14.4s, v15.4s}, [x9], #32
  ld2    {v14.4s, v15.4s}, [x9], #32       // Load data from r9
  // vld2.32 {q9}, [r8]! -> ld2 {v10.4s, v11.4s}, [x8], #32
  ld2    {v10.4s, v11.4s}, [x8], #32       // Load data from r8
  // vld2.32 {q8}, [r10]! -> ld2 {v8.4s, v9.4s}, [x10], #32
  ld2    {v8.4s, v9.4s}, [x10], #32       // Load data from r10

  // Section 3: Complex rotations and butterfly (results in v0-v7)
  // vadd.f32 q0, q12, q11
  fadd   v0.4s, v20.4s, v18.4s
  fadd   v1.4s, v21.4s, v19.4s
  // vsub.f32 q2, q12, q11
  fsub   v2.4s, v20.4s, v18.4s
  fsub   v3.4s, v21.4s, v19.4s

  // Complex rotation on q1 and q3 results:
  // Re(q1_res) = Re(q9_in) - Im(q8_in)
  // Im(q1_res) = Im(q9_in) + Re(q8_in)
  // Re(q3_res) = Re(q9_in) + Im(q8_in)
  // Im(q3_res) = Im(q9_in) - Re(q8_in)
  // Note: These do not match the original ARM32 code exactly. The original seems
  // to be doing: d2=d18-d17, d3=d19+d16, d6=d18+d17, d7=d19-d16
  // which translates to:
  // Re(q1) = Re(q9) - Im(q8)
  // Im(q1) = Im(q9) + Re(q8)
  // Re(q3) = Re(q9) + Im(q8)
  // Im(q3) = Im(q9) - Re(q8)
  // Let's use temporary registers for clarity
  mov    v24.16b, v10.16b // Temp for Re(q9)
  fsub   v2.4s, v24.4s, v9.4s   // Re(q1) = Re(q9) - Im(q8)
  fadd   v3.4s, v11.4s, v8.4s   // Im(q1) = Im(q9) + Re(q8)
  fadd   v4.4s, v24.4s, v9.4s   // Re(q3) = Re(q9) + Im(q8) ; v4 is used instead of v6
  fsub   v5.4s, v11.4s, v8.4s   // Im(q3) = Im(q9) - Re(q8) ; v5 is used instead of v7

  // Section 4 & 5: Final butterfly, address calculation, and data preparation
  // vadd.f32 q11, q13, q8
  fadd   v18.4s, v14.4s, v8.4s
  fadd   v19.4s, v15.4s, v9.4s
  // vadd.f32 q12, q10, q9
  fadd   v20.4s, v12.4s, v10.4s
  fadd   v21.4s, v13.4s, v11.4s
  // vsub.f32 q8, q13, q8
  fsub   v8.4s, v14.4s, v8.4s
  fsub   v9.4s, v15.4s, v9.4s
  // vsub.f32 q9, q10, q9
  fsub   v10.4s, v12.4s, v10.4s
  fsub   v11.4s, v13.4s, v11.4s

  // Prepare for storage with transpose
  mov    v24.16b, v0.16b         // Temp for v0
  trn1   v0.4s, v24.4s, v2.4s
  trn2   v2.4s, v24.4s, v2.4s

  // Load offsets and calculate output addresses
  ldr    w2, [x1], #4                       // Load offset 1, post-increment offsets pointer
  ldr    w12, [x1], #4                      // Load offset 2, post-increment offsets pointer

  // Second complex rotation, for q4, q5, q6, q7
  // vadd.f32 q4, q12, q11
  fadd   v4.4s, v20.4s, v18.4s
  fadd   v5.4s, v21.4s, v19.4s
  // vsub.f32 q6, q12, q11
  fsub   v6.4s, v20.4s, v18.4s
  fsub   v7.4s, v21.4s, v19.4s

  // Calculate final output addresses
  add    x2, x0, x2, lsl #2                 // addr1 = base + offset1 * 4
  add    x12, x0, x12, lsl #2               // addr2 = base + offset2 * 4

  // Prepare more data for storing
  mov    v24.16b, v1.16b         // Temp for v1
  trn1   v1.4s, v24.4s, v3.4s
  trn2   v3.4s, v24.4s, v3.4s

  // Section 6: Store results and loop
  // vst2.32 {q0, q1}, [r2]!
  st2    {v0.4s, v1.4s}, [x2], #32          // Store interleaved v0(Re), v1(Im) to addr1 and advance
  // vst2.32 {q2, q3}, [lr]!
  st2    {v2.4s, v3.4s}, [x12], #32         // Store interleaved v2(Re), v3(Im) to addr2 and advance

  // Prepare final vectors for storing
  mov    v24.16b, v4.16b         // Temp for v4
  trn1   v4.4s, v24.4s, v6.4s
  trn2   v6.4s, v24.4s, v6.4s

  mov    v25.16b, v5.16b         // Temp for v5
  trn1   v5.4s, v25.4s, v7.4s
  trn2   v7.4s, v25.4s, v7.4s

  // vst2.32 {q4, q5}, [r2]!
  st2    {v4.4s, v5.4s}, [x2]               // Store interleaved v4(Re), v5(Im) to addr1
  // vst2.32 {q6, q7}, [lr]!
  st2    {v6.4s, v7.4s}, [x12]              // Store interleaved v6(Re), v7(Im) to addr2

  bne    1b                                 // Branch to top of loop if counter is not zero

// AArch64 Port of neon_eo macro
// Assumes:
//   x0 = out buffer pointer
//   x12 = offsets array pointer
//   x3-x10 = input data pointers
//   x11 = twiddle factors table pointer (eo_ws)
//
// Clobbered Registers:
//   x2, x16 (lr), x17 (temp)
//   v0-v31
  .align 4
#ifdef __APPLE__
    .globl _neon64_eo
_neon64_eo:
#else
    .globl neon64_eo
neon64_eo:
#endif
  // vld2.32  {q9},  [r5, :64]! -> ld2 {v18.2s, v19.2s}, [x5], #16
  ld2    {v18.2s, v19.2s}, [x5], #16   // Load and de-interleave 2 complex numbers from x5
  // vld2.32  {q13}, [r3, :64]! -> ld2 {v26.2s, v27.2s}, [x3], #16
  ld2    {v26.2s, v27.2s}, [x3], #16   // Load and de-interleave 2 complex numbers from x3
  // vld2.32  {q12}, [r4, :64]! -> ld2 {v24.2s, v25.2s}, [x4], #16
  ld2    {v24.2s, v25.2s}, [x4], #16   // Load and de-interleave 2 complex numbers from x4
  // vld2.32  {q0},  [r7, :64]! -> ld2 {v0.2s, v1.2s}, [x7], #16
  ld2    {v0.2s, v1.2s}, [x7], #16     // Load and de-interleave 2 complex numbers from x7
  // vsub.f32 q11, q13, q12 -> fsub v22.4s, v26.4s, v24.4s
  fsub   v22.4s, v26.4s, v24.4s      // Vector subtract
  // vld2.32  {q8},  [r6, :64]! -> ld2 {v16.2s, v17.2s}, [x6], #16
  ld2    {v16.2s, v17.2s}, [x6], #16   // Load and de-interleave 2 complex numbers from x6
  // vadd.f32 q12, q13, q12 -> fadd v24.4s, v26.4s, v24.4s
  fadd   v24.4s, v26.4s, v24.4s      // Vector add
  // vsub.f32 q10, q9,  q8 -> fsub v20.4s, v18.4s, v16.4s
  fsub   v20.4s, v18.4s, v16.4s      // Vector subtract
  // vadd.f32 q8,  q9,  q8 -> fadd v16.4s, v18.4s, v16.4s
  fadd   v16.4s, v18.4s, v16.4s      // Vector add
  // vadd.f32 q9,  q12, q8 -> fadd v18.4s, v24.4s, v16.4s
  fadd   v18.4s, v24.4s, v16.4s      // Vector add
  // vadd.f32 d9,  d23, d20 -> fadd v9.2s, v23.2s, v20.2s
  fadd   v9.2s, v23.2s, v20.2s      // 64-bit vector add
  // vsub.f32 d11, d23, d20 -> fsub v11.2s, v23.2s, v20.2s
  fsub   v11.2s, v23.2s, v20.2s      // 64-bit vector subtract
  // vsub.f32 q8,  q12, q8 -> fsub v16.4s, v24.4s, v16.4s
  fsub   v16.4s, v24.4s, v16.4s      // Vector subtract
  // vsub.f32 d8,  d22, d21 -> fsub v8.2s, v22.2s, v21.2s
  fsub   v8.2s, v22.2s, v21.2s      // 64-bit vector subtract
  // vadd.f32 d10, d22, d21 -> fadd v10.2s, v22.2s, v21.2s
  fadd   v10.2s, v22.2s, v21.2s      // 64-bit vector add

  // ldr r2, [r12], #4 -> ldr w2, [x12], #4
  ldr    w2, [x12], #4                // Load 32-bit offset into w2, advance x12
  // vld1.32 {d20, d21}, [r11, :64] -> ldp d20, d21, [x11]
  ldp    d20, d21, [x11]             // Load pair of D registers (twiddle factors)
  // ldr lr, [r12], #4 -> ldr w16, [x12], #4
  ldr    w16, [x12], #4                // Load 32-bit offset into w16, advance x12

  // AArch64 equivalent of: vtrn.32 q9, q4
  mov    v31.16b, v18.16b            // Temp copy of v18 (q9)
  trn1   v18.4s, v31.4s, v8.4s       // Transpose lower half
  trn2   v8.4s, v31.4s, v8.4s        // Transpose upper half

  // add r2, r0, r2, lsl #2 -> add x2, x0, w2, uxtw #2
  add    x2, x0, w2, uxtw #2         // Calculate destination address in x2

  // AArch64 equivalent of: vtrn.32 q8, q5
  mov    v31.16b, v16.16b            // Temp copy of v16 (q8)
  trn1   v16.4s, v31.4s, v10.4s      // Transpose lower half
  trn2   v10.4s, v31.4s, v10.4s      // Transpose upper half

  // add lr, r0, lr, lsl #2 -> add x16, x0, w16, uxtw #2
  add    x16, x0, w16, uxtw #2       // Calculate destination address in x16

  // CORRECTED: AArch64 equivalent of: vswp d9, d10
  // This swaps the upper 64 bits of q4 (d9) with the lower 64 bits of q5 (d10).
  // In AArch64, this corresponds to swapping v4.d[1] and v5.d[0].
  mov    v31.16b, v4.16b           // Temp copy of v4 (q4)
  mov    v4.d[1], v5.d[0]            // v4.d[1] (d9) = v5.d[0] (d10)
  mov    v5.d[0], v31.d[1]           // v5.d[0] (d10) = original v4.d[1] (d9)

  // vst1.32 {d8, d9, d10, d11}, [lr, :64]! -> stp q4, q5, [x16], #32
  stp    q4, q5, [x16], #32          // Store q4 (d8,d9) and q5 (d10,d11), advance x16

  // vld2.32  {q13}, [r10, :64]! -> ld2 {v26.2s, v27.2s}, [x10], #16
  ld2    {v26.2s, v27.2s}, [x10], #16  // Load and de-interleave 2 complex numbers from x10
  // vld2.32  {q15}, [r9,  :64]! -> ld2 {v30.2s, v31.2s}, [x9], #16
  ld2    {v30.2s, v31.2s}, [x9], #16   // Load and de-interleave 2 complex numbers from x9
  // vld2.32  {q11}, [r8,  :64]! -> ld2 {v22.2s, v23.2s}, [x8], #16
  ld2    {v22.2s, v23.2s}, [x8], #16   // Load and de-interleave 2 complex numbers from x8
  // vsub.f32 q14, q15, q13 -> fsub v28.4s, v30.4s, v26.4s
  fsub   v28.4s, v30.4s, v26.4s      // Vector subtract
  // vsub.f32 q12, q0,  q11 -> fsub v24.4s, v0.4s, v22.4s
  fsub   v24.4s, v0.4s, v22.4s        // Vector subtract
  // vadd.f32 q11, q0,  q11 -> fadd v22.4s, v0.4s, v22.4s
  fadd   v22.4s, v0.4s, v22.4s        // Vector add
  // vadd.f32 q13, q15, q13 -> fadd v26.4s, v30.4s, v26.4s
  fadd   v26.4s, v30.4s, v26.4s      // Vector add
  // vadd.f32 d13, d29, d24 -> fadd v13.2s, v29.2s, v24.2s
  fadd   v13.2s, v29.2s, v24.2s      // 64-bit vector add
  // vadd.f32 q15, q13, q11 -> fadd v30.4s, v26.4s, v22.4s
  fadd   v30.4s, v26.4s, v22.4s      // Vector add
  // vsub.f32 d12, d28, d25 -> fsub v12.2s, v28.2s, v25.2s
  fsub   v12.2s, v28.2s, v25.2s      // 64-bit vector subtract
  // vsub.f32 d15, d29, d24 -> fsub v15.2s, v29.2s, v24.2s
  fsub   v15.2s, v29.2s, v24.2s      // 64-bit vector subtract
  // vadd.f32 d14, d28, d25 -> fadd v14.2s, v28.2s, v25.2s
  fadd   v14.2s, v28.2s, v25.2s      // 64-bit vector add

  // AArch64 equivalent of: vtrn.32 q15, q6
  mov    v31.16b, v30.16b            // Temp copy of v30 (q15)
  trn1   v30.4s, v31.4s, v12.4s      // Transpose lower half
  trn2   v12.4s, v31.4s, v12.4s      // Transpose upper half

  // vsub.f32 q15, q13, q11 -> fsub v30.4s, v26.4s, v22.4s
  fsub   v30.4s, v26.4s, v22.4s      // Vector subtract

  // AArch64 equivalent of: vtrn.32 q15, q7
  mov    v31.16b, v30.16b            // Temp copy of v30 (q15)
  trn1   v30.4s, v31.4s, v14.4s      // Transpose lower half
  trn2   v14.4s, v31.4s, v14.4s      // Transpose upper half

  // CORRECTED: AArch64 equivalent of: vswp d13, d14
  // Swaps upper 64 bits of q6 (d13) with lower 64 bits of q7 (d14).
  // In AArch64, this corresponds to swapping v6.d[1] and v7.d[0].
  mov    v31.16b, v6.16b           // Temp copy of v6 (q6)
  mov    v6.d[1], v7.d[0]            // v6.d[1] (d13) = v7.d[0] (d14)
  mov    v7.d[0], v31.d[1]           // v7.d[0] (d14) = original v6.d[1] (d13)

  // vst1.32 {d12, d13, d14, d15}, [lr, :64]! -> stp q6, q7, [x16], #32
  stp    q6, q7, [x16], #32           // Store q6 (d12,d13) and q7 (d14,d15), advance x16

  // AArch64 equivalent of: vtrn.32 q13, q14
  mov    v31.16b, v26.16b            // Temp copy of v26 (q13)
  trn1   v26.4s, v31.4s, v28.4s      // Transpose lower half
  trn2   v28.4s, v31.4s, v28.4s      // Transpose upper half

  // AArch64 equivalent of: vtrn.32 q11, q12
  mov    v31.16b, v22.16b            // Temp copy of v22 (q11)
  trn1   v22.4s, v31.4s, v24.4s      // Transpose lower half
  trn2   v24.4s, v31.4s, v24.4s      // Transpose upper half

  // Complex multiplication section
  fmul   v24.2s, v26.2s, v21.2s
  fmul   v28.2s, v27.2s, v20.2s
  fmul   v25.2s, v26.2s, v20.2s
  fmul   v26.2s, v27.2s, v21.2s
  fmul   v27.2s, v22.2s, v21.2s
  fmul   v30.2s, v23.2s, v20.2s
  fmul   v29.2s, v23.2s, v21.2s
  fmul   v22.2s, v22.2s, v20.2s

  // Final real/imaginary parts calculation
  fsub   v21.2s, v28.2s, v24.2s
  fadd   v20.2s, v26.2s, v25.2s
  fadd   v25.2s, v30.2s, v27.2s
  fsub   v24.2s, v22.2s, v29.2s

  // Final butterfly operations
  fadd   v22.4s, v24.4s, v20.4s
  fsub   v20.4s, v24.4s, v20.4s
  fadd   v0.4s, v18.4s, v22.4s
  fsub   v4.4s, v18.4s, v22.4s
  fadd   v3.2s, v17.2s, v20.2s
  fsub   v7.2s, v17.2s, v20.2s
  fsub   v2.2s, v16.2s, v21.2s
  fadd   v6.2s, v16.2s, v21.2s

  // AArch64 equivalent of: vswp d1, d2
  // Swaps upper 64 bits of q0 (d1) with lower 64 bits of q1 (d2).
  // Corresponds to swapping v0.d[1] and v1.d[0].
  mov    v31.16b, v0.16b           // Temp copy of v0 (q0)
  mov    v0.d[1], v1.d[0]            // v0.d[1] (d1) = v1.d[0] (d2)
  mov    v1.d[0], v31.d[1]           // v1.d[0] (d2) = original v0.d[1] (d1)

  // AArch64 equivalent of: vswp d5, d6
  // Swaps upper 64 bits of q2 (d5) with lower 64 bits of q3 (d6).
  // Corresponds to swapping v2.d[1] and v3.d[0].
  mov    v31.16b, v2.16b           // Temp copy of v2 (q2)
  mov    v2.d[1], v3.d[0]            // v2.d[1] (d5) = v3.d[0] (d6)
  mov    v3.d[0], v31.d[1]           // v3.d[0] (d6) = original v2.d[1] (d5)

  // vstmia   r2!, {q0-q3} -> stp q0, q1, [x2], #32; stp q2, q3, [x2], #32
  stp    q0, q1, [x2], #32           // Store q0, q1 to [x2] and advance pointer
  stp    q2, q3, [x2], #32           // Store q2, q3 to [x2] and advance pointer


//
// AArch64 port of the neon_oe macro.
//
// Register mapping from ARM32 to AArch64:
// r0 (out)         -> x0
// r3-r10 (data)    -> x3-x10
// r11 (twiddle)    -> x11
// r12 (offsets)    -> x12
// r2 (temp)        -> x2
// lr (temp)        -> x14
// q0-q15 / d0-d31  -> v0-v15
// v16 is used as a temporary vector register.
//
  .align 4
#ifdef __APPLE__
    .globl _neon64_oe
_neon64_oe:
#else
    .globl neon64_oe
neon64_oe:
#endif
  // vld1.32  {q8},  [r5,  :64]!
  // vld1.32  {q10}, [r6,  :64]!
  ldr   q8, [x5], #16
  ldr   q10, [x6], #16

  // vld2.32  {q11}, [r4,  :64]!       // De-interleaves into d22, d23
  // vld2.32  {q13}, [r3,  :64]!       // De-interleaves into d26, d27
  // vld2.32  {q15}, [r10, :64]!       // De-interleaves into d30, d31
  ld2   { v22.2s, v23.2s }, [x4], #16
  ld2   { v26.2s, v27.2s }, [x3], #16
  ld2   { v30.2s, v31.2s }, [x10], #16

  // vorr     d25, d17, d17           // mov d25, d17 (high half of q8)
  // vorr     d24, d20, d20           // mov d24, d20 (low half of q10)
  // vorr     d20, d16, d16           // mov d20, d16 (low half of q8)
  ext   v25.16b, v8.16b, v8.16b, #8    // v25 = high 64 bits of v8
  mov   v24.8b, v10.8b                // v24 = low 64 bits of v10
  mov   v20.8b, v8.8b                 // v20 = low 64 bits of v8

  // vsub.f32 q9,  q13, q11           // q9={d18,d19} q13={d26,d27} q11={d22,d23}
  // vadd.f32 q11, q13, q11
  fsub  v18.2s, v26.2s, v22.2s
  fsub  v19.2s, v27.2s, v23.2s
  fadd  v22.2s, v26.2s, v22.2s
  fadd  v23.2s, v27.2s, v23.2s

  // ldr      r2,  [r12], #4
  // Note: ptrdiff_t is 64-bit on AArch64.
  ldr   x2, [x12], #8

  // vtrn.32  d24, d25
  trn1  v16.2s, v24.2s, v25.2s
  trn2  v25.2s, v24.2s, v25.2s
  mov   v24.16b, v16.16b

  // ldr      lr,  [r12], #4
  ldr   x14, [x12], #8

  // vtrn.32  d20, d21
  trn1  v16.2s, v20.2s, v21.2s
  trn2  v21.2s, v20.2s, v21.2s
  mov   v20.16b, v16.16b

  // add      r2,  r0,  r2, lsl #2
  add   x2, x0, x2, lsl #3              // Multiply index by 8 (size of complex float)

  // vsub.f32 q8,  q10, q12           // q8={d16,d17} q10={d20,d21} q12={d24,d25}
  // add      lr,  r0,  lr, lsl #2
  // vadd.f32 q10, q10, q12
  fsub  v16.2s, v20.2s, v24.2s
  fsub  v17.2s, v21.2s, v25.2s
  add   x14, x0, x14, lsl #3
  fadd  v20.2s, v20.2s, v24.2s
  fadd  v21.2s, v21.2s, v25.2s
  
  // Reconstruct q8 from its new parts in d16,d17
  mov   v8.d[0], v16.d[0]
  mov   v8.d[1], v17.d[0]
  
  // vadd.f32 q0,  q11, q10           // q0={d0,d1} q11={d22,d23}, q10={d20,d21}
  // vadd.f32 d25, d19, d16           // Using d register names directly from here
  // vsub.f32 d27, d19, d16
  fadd  v0.2s, v22.2s, v20.2s
  fadd  v1.2s, v23.2s, v21.2s
  fadd  v25.2s, v19.2s, v16.2s
  fsub  v27.2s, v19.2s, v16.2s

  // vsub.f32 q1,  q11, q10
  // vsub.f32 d24, d18, d17
  // vadd.f32 d26, d18, d17
  fsub  v2.2s, v22.2s, v20.2s
  fsub  v3.2s, v23.2s, v21.2s
  fsub  v24.2s, v18.2s, v17.2s
  fadd  v26.2s, v18.2s, v17.2s

  // vtrn.32  q0,  q12               // Transposes d0,d24 and d1,d25
  trn1  v16.2s, v0.2s, v24.2s
  trn2  v24.2s, v0.2s, v24.2s
  mov   v0.16b, v16.16b
  trn1  v16.2s, v1.2s, v25.2s
  trn2  v25.2s, v1.2s, v25.2s
  mov   v1.16b, v16.16b

  // vtrn.32  q1,  q13               // Transposes d2,d26 and d3,d27
  trn1  v16.2s, v2.2s, v26.2s
  trn2  v26.2s, v2.2s, v26.2s
  mov   v2.16b, v16.16b
  trn1  v16.2s, v3.2s, v27.2s
  trn2  v27.2s, v3.2s, v27.2s
  mov   v3.16b, v16.16b

  // vld1.32  {d24, d25}, [r11, :64]
  ldr   q12, [x11]                    // Load twiddles into v12={d24,d25}

  // vswp     d1, d2
  mov   v16.16b, v1.16b
  mov   v1.16b, v2.16b
  mov   v2.16b, v16.16b

  // vst1.32  {q0,  q1},  [r2, :64]!
  stp   q0, q1, [x2], #32

  // vld2.32  {q0},  [r9, :64]!        // De-interleaves into d0, d1
  // vadd.f32 q1,  q0, q15            // q1={d2,d3}, q0={d0,d1}, q15={d30,d31}
  ld2   { v0.2s, v1.2s }, [x9], #16
  fadd  v2.2s, v0.2s, v30.2s
  fadd  v3.2s, v1.2s, v31.2s

  // vld2.32  {q13}, [r8, :64]!       // De-interleaves into d26, d27
  // vld2.32  {q14}, [r7, :64]!       // De-interleaves into d28, d29
  ld2   { v26.2s, v27.2s }, [x8], #16
  ld2   { v28.2s, v29.2s }, [x7], #16

  // vsub.f32 q15, q0,  q15
  fsub  v30.2s, v0.2s, v30.2s
  fsub  v31.2s, v1.2s, v31.2s
  
  // vsub.f32 q0,  q14, q13           // q0={d0,d1} q14={d28,d29} q13={d26,d27}
  // vadd.f32 q3,  q14, q13
  fsub  v0.2s, v28.2s, v26.2s
  fsub  v1.2s, v29.2s, v27.2s
  fadd  v6.2s, v28.2s, v26.2s         // q3 is {d6,d7}
  fadd  v7.2s, v29.2s, v27.2s

  // vadd.f32 q2,  q3,  q1
  // vadd.f32 d29, d1,  d30
  // vsub.f32 d27, d1,  d30
  fadd  v4.2s, v6.2s, v2.2s           // q2 is {d4,d5}
  fadd  v5.2s, v7.2s, v3.2s
  fadd  v29.2s, v1.2s, v30.2s
  fsub  v27.2s, v1.2s, v30.2s

  // vsub.f32 q3,  q3,  q1
  // vsub.f32 d28, d0,  d31
  // vadd.f32 d26, d0,  d31
  fsub  v6.2s, v6.2s, v2.2s
  fsub  v7.2s, v7.2s, v3.2s
  fsub  v28.2s, v0.2s, v31.2s
  fadd  v26.2s, v0.2s, v31.2s

  // vtrn.32  q2,  q14               // Transposes d4,d28 and d5,d29
  trn1  v16.2s, v4.2s, v28.2s
  trn2  v28.2s, v4.2s, v28.2s
  mov   v4.16b, v16.16b
  trn1  v16.2s, v5.2s, v29.2s
  trn2  v29.2s, v5.2s, v29.2s
  mov   v5.16b, v16.16b

  // vtrn.32  q3,  q13               // Transposes d6,d26 and d7,d27
  trn1  v16.2s, v6.2s, v26.2s
  trn2  v26.2s, v6.2s, v26.2s
  mov   v6.16b, v16.16b
  trn1  v16.2s, v7.2s, v27.2s
  trn2  v27.2s, v7.2s, v27.2s
  mov   v7.16b, v16.16b

  // vswp     d5, d6
  mov   v16.16b, v5.16b
  mov   v5.16b, v6.16b
  mov   v6.16b, v16.16b

  // vst1.32  {q2, q3}, [r2, :64]!
  stp   q2, q3, [x2], #32

  // vtrn.32  q11, q9                // Transposes d22,d18 and d23,d19
  // vtrn.32  q10, q8                // Transposes d20,d16 and d21,d17
  trn1  v16.2s, v22.2s, v18.2s
  trn2  v18.2s, v22.2s, v18.2s
  mov   v22.16b, v16.16b
  trn1  v16.2s, v23.2s, v19.2s
  trn2  v19.2s, v23.2s, v19.2s
  mov   v23.16b, v16.16b
  trn1  v16.2s, v20.2s, v16.2s
  trn2  v16.2s, v20.2s, v16.2s
  mov   v20.16b, v16.16b
  trn1  v16.2s, v21.2s, v17.2s
  trn2  v17.2s, v21.2s, v17.2s
  mov   v21.16b, v16.16b

  // Complex multiply section (twiddles in d24,d25)
  // vmul.f32 d20, d18, d25
  // vmul.f32 d22, d19, d24
  // vmul.f32 d21, d19, d25
  // vmul.f32 d18, d18, d24
  fmul  v20.2s, v18.2s, v25.2s
  fmul  v22.2s, v19.2s, v24.2s
  fmul  v21.2s, v19.2s, v25.2s
  fmul  v18.2s, v18.2s, v24.2s

  // vmul.f32 d19, d16, d25
  // vmul.f32 d30, d17, d24
  // vmul.f32 d23, d16, d24
  // vmul.f32 d24, d17, d25
  fmul  v19.2s, v16.2s, v25.2s
  fmul  v30.2s, v17.2s, v24.2s
  fmul  v23.2s, v16.2s, v24.2s
  fmul  v24.2s, v17.2s, v25.2s

  // vadd.f32 d17, d22, d20
  // vsub.f32 d16, d18, d21
  // vsub.f32 d21, d30, d19
  // vadd.f32 d20, d24, d23
  fadd  v17.2s, v22.2s, v20.2s
  fsub  v16.2s, v18.2s, v21.2s
  fsub  v21.2s, v30.2s, v19.2s
  fadd  v20.2s, v24.2s, v23.2s
  
  // Last butterfly and store
  // vadd.f32 q9,  q8,  q10          // q9={d18,d19}, q8={d16,d17}, q10={d20,d21}
  // vsub.f32 q8,  q8,  q10
  fadd  v18.2s, v16.2s, v20.2s
  fadd  v19.2s, v17.2s, v21.2s
  fsub  v16.2s, v16.2s, v20.2s
  fsub  v17.2s, v17.2s, v21.2s
  
  // vadd.f32 q4,  q14, q9
  // vsub.f32 q6,  q14, q9
  // vadd.f32 d11, d27, d16
  // vsub.f32 d15, d27, d16
  fadd  v8.2s, v28.2s, v18.2s        // q4 = {d8,d9}
  fadd  v9.2s, v29.2s, v19.2s
  fsub  v12.2s, v28.2s, v18.2s       // q6 = {d12,d13}
  fsub  v13.2s, v29.2s, v19.2s
  fadd  v11.2s, v27.2s, v16.2s       // d11
  fsub  v15.2s, v27.2s, v16.2s       // d15
  
  // vsub.f32 d10, d26, d17
  // vadd.f32 d14, d26, d17
  fsub  v10.2s, v26.2s, v17.2s       // d10
  fadd  v14.2s, v26.2s, v17.2s       // d14
  
  // vswp     d9,  d10
  // vswp     d13, d14
  mov   v16.16b, v9.16b
  mov   v9.16b, v10.16b
  mov   v10.16b, v16.16b
  mov   v16.16b, v13.16b
  mov   v13.16b, v14.16b
  mov   v14.16b, v16.16b
  
  // vstmia   lr!, {q4-q7}
  stp   q4, q5, [x14], #32
  stp   q6, q7, [x14], #32


  .align 4
#ifdef __APPLE__
  .globl  _neon64_end
_neon64_end:
#else
  .globl  neon64_end
neon64_end:
#endif
  ret


//
// Aarch64 port of the neon_transpose4 macro.
//
// This function transposes a matrix of complex numbers (pairs of 32-bit floats).
// It processes the matrix in 4x2 blocks.
//
// Arguments:
//   x0: Input matrix pointer (*in)
//   x1: Output matrix pointer (*out)
//   x2: Matrix width (w)
//   x3: Matrix height (h)
//
  .align 4
#ifdef __APPLE__
  .globl _neon64_transpose4
_neon64_transpose4:
#else
  .globl neon64_transpose4
neon64_transpose4:
#endif
  // --- Prologue ---
  // Allocate stack space and save callee-saved registers and the link register.
  // We need to save GPRs x4-x6 and SIMD registers d8-d13 (lower 64 bits of v8-v13).
  // The stack must be 16-byte aligned.
  stp   x4, x5, [sp, #-80]!   // Store x4, x5 and pre-decrement SP
  stp   x6, x30, [sp, #16]    // Store x6, lr(x30)
  stp   d8, d9, [sp, #32]     // Store v8, v9
  stp   d10, d11, [sp, #48]   // Store v10, v11
  stp   d12, d13, [sp, #64]   // Store v12, v13

  // --- Outer Loop Setup ---
  // x5 will be the outer loop counter, iterating over height.
  mov   x5, x3                // x5 = h

1:  // Outer loop label
  // --- Inner Loop Setup ---
  // x10, x11 will be the output pointers for the columns.
  mov   x10, x1               // x10 (ip) = out_ptr (start of the first column for this block)
  // Calculate stride between columns: height * sizeof(complex float) = h * 8 bytes
  add   x11, x1, x3, lsl #3   // x11 (lr) = out_ptr + h*8 (start of the second column)
  // x4 will be the inner loop counter, iterating over width.
  mov   x4, x2                // x4 = w
  // Calculate the pointer to the second row of the current input block.
  // Stride between rows = width * sizeof(complex float) = w * 8 bytes
  add   x6, x0, x2, lsl #3    // x6 = in_ptr + w*8

2:  // Inner loop label
  // --- Load Data ---
  // Load a 2x4 block of complex numbers. Each ldp loads 4 complex numbers (32 bytes).
  // x0 points to the first row, x6 points to the second row.
  ldp   q8, q9, [x0], #32     // Load {c00,c01,c02,c03} from row 0; x0 += 32
  ldp   q12, q13, [x6], #32   // Load {c10,c11,c12,c13} from row 1; x6 += 32

  // --- Transpose 2x4 block ---
  // Use trn1/trn2 on 64-bit elements (.2d) to transpose pairs of vectors.
  // This is the Aarch64 equivalent of the vswp logic.
  // We use temporary registers v16-v19 to hold the transposed columns.
  trn1  v16.2d, v8.2d, v12.2d   // v16 = {c00, c10} (column 0)
  trn2  v17.2d, v8.2d, v12.2d   // v17 = {c01, c11} (column 1)
  trn1  v18.2d, v9.2d, v13.2d   // v18 = {c02, c12} (column 2)
  trn2  v19.2d, v9.2d, v13.2d   // v19 = {c03, c13} (column 3)

  // --- Store Data ---
  // Store the four transposed columns into the output matrix.
  // The pointers x10 and x11 point to the base of columns 0 and 1.
  str   q16, [x10]              // Store column 0
  str   q17, [x11]              // Store column 1

  // Calculate pointers for columns 2 and 3.
  // The stride to jump two columns is h * 16 bytes.
  add   x10, x10, x3, lsl #4    // x10 now points to column 2 base
  add   x11, x11, x3, lsl #4    // x11 now points to column 3 base

  str   q18, [x10]              // Store column 2
  str   q19, [x11]              // Store column 3

  // --- Inner Loop Decrement and Branch ---
  subs  x4, x4, #4              // Decrement width counter by 4
  bne   2b                      // Branch if not finished with the row

  // --- Outer Loop Decrement and Pointer Update ---
  subs  x5, x5, #2              // Decrement height counter by 2 (we processed 2 rows)
  
  // Advance input pointer (x0) by one row's worth of bytes to skip the next row.
  // The inner loop already advanced x0 by one row, so this advances it a second time.
  // Total advancement per outer loop iteration = 2 * w * 8 bytes.
  add   x0, x0, x2, lsl #3

  // Advance the base output pointer (x1) by two elements (2 columns were the basic unit).
  // The output is written column-wise, so we advance to the start of the next 2-column block.
  add   x1, x1, #16             // x1 += 2 * sizeof(complex float)

  bne   1b                      // Branch if not finished with all rows

  // --- Epilogue ---
  // Restore all saved registers and deallocate stack space.
  ldp   d12, d13, [sp, #64]   // Restore v12, v13
  ldp   d10, d11, [sp, #48]   // Restore v10, v11
  ldp   d8, d9, [sp, #32]     // Restore v8, v9
  ldp   x6, x30, [sp, #16]    // Restore x6, lr(x30)
  ldp   x4, x5, [sp], #80     // Restore x4, x5 and post-increment SP


  .align 4
#ifdef __APPLE__
  .globl _neon64_transpose8
_neon64_transpose8:
#else
  .globl neon64_transpose8
neon64_transpose8:
#endif
  // Aarch64 Prologue
  // Save callee-saved general purpose registers x19-x28 and the link register x30 (lr).
  // Also save callee-saved vector registers v8-v15.
  stp x19, x20, [sp, #-160]!
  stp x21, x22, [sp, #16]
  stp x23, x24, [sp, #32]
  stp x25, x26, [sp, #48]
  stp x27, x28, [sp, #64]
  stp x29, x30, [sp, #80]  // Save x29 and lr(x30)
  stp q8, q9, [sp, #96]
  stp q10, q11, [sp, #112]
  stp q12, q13, [sp, #128]
  stp q14, q15, [sp, #144]

  // Aarch64 has more registers, so we can map more cleanly.
  // x0: in_ptr, x1: out_ptr, x2: w, x3: h
  // Let's use named registers for clarity in comments.
  // x0: in_ptr,   x1: out_ptr,  x2: width_w, x3: height_h
  // x4: r4,       x5: r5,       x6: r6,      x7: r7
  // x8: r8,       x9: r9,       x10: r10,    x11: r11
  // x12: r12,     x13: lr,      x14: ip

  mov x29, sp // Save current stack pointer in frame pointer

  // @ initialize
  lsl   x12, x2, #3          // x12 (stride_w) = w * 8
  mul   x13, x12, x3         // x13 (total_size) = stride_w * h
  lsl   x3, x3, #5           // x3 (stride_h_out) = h * 32
  add   x4, x0, x12          // x4 = in_ptr + stride_w
  lsl   x14, x12, #1         // x14 (ip) = stride_w * 2
  lsr   x15, x3, #2
  add   x5, x1, x15          // x5 = out_ptr + stride_h_out / 4
  lsr   x15, x3, #1
  add   x6, x1, x15          // x6 = out_ptr + stride_h_out / 2
  add   x7, x5, x15          // x7 = x5 + stride_h_out / 2
  sub   x13, x3, x13         // x13 (lr_rem) = stride_h_out - total_size
  sub   x15, x14, #64        // x15 (ip_minus_64) = ip - 64
  sub   x8, x3, #48          // x8 = stride_h_out - 48
  add   x13, x13, #16        // x13 (lr_rem) += 16

1:
  // @ process all but the last one
  subs  x11, x12, #64        // x11 = stride_w - 64

  // @ prefetch next rows 0-5
  // Aarch64 prefetch instruction. pldl1keep = PLD, level 1 cache, keep
  prfm  pldl1keep, [x0]
  prfm  pldl1keep, [x4]
  add   x16, x0, x14, lsl #1
  prfm  pldl1keep, [x16]
  add   x16, x4, x14, lsl #1
  prfm  pldl1keep, [x16]
  add   x16, x0, x14, lsl #2
  prfm  pldl1keep, [x16]
  add   x16, x4, x14, lsl #2
  prfm  pldl1keep, [x16]

  // @ if there is only the last one
  b.eq  3f
2:
  // @ matrix 0&2 row 0-1
  ldp   q0, q1, [x0], #32       // vld1.32 {q0, q1}, [r0, :64]! -> ldp q0, q1, [x0], #32
  ldp   q2, q3, [x4], #32       // vld1.32 {q2, q3}, [r4, :64]! -> ldp q2, q3, [x4], #32

  // vswp d1, d4 -> swap 64 bits of v0 with 64 bits of v2
  // We need a temporary vector register, e.g., v16
  mov   v16.d[0], v0.d[1]
  mov   v0.d[1], v2.d[0]
  mov   v2.d[0], v16.d[0]
  // vswp d3, d6
  mov   v16.d[0], v1.d[1]
  mov   v1.d[1], v3.d[0]
  mov   v3.d[0], v16.d[0]

  stp   q0, q2, [x1], #32       // Optimized store for two vectors
  stp   q1, q3, [x6], #32       // Optimized store for two vectors
  add   x5, x5, #32             // Manual increment for x5, x7
  add   x7, x7, #32

  // @ matrix 1&3 row 0-1
  ldp   q4, q5, [x0], #32
  ldp   q6, q7, [x4], #32
  // vswp d9, d12
  mov   v16.d[0], v4.d[1]
  mov   v4.d[1], v6.d[0]
  mov   v6.d[0], v16.d[0]
  // vswp d11, d14
  mov   v16.d[0], v5.d[1]
  mov   v5.d[1], v7.d[0]
  mov   v7.d[0], v16.d[0]

  // @ prefetch next rows 0-1
  prfm  pldl1keep, [x0]
  prfm  pldl1keep, [x4]
  add   x9, x0, x15           // use ip_minus_64
  add   x10, x4, x15          // use ip_minus_64

  // @ matrix 0&2, row 2-3
  ldp   q0, q1, [x9], #32
  ldp   q2, q3, [x10], #32
  mov   v16.d[0], v0.d[1]
  mov   v0.d[1], v2.d[0]
  mov   v2.d[0], v16.d[0]
  mov   v16.d[0], v1.d[1]
  mov   v1.d[1], v3.d[0]
  mov   v3.d[0], v16.d[0]
  
  // Back to original store logic as stp requires base register writeback
  sub   x1, x1, #32             // revert address for single stores
  sub   x6, x6, #32
  str   q0, [x1, #16]
  str   q2, [x5, #-16]
  str   q1, [x6, #16]
  str   q3, [x7, #-16]

  // @ matrix 1&3, row 2-3
  ldp   q8, q9, [x9], #32
  ldp   q10, q11, [x10], #32
  mov   v16.d[0], v8.d[1]
  mov   v8.d[1], v10.d[0]
  mov   v10.d[0], v16.d[0]
  mov   v16.d[0], v9.d[1]
  mov   v9.d[1], v11.d[0]
  mov   v11.d[0], v16.d[0]

  // @ prefetch next rows 2-3
  prfm  pldl1keep, [x9]
  prfm  pldl1keep, [x10]
  add   x9, x9, x15
  add   x10, x10, x15

  // @ matrix 0&2, row 4-5
  ldp   q0, q1, [x9], #32
  ldp   q2, q3, [x10], #32
  mov   v16.d[0], v0.d[1]
  mov   v0.d[1], v2.d[0]
  mov   v2.d[0], v16.d[0]
  mov   v16.d[0], v1.d[1]
  mov   v1.d[1], v3.d[0]
  mov   v3.d[0], v16.d[0]
  str   q0, [x1, #32]
  str   q2, [x5]
  str   q1, [x6, #32]
  str   q3, [x7]

  // @ matrix 1&3, row 4-5
  ldp   q12, q13, [x9], #32
  ldp   q14, q15, [x10], #32
  mov   v16.d[0], v12.d[1]
  mov   v12.d[1], v14.d[0]
  mov   v14.d[0], v16.d[0]
  mov   v16.d[0], v13.d[1]
  mov   v13.d[1], v15.d[0]
  mov   v15.d[0], v16.d[0]

  // @ prefetch next rows 4-5
  prfm  pldl1keep, [x9]
  prfm  pldl1keep, [x10]
  add   x9, x9, x15
  add   x10, x10, x15

  // @ matrix 0&2, row 6-7
  ldp   q0, q1, [x9], #32
  ldp   q2, q3, [x10], #32
  mov   v16.d[0], v0.d[1]
  mov   v0.d[1], v2.d[0]
  mov   v2.d[0], v16.d[0]
  mov   v16.d[0], v1.d[1]
  mov   v1.d[1], v3.d[0]
  mov   v3.d[0], v16.d[0]
  str   q0, [x1, #48]
  str   q2, [x5, #16]
  str   q1, [x6, #48]
  str   q3, [x7, #16]

  // @ matrix 1&3, row 6-7
  ldp   q0, q1, [x9]
  ldp   q2, q3, [x10]
  mov   v16.d[0], v0.d[1]
  mov   v0.d[1], v2.d[0]
  mov   v2.d[0], v16.d[0]
  mov   v16.d[0], v1.d[1]
  mov   v1.d[1], v3.d[0]
  mov   v3.d[0], v16.d[0]

  // @ prefetch next rows 6-7
  prfm  pldl1keep, [x9]
  prfm  pldl1keep, [x10]

  subs  x11, x11, #64

  // Store the second block of transposed data
  str   q4, [x1, #64]!
  str   q8, [x1, #16]!
  str   q12, [x1, #16]!
  add   x1, x1, x8
  str   q0, [x1], #16

  str   q6, [x5, #32]!
  str   q10, [x5, #16]!
  str   q14, [x5, #16]!
  add   x5, x5, x8
  str   q2, [x5], #16

  str   q5, [x6, #64]!
  str   q9, [x6, #16]!
  str   q13, [x6, #16]!
  add   x6, x6, x8
  str   q1, [x6], #16

  str   q7, [x7, #32]!
  str   q11, [x7, #16]!
  str   q15, [x7, #16]!
  add   x7, x7, x8
  str   q3, [x7], #16

  // @ process all but the last on row
  b.ne  2b
3:
  // @ process the last one
  sub   x3, x3, #256

  // This block is identical to the one in the loop.
  // We can common up the code, but for a direct port, we duplicate it.
  ldp   q0, q1, [x0], #32
  ldp   q2, q3, [x4], #32
  mov   v16.d[0], v0.d[1]; mov v0.d[1], v2.d[0]; mov v2.d[0], v16.d[0]
  mov   v16.d[0], v1.d[1]; mov v1.d[1], v3.d[0]; mov v3.d[0], v16.d[0]
  stp   q0, q2, [x1], #32
  stp   q1, q3, [x6], #32
  add   x5, x5, #32
  add   x7, x7, #32

  ldp   q4, q5, [x0], #32
  ldp   q6, q7, [x4], #32
  mov   v16.d[0], v4.d[1]; mov v4.d[1], v6.d[0]; mov v6.d[0], v16.d[0]
  mov   v16.d[0], v5.d[1]; mov v5.d[1], v7.d[0]; mov v7.d[0], v16.d[0]
  add   x9, x0, x15
  add   x10, x4, x15

  ldp   q0, q1, [x9], #32
  ldp   q2, q3, [x10], #32
  mov   v16.d[0], v0.d[1]; mov v0.d[1], v2.d[0]; mov v2.d[0], v16.d[0]
  mov   v16.d[0], v1.d[1]; mov v1.d[1], v3.d[0]; mov v3.d[0], v16.d[0]
  sub   x1, x1, #32; sub   x6, x6, #32 // revert
  str   q0, [x1, #16]; str   q2, [x5, #-16]; str   q1, [x6, #16]; str   q3, [x7, #-16]

  ldp   q8, q9, [x9], #32
  ldp   q10, q11, [x10], #32
  mov   v16.d[0], v8.d[1]; mov v8.d[1], v10.d[0]; mov v10.d[0], v16.d[0]
  mov   v16.d[0], v9.d[1]; mov v9.d[1], v11.d[0]; mov v11.d[0], v16.d[0]
  add   x9, x9, x15
  add   x10, x10, x15

  ldp   q0, q1, [x9], #32
  ldp   q2, q3, [x10], #32
  mov   v16.d[0], v0.d[1]; mov v0.d[1], v2.d[0]; mov v2.d[0], v16.d[0]
  mov   v16.d[0], v1.d[1]; mov v1.d[1], v3.d[0]; mov v3.d[0], v16.d[0]
  str   q0, [x1, #32]; str   q2, [x5]; str   q1, [x6, #32]; str   q3, [x7]

  ldp   q12, q13, [x9], #32
  ldp   q14, q15, [x10], #32
  mov   v16.d[0], v12.d[1]; mov v12.d[1], v14.d[0]; mov v14.d[0], v16.d[0]
  mov   v16.d[0], v13.d[1]; mov v13.d[1], v15.d[0]; mov v15.d[0], v16.d[0]
  add   x9, x9, x15
  add   x10, x10, x15

  ldp   q0, q1, [x9], #32
  ldp   q2, q3, [x10], #32
  mov   v16.d[0], v0.d[1]; mov v0.d[1], v2.d[0]; mov v2.d[0], v16.d[0]
  mov   v16.d[0], v1.d[1]; mov v1.d[1], v3.d[0]; mov v3.d[0], v16.d[0]
  str   q0, [x1, #48]; str   q2, [x5, #16]; str   q1, [x6, #48]; str   q3, [x7, #16]

  ldp   q0, q1, [x9]
  ldp   q2, q3, [x10]
  mov   v16.d[0], v0.d[1]; mov v0.d[1], v2.d[0]; mov v2.d[0], v16.d[0]
  mov   v16.d[0], v1.d[1]; mov v1.d[1], v3.d[0]; mov v3.d[0], v16.d[0]

  // @ next row starts right after
  mov   x0, x10
  add   x4, x10, x12

  // Store the final block
  str   q4, [x1, #64]!
  str   q8, [x1, #16]!
  str   q12, [x1, #16]!
  add   x1, x1, x13 // use lr_rem
  str   q0, [x1], #16

  str   q6, [x5, #32]!
  str   q10, [x5, #16]!
  str   q14, [x5, #16]!
  add   x5, x5, x13 // use lr_rem
  str   q2, [x5], #16

  str   q5, [x6, #64]!
  str   q9, [x6, #16]!
  str   q13, [x6, #16]!
  add   x6, x6, x13 // use lr_rem
  str   q1, [x6], #16

  str   q7, [x7, #32]!
  str   q11, [x7, #16]!
  str   q15, [x7, #16]!
  add   x7, x7, x13 // use lr_rem
  str   q3, [x7], #16

  // @ process all columns
  cbnz  x3, 1b // if (x3 != 0) goto 1

  // Aarch64 Epilogue
  mov   sp, x29 // Restore stack pointer
  ldp q14, q15, [sp, #144]
  ldp q12, q13, [sp, #128]
  ldp q10, q11, [sp, #112]
  ldp q8, q9, [sp, #96]
  ldp x29, x30, [sp, #80]
  ldp x27, x28, [sp, #64]
  ldp x25, x26, [sp, #48]
  ldp x23, x24, [sp, #32]
  ldp x21, x22, [sp, #16]
  ldp x19, x20, [sp], #160

// =========================================================================
//  ARM32 Compatibility Aliases
// =========================================================================
#ifdef __APPLE__
    .globl _neon_x4
    .set _neon_x4, _neon64_x4
    .globl _neon_x8
    .set _neon_x8, _neon64_x8
    .globl _neon_x8_t
    .set _neon_x8_t, _neon64_x8_t
    .globl _neon_ee
    .set _neon_ee, _neon64_ee
    .globl _neon_oo
    .set _neon_oo, _neon64_oo
    .globl _neon_eo
    .set _neon_eo, _neon64_eo
    .globl _neon_oe
    .set _neon_oe, _neon64_oe
    .globl _neon_end
    .set _neon_end, _neon64_end
    .globl _neon_transpose4
    .set _neon_transpose4, _neon64_transpose4
    .globl _neon_transpose8
    .set _neon_transpose8, _neon64_transpose8
#else
    .globl neon_x4
    .set neon_x4, neon64_x4
    .globl neon_x8
    .set neon_x8, neon64_x8
    .globl neon_x8_t
    .set neon_x8_t, neon64_x8_t
    .globl neon_ee
    .set neon_ee, neon64_ee
    .globl neon_oo
    .set neon_oo, neon64_oo
    .globl neon_eo
    .set neon_eo, neon64_eo
    .globl neon_oe
    .set neon_oe, neon64_oe
    .globl neon_end
    .set neon_end, neon64_end
    .globl neon_transpose4
    .set neon_transpose4, neon64_transpose4
    .globl neon_transpose8
    .set neon_transpose8, neon64_transpose8
#endif

// End of file
    .end
