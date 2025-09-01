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
// Data Layout:
// - Complex numbers stored as interleaved pairs [Re₀, Im₀, Re₁, Im₁, ...]
// - Each v register with .4s holds 4 float32 values = 2 complex numbers
// - Two v registers together process 4 complex numbers per operation
//
// Algorithm: Radix-8 FFT using three stages of radix-2 butterflies:
// 1. First stage: Process data[2,3] with twiddle factors, butterfly with data[0,1]
// 2. Second stage: Process data[4,5,6,7] with twiddle factors  
// 3. Third stage: Final combinations and output with post-increment stores
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

    brk      #0x0810

1:  // Start of the main loop

    // --- Phase 1: Load Twiddle Factors and Initial Data ---
    // Load 4 complex numbers (256 bits) of twiddle factors from the LUT.
    // Post-increment the LUT pointer (x12) by 32 bytes.
    brk      #0x8C10 // BRK_X8_PRE_LUT_LOAD0
    ld1      {v2.4s,  v3.4s},  [x12], #32
    brk      #0x8C11 // BRK_X8_POST_LUT_LOAD0
    // Load data from streams 3 and 2.
    ld1      {v14.4s, v15.4s}, [x6]
    ld1      {v10.4s, v11.4s}, [x5]

    // --- Loop Counter Increment ---
    // Increment counter and continue if the loop should continue.
    add      x11, x11, #1

    // --- Phase 2: First Butterfly Computation Stage ---
    // Complex multiplication: data[2,3] × twiddle_factors
    // (a + bi) × (c + di) = (ac - bd) + (ad + bc)i
    fmul     v12.4s, v15.4s, v2.4s         // v12 = data[3].imag × twiddle.real
    fmul     v8.4s,  v14.4s, v3.4s         // v8  = data[3].real × twiddle.imag
    fmul     v13.4s, v14.4s, v2.4s         // v13 = data[3].real × twiddle.real
    fmul     v9.4s,  v10.4s, v3.4s         // v9  = data[2].real × twiddle.imag
    fmul     v1.4s,  v10.4s, v2.4s         // v1  = data[2].real × twiddle.real
    fmul     v0.4s,  v11.4s, v2.4s         // v0  = data[2].imag × twiddle.real
    fmul     v14.4s, v11.4s, v3.4s         // v14 = data[2].imag × twiddle.imag
    fmul     v15.4s, v15.4s, v3.4s         // v15 = data[3].imag × twiddle.imag

    // Load next set of twiddle factors for second butterfly stage
    brk      #0x8C12 // BRK_X8_PRE_LUT_LOAD1
    ld1      {v2.4s,  v3.4s},  [x12], #32
    brk      #0x8C13 // BRK_X8_POST_LUT_LOAD1

    // Complete complex multiplications and first butterfly stage
    fsub     v10.4s, v12.4s, v8.4s         // v10 = complex multiplication result (imag part)
    fadd     v11.4s, v0.4s,  v9.4s         // v11 = complex multiplication result (imag part)
    fadd     v8.4s,  v15.4s, v13.4s        // v8  = complex multiplication result (real part)

    // Load data from stream 1 for butterfly operations
    ld1      {v12.4s, v13.4s}, [x4]

    // Continue butterfly computations
    fsub     v9.4s,  v1.4s,  v14.4s        // v9  = complex subtraction result
    fsub     v15.4s, v11.4s, v10.4s        // v15 = intermediate butterfly result
    fsub     v14.4s, v9.4s,  v8.4s         // v14 = intermediate butterfly result
    fsub     v4.4s,  v12.4s, v15.4s        // v4  = data[1] - processed_result
    fadd     v6.4s,  v12.4s, v15.4s        // v6  = data[1] + processed_result
    fadd     v5.4s,  v13.4s, v14.4s        // v5  = combined butterfly result
    fsub     v7.4s,  v13.4s, v14.4s        // v7  = combined butterfly result

    // --- Phase 3: Second Butterfly Computation Stage ---
    // Load data from streams 6 and 4 for processing
    ld1      {v14.4s, v15.4s}, [x9]
    ld1      {v12.4s, v13.4s}, [x7]

    // Begin complex multiplications for second stage
    fmul     v1.4s,  v14.4s, v2.4s         // Complex multiplication: data[6] × twiddle
    fmul     v0.4s,  v14.4s, v3.4s

    // Store intermediate results to data[1] (no post-increment)
    st1      {v4.4s,  v5.4s},  [x4]

    // Continue complex multiplications
    fmul     v14.4s, v15.4s, v3.4s         // Continue data[6] × twiddle
    fmul     v4.4s,  v15.4s, v2.4s
    fadd     v15.4s, v9.4s,  v8.4s          // Combine previous results

    // Store intermediate results to data[3] (no post-increment)  
    st1      {v6.4s,  v7.4s},  [x6]

    // Process data[4] with twiddle factors
    fmul     v8.4s,  v12.4s, v3.4s         // Complex multiplication: data[4] × twiddle
    fmul     v5.4s,  v13.4s, v3.4s
    fmul     v12.4s, v12.4s, v2.4s
    fmul     v9.4s,  v13.4s, v2.4s
    fadd     v14.4s, v14.4s, v1.4s         // Complete complex multiplication
    fsub     v13.4s, v4.4s,  v0.4s
    fadd     v0.4s,  v9.4s,  v8.4s

    // Load data from stream 0 for final butterfly combinations
    ld1      {v8.4s,  v9.4s},  [x3]

    // --- Phase 4: Final Butterfly Stage and Data Combination ---
    fadd     v1.4s,  v11.4s, v10.4s        // Combine earlier butterfly results
    fsub     v12.4s, v12.4s, v5.4s         // Continue complex arithmetic
    fadd     v11.4s, v8.4s,  v15.4s        // Combine data[0] with processed results
    fsub     v8.4s,  v8.4s,  v15.4s
    fadd     v2.4s,  v12.4s, v14.4s        // Final butterfly combinations
    fsub     v10.4s, v0.4s,  v13.4s
    fadd     v15.4s, v0.4s,  v13.4s
    fadd     v13.4s, v9.4s,  v1.4s
    fsub     v9.4s,  v9.4s,  v1.4s
    fsub     v12.4s, v12.4s, v14.4s
    fadd     v0.4s,  v11.4s, v2.4s         // Final output preparation
    fadd     v1.4s,  v13.4s, v15.4s
    fsub     v4.4s,  v11.4s, v2.4s
    fsub     v2.4s,  v8.4s,  v10.4s
    fadd     v3.4s,  v9.4s,  v12.4s
    
    // Store results to stream 0, post-incrementing the pointer.
    brk      #0x8C20 // BRK_X8_PRE_ST_DATA0
    brk      #0x8D30 // BRK_X8T_PRE_ST_F0
  st1      {v0.4s,  v1.4s},  [x3], #32
    nop // removed BRK_X8_POST_ST_DATA0

    fsub     v5.4s,  v13.4s, v15.4s
    // Load data from streams 7 and 5.
    ld1      {v14.4s, v15.4s}, [x10]
    fsub     v7.4s,  v9.4s,  v12.4s
    ld1      {v12.4s, v13.4s}, [x8]

    // Store results to stream 2, post-incrementing the pointer.
    brk      #0x8C22 // BRK_X8_PRE_ST_DATA2
    brk      #0x8D31 // BRK_X8T_PRE_ST_F2
  st1      {v2.4s,  v3.4s},  [x5], #32

    // Load final set of twiddle factors
    ld1      {v2.4s,  v3.4s},  [x12], #32

    fadd     v6.4s,  v8.4s,  v10.4s

    // --- Phase 5: Final Data Processing (Third Stage) ---
    fmul     v8.4s,  v14.4s, v2.4s         // Process data[7] × twiddle

    // Store results to stream 4, post-incrementing the pointer.
    brk      #0x8C24 // BRK_X8_PRE_ST_DATA4
    brk      #0x8D32 // BRK_X8T_PRE_ST_F4
  st1      {v4.4s,  v5.4s},  [x7], #32

    // Complete final complex multiplications
    fmul     v10.4s, v15.4s, v3.4s         // Continue data[7] × twiddle
    fmul     v9.4s,  v13.4s, v3.4s         // Process data[5] × twiddle
    fmul     v11.4s, v12.4s, v2.4s
    fmul     v14.4s, v14.4s, v3.4s
    
    // Store results to stream 6, post-incrementing the pointer.
    brk      #0x8C26 // BRK_X8_PRE_ST_DATA6
    brk      #0x8D33 // BRK_X8T_PRE_ST_F6
  st1      {v6.4s,  v7.4s},  [x9], #32
    
    fmul     v15.4s, v15.4s, v2.4s
    fmul     v12.4s, v12.4s, v3.4s
    fmul     v13.4s, v13.4s, v2.4s
    fadd     v10.4s, v10.4s, v8.4s         // Combine multiplication results
    fsub     v11.4s, v11.4s, v9.4s
    
    // Load data for final butterfly combinations
    ld1      {v8.4s,  v9.4s},  [x4]        // Reload data[1] for final processing

    fsub     v14.4s, v15.4s, v14.4s        // Complete complex arithmetic
    fadd     v15.4s, v13.4s, v12.4s
    fadd     v13.4s, v11.4s, v10.4s        // Final butterfly results
    fadd     v12.4s, v15.4s, v14.4s
    fsub     v15.4s, v15.4s, v14.4s
    fsub     v14.4s, v11.4s, v10.4s

    // Load final data for output combinations
    ld1      {v10.4s, v11.4s}, [x6]        // Reload data[3] for final processing

    // --- Phase 6: Final Output Computations and Storage ---
    fadd     v0.4s,  v8.4s,  v13.4s        // Final butterfly combinations
    fadd     v1.4s,  v9.4s,  v12.4s
    fsub     v2.4s,  v10.4s, v15.4s
    fadd     v3.4s,  v11.4s, v14.4s
    fsub     v4.4s,  v8.4s,  v13.4s

    // Store final results with post-increment to remaining data streams
    brk      #0x8C30 // BRK_X8_PRE_ST_DATA0
    st1      {v0.4s,  v1.4s},  [x4], #32   // Store to data[1] with post-increment

    fsub     v5.4s,  v9.4s,  v12.4s
    fadd     v6.4s,  v10.4s, v15.4s

    brk      #0x8C34 // BRK_X8_PRE_ST_DATA2
    st1      {v2.4s,  v3.4s},  [x6], #32   // Store to data[3] with post-increment

    fsub     v7.4s,  v11.4s, v14.4s

    brk      #0x8C38 // BRK_X8_PRE_ST_DATA4
    st1      {v4.4s,  v5.4s},  [x8], #32   // Store to data[5] with post-increment
    st1      {v6.4s,  v7.4s},  [x10], #32  // Store to data[7] with post-increment

    // --- Loop Control ---
    // Continue loop while counter is not zero (started negative, increments to 0)
    cbnz     x11, 1b

    // --- Function Exit ---
    ret // Return to the caller

//
// AArch64 implementation of neon_x8_t - 8-point FFT with transpose output
//
// This function implements a vectorized 8-point Cooley-Tukey FFT butterfly 
// with transposed output using ARM64 NEON instructions. It processes multiple
// 8-point FFTs in parallel, with each iteration handling 4 complex numbers 
// per data point. The transpose operation is integrated into the store 
// operations using st2 instructions.
//
// Register mapping from ARM32 to AArch64:
// r0 (data base ptr)    -> x0
// r1 (stride in bytes)  -> x1  
// r2 (LUT base ptr)     -> x2
// r3..r10 (data ptrs)   -> x3..x10
// r11 (loop counter)    -> x11
// r12 (LUT current ptr) -> x12
// q0..q15 (NEON regs)   -> v0..v15
//
// Input Parameters:
// x0: Pointer to input/output data buffer (complex float array)
// x1: Stride between data elements in bytes
// x2: Pointer to Look-Up Table (LUT) containing twiddle factors
//
// Data Layout:
// - Complex numbers stored as interleaved pairs [Re₀, Im₀, Re₁, Im₁, ...]
// - Input: 8 data streams, each processing 4 complex numbers per iteration
// - Output: Transposed complex data using st2 de-interleaving stores
//
    .align 4
#ifdef __APPLE__
    .globl _neon64_x8_t
_neon64_x8_t:
#else
    .globl neon64_x8_t
neon64_x8_t:
#endif
  // --- Data Pointer Setup ---
  // Calculate pointers to the 8 parallel data streams based on stride
  mov      x11, xzr             // Initialize loop counter to 0

  brk      #0x8D00 // BRK_X8T_ENTRY

  // NEW: Verify entry parameters for x8_t
  brk      #0x8D02 // BRK_X8T_ENTRY_PARAMS

  mov      x3, x0               // x3 = &data[0] (base pointer)
  add      x5, x0, x1, lsl #1   // x5 = &data[0] + stride*2 = &data[2]
  add      x4, x0, x1           // x4 = &data[0] + stride*1 = &data[1]  
  add      x7, x5, x1, lsl #1   // x7 = &data[2] + stride*2 = &data[4]
  add      x6, x5, x1           // x6 = &data[2] + stride*1 = &data[3]
  add      x9, x7, x1, lsl #1   // x9 = &data[4] + stride*2 = &data[6]
  add      x8, x7, x1           // x8 = &data[4] + stride*1 = &data[5]
  add      x10, x9, x1          // x10 = &data[6] + stride*1 = &data[7]
  mov      x12, x2              // x12 = LUT current pointer (advances each iteration)

  // --- Loop Counter Setup ---
  // Initialize counter to -(stride/32). Each iteration processes 32 bytes
  // (4 complex numbers × 8 bytes per complex number)
  lsr      x11, x1, #5          // x11 = stride / 32 (number of iterations)
  neg      x11, x11             // x11 = -(stride / 32) (count up to 0)


1:  // === Main Loop Body ===
  
  // NEW: Main loop iteration start for x8_t
  brk      #0x8D03 // BRK_X8T_LOOP_START
  
  // --- Phase 1: Load Twiddle Factors and Initial Data ---
  ld1      {v2.4s,  v3.4s},  [x12], #32  // Load 8 twiddle factors (32 bytes) with post-increment
  ld1      {v14.4s, v15.4s}, [x6]        // Load 8 floats from data[3] (no increment)
  ld1      {v10.4s, v11.4s}, [x5]        // Load 8 floats from data[2] (no increment)

  // Increment loop counter and continue if not zero
  add      x11, x11, #1                   // Increment counter (starts negative, counts to 0)

  // --- Phase 2: First Butterfly Computation Stage ---
  // Complex multiplication: data[2,3] × twiddle_factors
  // (a + bi) × (c + di) = (ac - bd) + (ad + bc)i
  fmul     v12.4s, v15.4s, v2.4s         // v12 = data[3].imag × twiddle.real
  fmul     v8.4s,  v14.4s, v3.4s         // v8  = data[3].real × twiddle.imag
  fmul     v13.4s, v14.4s, v2.4s         // v13 = data[3].real × twiddle.real
  fmul     v9.4s,  v10.4s, v3.4s         // v9  = data[2].real × twiddle.imag
  fmul     v1.4s,  v10.4s, v2.4s         // v1  = data[2].real × twiddle.real
  fmul     v0.4s,  v11.4s, v2.4s         // v0  = data[2].imag × twiddle.real
  fmul     v14.4s, v11.4s, v3.4s         // v14 = data[2].imag × twiddle.imag
  fmul     v15.4s, v15.4s, v3.4s         // v15 = data[3].imag × twiddle.imag

  // Load next set of twiddle factors for second butterfly stage
  ld1      {v2.4s,  v3.4s},  [x12], #32  // Load next 8 twiddle factors

  // Complete complex multiplications and first butterfly stage
  fsub     v10.4s, v12.4s, v8.4s         // v10 = complex multiplication result (real part)
  fadd     v11.4s, v0.4s,  v9.4s         // v11 = complex multiplication result (imag part)
  fadd     v8.4s,  v15.4s, v13.4s        // v8  = complex multiplication result

  // Load data from stream 1 for butterfly operations
  ld1      {v12.4s, v13.4s}, [x4]        // Load 8 floats from data[1]

  // Continue butterfly computations
  fsub     v9.4s,  v1.4s,  v14.4s        // v9  = complex subtraction result
  fsub     v15.4s, v11.4s, v10.4s        // v15 = intermediate butterfly result
  fsub     v14.4s, v9.4s,  v8.4s         // v14 = intermediate butterfly result
  fsub     v4.4s,  v12.4s, v15.4s        // v4  = data[1] - processed_result
  fadd     v6.4s,  v12.4s, v15.4s        // v6  = data[1] + processed_result
  fadd     v5.4s,  v13.4s, v14.4s        // v5  = combined butterfly result
  fsub     v7.4s,  v13.4s, v14.4s        // v7  = combined butterfly result

  // --- Phase 3: Second Butterfly Computation Stage ---
  // Load data from streams 6 and 4 for processing
  ld1      {v14.4s, v15.4s}, [x9]
  ld1      {v12.4s, v13.4s}, [x7]

  // Begin complex multiplications for second stage
  fmul     v1.4s,  v14.4s, v2.4s         // Complex multiplication: data[6] × twiddle
  fmul     v0.4s,  v14.4s, v3.4s

  // Store intermediate results to data[1] (no post-increment)
  brk      #0x8D20 // BRK_X8T_PRE_ST_I1
  st1      {v4.4s,  v5.4s},  [x4]

  // Continue complex multiplications
  fmul     v14.4s, v15.4s, v3.4s         // Continue data[6] × twiddle
  fmul     v4.4s,  v15.4s, v2.4s
  fadd     v15.4s, v9.4s,  v8.4s          // Combine previous results

  // Store intermediate results to data[3] (no post-increment)
  brk      #0x8D21 // BRK_X8T_PRE_ST_I3
  st1      {v6.4s,  v7.4s},  [x6]

  // Process data[4] with twiddle factors
  fmul     v8.4s,  v12.4s, v3.4s         // Complex multiplication: data[4] × twiddle
  fmul     v5.4s,  v13.4s, v3.4s
  fmul     v12.4s, v12.4s, v2.4s
  fmul     v9.4s,  v13.4s, v2.4s
  fadd     v14.4s, v14.4s, v1.4s         // Complete complex multiplication
  fsub     v13.4s, v4.4s,  v0.4s
  fadd     v0.4s,  v9.4s,  v8.4s

  // Load data from stream 0 for final butterfly combinations
  ld1      {v8.4s,  v9.4s},  [x3]

  // --- Phase 4: Final Butterfly Stage and Data Combination ---
  fadd     v1.4s,  v11.4s, v10.4s        // Combine earlier butterfly results
  fsub     v12.4s, v12.4s, v5.4s         // Continue complex arithmetic
  fadd     v11.4s, v8.4s,  v15.4s        // Combine data[0] with processed results
  fsub     v8.4s,  v8.4s,  v15.4s
  fadd     v2.4s,  v12.4s, v14.4s        // Final butterfly combinations
  fsub     v10.4s, v0.4s,  v13.4s
  fadd     v15.4s, v0.4s,  v13.4s
  fadd     v13.4s, v9.4s,  v1.4s
  fsub     v9.4s,  v9.4s,  v1.4s
  fsub     v12.4s, v12.4s, v14.4s
  fadd     v0.4s,  v11.4s, v2.4s         // Final output preparation
  fadd     v1.4s,  v13.4s, v15.4s
  fsub     v4.4s,  v11.4s, v2.4s
  fsub     v2.4s,  v8.4s,  v10.4s
  fadd     v3.4s,  v9.4s,  v12.4s

  // --- Phase 5: Transposed Output Storage (First Half) ---
  // Use st2 instructions for automatic de-interleaving (transpose)
  brk      #0x8D30 // BRK_X8T_PRE_ST_F0
  st2      {v0.4s,  v1.4s},  [x3], #32   // Store to data[0] with transpose and post-increment
  fsub     v5.4s,  v13.4s, v15.4s        // Continue preparing output data
  ld1      {v14.4s, v15.4s}, [x10]       // Load data[7] for final processing
  fsub     v7.4s,  v9.4s,  v12.4s
  ld1      {v12.4s, v13.4s}, [x8]        // Load data[5] for final processing

  brk      #0x8D31 // BRK_X8T_PRE_ST_F2
  st2      {v2.4s,  v3.4s},  [x5], #32   // Store to data[2] with transpose and post-increment

  // Load final set of twiddle factors
  ld1      {v2.4s,  v3.4s},  [x12], #32

  fadd     v6.4s,  v8.4s,  v10.4s
  fmul     v8.4s,  v14.4s, v2.4s         // Process data[7] × twiddle

  brk      #0x8D32 // BRK_X8T_PRE_ST_F4
  st2      {v4.4s,  v5.4s},  [x7], #32   // Store to data[4] with transpose and post-increment

  // --- Phase 6: Final Data Processing (Second Half) ---
  fmul     v10.4s, v15.4s, v3.4s         // Continue data[7] × twiddle
  fmul     v9.4s,  v13.4s, v3.4s         // Process data[5] × twiddle
  fmul     v11.4s, v12.4s, v2.4s
  fmul     v14.4s, v14.4s, v3.4s

  brk      #0x8D33 // BRK_X8T_PRE_ST_F6
  st2      {v6.4s,  v7.4s},  [x9], #32   // Store to data[6] with transpose and post-increment

  // Complete final complex multiplications
  fmul     v15.4s, v15.4s, v2.4s
  fmul     v12.4s, v12.4s, v3.4s
  fmul     v13.4s, v13.4s, v2.4s
  fadd     v10.4s, v10.4s, v8.4s         // Combine multiplication results
  fsub     v11.4s, v11.4s, v9.4s
  
  // Load data for final butterfly combinations
  ld1      {v8.4s,  v9.4s},  [x4]        // Reload data[1] for final processing

  fsub     v14.4s, v15.4s, v14.4s        // Complete complex arithmetic
  fadd     v15.4s, v13.4s, v12.4s
  fadd     v13.4s, v11.4s, v10.4s        // Final butterfly results
  fadd     v12.4s, v15.4s, v14.4s
  fsub     v15.4s, v15.4s, v14.4s
  fsub     v14.4s, v11.4s, v10.4s

  // Load final data for output combinations
  ld1      {v10.4s, v11.4s}, [x6]        // Reload data[3] for final processing

  // --- Phase 7: Final Output Computations and Transposed Storage ---
  fadd     v0.4s,  v8.4s,  v13.4s        // Final butterfly combinations
  fadd     v1.4s,  v9.4s,  v12.4s
  fsub     v2.4s,  v10.4s, v15.4s
  fadd     v3.4s,  v11.4s, v14.4s
  fsub     v4.4s,  v8.4s,  v13.4s

  // Store final results with transpose to remaining data streams
  st2      {v0.4s,  v1.4s},  [x4], #32   // Store to data[1] with transpose and post-increment
  fsub     v5.4s,  v9.4s,  v12.4s
  fadd     v6.4s,  v10.4s, v15.4s

  st2      {v2.4s,  v3.4s},  [x6], #32   // Store to data[3] with transpose and post-increment
  fsub     v7.4s,  v11.4s, v14.4s

  st2      {v4.4s,  v5.4s},  [x8], #32   // Store to data[5] with transpose and post-increment
  st2      {v6.4s,  v7.4s},  [x10], #32  // Store to data[7] with transpose and post-increment

  // --- Loop Control ---
  // Continue loop while counter is not zero (started negative, increments to 0)
  
  // NEW: Verify before loop continuation
  brk      #0x8D04 // BRK_X8T_LOOP_CHECK
  
  cbnz     x11, 1b

  // NEW: x8_t function exit
  brk      #0x8D05 // BRK_X8T_EXIT

  // Function complete - return to caller
  nop


//
// Corrected AArch64 port of the FFTS library's 'neon_ee' macro.
//
// This is a direct line-by-line port of the ARM32 implementation.
// The key insight is to work with deinterleaved data from ld2 throughout,
// just like the ARM32 vld2.32 instruction produces.
//
// Register mapping:
// x0 = Output data pointer (ARM32: r0)
// x2 = Twiddles pointer (ARM32: r2)  
// x3-x10 = Input data pointers (ARM32: r3-r10)
// x11 = Loop counter (ARM32: r11)
// x12 = Offsets array pointer (ARM32: r12)
// d16, d17 = Twiddle factors (same as ARM32)
// v0-v15 = Data registers (ARM32: q0-q15)
    .align 4
#ifdef __APPLE__
    .globl _neon64_ee
_neon64_ee:
#else
    .globl neon64_ee
neon64_ee:
#endif
     brk   #0xEE00   // BRK_EE_ENTRY
     
     // NEW: Verify entry parameters
     brk   #0xEE01   // BRK_EE_ENTRY_PARAMS
     
     // ARM32: vld1.32 {d16, d17}, [r2, :64]
     ldp   d16, d17, [x2]               // Load twiddles: d16=real, d17=imag
     //dup v16.2d, v16.d[0]
     //dup v17.2d, v17.d[0]
     dup v16.4s, v16.s[0]
     dup v17.4s, v17.s[0]
     
     // NEW: Verify twiddle load
     brk   #0xEE02   // BRK_EE_TWIDDLES_LOADED

1:  // Main loop - Match ARM32 load sizes exactly (2 complex numbers = 16 bytes)
    // NEW: Loop iteration start
    brk   #0xEE03   // BRK_EE_LOOP_START
    
    // ARM32: vld2.32 {q15}, [r10, :64]!
    ld2   {v30.4s, v31.4s}, [x10], #32 // q15: v30=real, v31=imag (4 complex numbers)
    // dup v30.2d, v30.d[0]
    // dup v31.2d, v31.d[0]
    // ARM32: vld2.32 {q13}, [r8, :64]!  
    ld2   {v26.4s, v27.4s}, [x8], #32  // q13: v26=real, v27=imag (4 complex numbers)
    brk   #0xEE16   // BRK_EE_AFTER_LD2_X8
    // dup v26.2d, v26.d[0]
    // dup v27.2d, v27.d[0]
    // ARM32: vld2.32 {q14}, [r7, :64]!
    ld2   {v28.4s, v29.4s}, [x7], #32  // q14: v28=real, v29=imag (4 complex numbers)
    // dup v28.2d, v28.d[0]
    // dup v29.2d, v29.d[0]
    // ARM32: vld2.32 {q9}, [r4, :64]!
    ld2   {v18.4s, v19.4s}, [x4], #32  // q9: v18=real, v19=imag (4 complex numbers)
    // dup v18.2d, v18.d[0]
    // dup v19.2d, v19.d[0]
    // ARM32: vld2.32 {q10}, [r3, :64]!
    ld2   {v20.4s, v21.4s}, [x3], #32  // q10: v20=real, v21=imag (4 complex numbers)
    // dup v20.2d, v20.d[0]
    // dup v21.2d, v21.d[0]
    // ARM32: vld2.32 {q11}, [r6, :64]!
    ld2   {v22.4s, v23.4s}, [x6], #32  // q11: v22=real, v23=imag (4 complex numbers)
    // dup v22.2d, v22.d[0]
    // dup v23.2d, v23.d[0]
    // ARM32: vld2.32 {q12}, [r5, :64]!
    ld2   {v24.4s, v25.4s}, [x5], #32  // q12: v24=real, v25=imag (4 complex numbers)
    // dup v24.2d, v24.d[0]
    // dup v25.2d, v25.d[0]
    
    // NEW: Verify data loads
    brk   #0xEE04   // BRK_EE_DATA_LOADED
    
    // ARM32: vsub.f32 q1, q14, q13
    fsub  v2.4s, v28.4s, v26.4s        // q1 real: v2 = q14_real - q13_real
    fsub  v3.4s, v29.4s, v27.4s        // q1 imag: v3 = q14_imag - q13_imag
     
    // NEW: q1 built
    brk   #0xEE10   // BRK_EE_Q1_BUILT
     
     // ARM32: vld2.32 {q0}, [r9, :64]!
    ld2   {v0.4s, v1.4s}, [x9], #32    // q0: v0=real, v1=imag (4 complex numbers)
     
    // NEW: q0 loaded
    brk   #0xEE11   // BRK_EE_Q0_LOADED
     
    // ARM32: subs r11, r11, #1
    subs  x11, x11, #1
     
    // ARM32: vsub.f32 q2, q0, q15
    fsub  v4.4s, v0.4s, v30.4s         // q2 real: v4 = q0_real - q15_real
    fsub  v5.4s, v1.4s, v31.4s         // q2 imag: v5 = q0_imag - q15_imag
    
    // ARM32: vadd.f32 q0, q0, q15
    fadd  v0.4s, v0.4s, v30.4s         // q0 real: v0 = q0_real + q15_real
    fadd  v1.4s, v1.4s, v31.4s         // q0 imag: v1 = q0_imag + q15_imag
     
    // NEW: q0/q2 updated
    brk   #0xEE12   // BRK_EE_Q0Q2_UPDATED
     
     // Complex multiplication operations (ARM32 d-register equivalents)
     // ARM32: vmul.f32 d10, d2, d17 -> multiply q1_real with twiddle_imag  
    fmul  v10.4s, v2.4s, v17.4s       // q5 = q1_real * twiddle_imag
    
    // ARM32: vmul.f32 d11, d3, d16 -> multiply q1_imag with twiddle_real
    fmul  v11.4s, v3.4s, v16.4s       // q5 = q1_imag * twiddle_real
    
    // ARM32: vmul.f32 d6, d4, d17 -> multiply q2_real with twiddle_imag
    fmul  v6.4s, v4.4s, v17.4s        // q3 = q2_real * twiddle_imag
    
    // ARM32: vmul.f32 d7, d5, d16 -> multiply q2_imag with twiddle_real
    fmul  v7.4s, v5.4s, v16.4s        // q3 = q2_imag * twiddle_real
    
    // ARM32: vmul.f32 d8, d4, d16 -> multiply q2_real with twiddle_real
    fmul  v8.4s, v4.4s, v16.4s        // q4 = q2_real * twiddle_real
    
    // ARM32: vmul.f32 d9, d5, d17 -> multiply q2_imag with twiddle_imag
    fmul  v9.4s, v5.4s, v17.4s        // q4 = q2_imag * twiddle_imag
    
    // ARM32: vmul.f32 d13, d2, d16 -> multiply q1_real with twiddle_real
    fmul  v13.4s, v2.4s, v16.4s       // q6 = q1_real * twiddle_real
    // ARM32 counterpart also computes: vmul.f32 d12, d3, d17 (q1_imag * twiddle_imag)
    // Compute that missing term explicitly so we can form (q1_real*tw_re) - (q1_imag*tw_im)
    fmul  v12.4s, v3.4s, v17.4s       // tmp = q1_imag * twiddle_imag
    
    // ARM32: vsub.f32 d7, d7, d6
    fsub  v7.4s, v7.4s, v6.4s         // q3 = q2_imag*twiddle_real - q2_real*twiddle_imag
    
    // ARM32: vadd.f32 d11, d11, d10
    fadd  v11.4s, v11.4s, v10.4s      // q5 = q1_imag*twiddle_real + q1_real*twiddle_imag
    
    // ARM32: vsub.f32 q1, q12, q11
    fsub  v2.4s, v24.4s, v22.4s       // q1 real: q12_real - q11_real
    fsub  v3.4s, v25.4s, v23.4s       // q1 imag: q12_imag - q11_imag
    
    // ARM32: vsub.f32 q2, q10, q9  
    fsub  v4.4s, v20.4s, v18.4s       // q2 real: q10_real - q9_real
    fsub  v5.4s, v21.4s, v19.4s       // q2 imag: q10_imag - q9_imag
    
    // ARM32: vadd.f32 d6, d9, d8
    fadd  v6.4s, v9.4s, v8.4s         // q3 = q2_imag*twiddle_imag + q2_real*twiddle_real
    
     // NEW: d-lane partials (pre-accum)
     brk   #0xEE13   // BRK_EE_DLANE_PARTIALS
     
     // ARM32: vadd.f32 q4, q14, q13
     fadd  v14.4s, v28.4s, v26.4s      // q4 real: q14_real + q13_real
     fadd  v15.4s, v29.4s, v27.4s      // q4 imag: q14_imag + q13_imag
    
    // ARM32: vadd.f32 q11, q12, q11
    fadd  v22.4s, v24.4s, v22.4s      // q11 real: q12_real + q11_real
    fadd  v23.4s, v25.4s, v23.4s      // q11 imag: q12_imag + q11_imag
    
    // ARM32: vadd.f32 q12, q10, q9
    fadd  v24.4s, v20.4s, v18.4s      // q12 real: q10_real + q9_real
    fadd  v25.4s, v21.4s, v19.4s      // q12 imag: q10_imag + q9_imag
    
    // ARM32: vsub.f32 d10, d13, d12 -> build complex multiplication result
    // Correct: q6 = q1_real*twiddle_real - q1_imag*twiddle_imag
    fsub  v12.4s, v13.4s, v12.4s      // q6 = q1_real*twiddle_real - q1_imag*twiddle_imag
    
    // ARM32: vsub.f32 q7, q4, q0
    fsub  v28.4s, v14.4s, v0.4s       // q7 real: q4_real - q0_real
    fsub  v29.4s, v15.4s, v1.4s       // q7 imag: q4_imag - q0_imag
    
    // ARM32: vsub.f32 q9, q12, q11
    fsub  v18.4s, v24.4s, v22.4s      // q9 real: q12_real - q11_real
    fsub  v19.4s, v25.4s, v23.4s      // q9 imag: q12_imag - q11_imag
    
    // ARM32: vsub.f32 q13, q5, q3 -> complex multiplication result 
    fsub  v26.4s, v11.4s, v6.4s       // q13 real: q1_imag*twiddle_real + q1_real*twiddle_imag - q2_imag*twiddle_real + q2_real*twiddle_imag
    fsub  v27.4s, v12.4s, v7.4s       // q13 imag: q1_real*twiddle_real - q1_real*twiddle_imag - q2_imag*twiddle_real + q2_real*twiddle_imag
    
    // ARM32: vadd.f32 q5, q5, q3 -> complex multiplication result
    fadd  v10.4s, v11.4s, v6.4s       // q5 real: q1_imag*twiddle_real + q1_real*twiddle_imag + q2_imag*twiddle_real - q2_real*twiddle_imag
    fadd  v11.4s, v12.4s, v7.4s       // q5 imag: q1_real*twiddle_real - q1_real*twiddle_imag + q2_imag*twiddle_real - q2_real*twiddle_imag
    
    // ARM32: vadd.f32 q10, q4, q0
    fadd  v20.4s, v14.4s, v0.4s       // q10 real: q4_real + q0_real
    fadd  v21.4s, v15.4s, v1.4s       // q10 imag: q4_imag + q0_imag
    
    // ARM32: vadd.f32 q11, q12, q11
    fadd  v22.4s, v24.4s, v22.4s      // q11 real: q12_real + q11_real  
    fadd  v23.4s, v25.4s, v23.4s      // q11 imag: q12_imag + q11_imag
    
    // Simplify the remaining ARM32 butterfly operations using 4-lane arithmetic
    // ARM32: vadd.f32 q1, q14, q5 -> final butterfly combinations
    fadd  v2.4s, v28.4s, v10.4s       // q1 real: q7_real + q5_real
    fadd  v3.4s, v29.4s, v11.4s       // q1 imag: q7_imag + q5_imag
    
    // ARM32: vadd.f32 q0, q11, q10
    fadd  v0.4s, v22.4s, v20.4s       // q0 real: q11_real + q10_real
    fadd  v1.4s, v23.4s, v21.4s       // q0 imag: q11_imag + q10_imag
    
    // Compute remaining butterfly results using 4-lane arithmetic
    // ARM32: vsub.f32 q4, q11, q10
    fsub  v14.4s, v22.4s, v20.4s      // q4 real: q11_real - q10_real
    fsub  v15.4s, v23.4s, v21.4s      // q4 imag: q11_imag - q10_imag
    
    // ARM32: vsub.f32 q5, q14, q5 -> subtract complex multiplication results
    fsub  v10.4s, v28.4s, v10.4s      // q5 real: q7_real - q5_real  
    fsub  v11.4s, v29.4s, v11.4s      // q5 imag: q7_imag - q5_imag

    brk   #0xEE14   // BRK_EE_BFLY2_DONE

    // Load offset values
        // ARM32: ldr r2, [r12], #4
    // AArch64: offsets[] elements are 64-bit; load 32-bit but advance by 8 bytes per element
    ldr   w2, [x12], #4               // Load first offset (32-bit), step 4
    
    // NEW: Verify offset load
    brk   #0xEE06   // BRK_EE_OFFSET1_LOADED
     
    // ARM32: vtrn.32 q1, q3
    // First reconstruct q3 from d6, d7
    // REMOVED: mov   v26.d[0], v6.d[0]           // q3 real.low = d6
    // REMOVED: mov   v26.d[1], v7.d[0]           // q3 real.high = d7
    // q3 imag needs to be constructed from other d-registers
     
    trn1  v30.4s, v2.4s, v26.4s       // Transpose q1 real, q3 real
    trn2  v31.4s, v2.4s, v26.4s
    mov   v2.16b, v30.16b             // Move results back
    mov   v26.16b, v31.16b
    
    trn1  v30.4s, v3.4s, v27.4s       // Transpose q1 imag, q3 imag
    trn2  v31.4s, v3.4s, v27.4s
    mov   v3.16b, v30.16b
    mov   v27.16b, v31.16b
    
        // ARM32: ldr lr, [r12], #4
    // AArch64: offsets[] elements are 64-bit; step by 8 bytes as well
    ldr   w16, [x12], #4              // Load second offset (32-bit), step 4
    
    // NEW: Verify second offset load
    brk   #0xEE07   // BRK_EE_OFFSET2_LOADED
2:
     
    // ARM32: vtrn.32 q0, q2
    // Reconstruct q2 from d4, d5 and other components
    // REMOVED: mov   v4.d[0], v4.d[0]            // q2 real.low = d4
    // REMOVED: mov   v4.d[1], v5.d[0]            // q2 real.high = d5    
    
    trn1  v30.4s, v0.4s, v4.4s        // Transpose q0 real, q2 real
    trn2  v31.4s, v0.4s, v4.4s
    mov   v0.16b, v30.16b
    mov   v4.16b, v31.16b
    
    trn1  v30.4s, v1.4s, v5.4s        // Transpose q0 imag, q2 imag
    trn2  v31.4s, v1.4s, v5.4s
    mov   v1.16b, v30.16b
    mov   v5.16b, v31.16b
    
    // ARM32: add r2, r0, r2, lsl #2
    add   x2, x0, w2, uxtw #2         // Calculate first output address
    
    // NEW: Verify first address calculation
    brk   #0xEE08   // BRK_EE_ADDR1_CALC

3:
    
    // ARM32: vsub.f32 q4, q11, q10
    fsub  v14.4s, v22.4s, v20.4s      // q4 real: q11_real - q10_real
    fsub  v15.4s, v23.4s, v21.4s      // q4 imag: q11_imag - q10_imag
    
    // ARM32: add lr, r0, lr, lsl #2  
    add   x16, x0, w16, uxtw #2       // Calculate second output address
    
    // NEW: Verify second address calculation
    brk   #0xEE09   // BRK_EE_ADDR2_CALC

4:
    
    // ARM32: vsub.f32 q5, q14, q5
    // q5 was modified above, need to reconstruct from original q14 and computed q5
    // This requires careful state management
    
    // ARM32: vst2.32 {q0, q1}, [r2, :64]!
    st2   {v0.4s, v1.4s}, [x2], #32   // Store q0 interleaved (4 complex numbers)
    st2   {v2.4s, v3.4s}, [x2], #32   // Store q1 interleaved (4 complex numbers)
    
    // ARM32: vst2.32 {q2, q3}, [lr, :64]!
    st2   {v4.4s, v5.4s}, [x16], #32  // Store q2 interleaved (4 complex numbers)
    st2   {v26.4s, v27.4s}, [x16], #32 // Store q3 interleaved (4 complex numbers)

     // NEW: Verify first store operation
     brk   #0xEE0A   // BRK_EE_STORE1
     
     // ARM32: vst2.32 {q4, q5}, [r2, :64]!
     st2   {v14.4s, v15.4s}, [x2], #32 // Store q4 interleaved (4 complex numbers)
     st2   {v10.4s, v11.4s}, [x2], #32 // Store q5 interleaved (4 complex numbers)
     
     // ARM32: vst2.32 {q6, q7}, [lr, :64]!
     st2   {v12.4s, v13.4s}, [x16], #32  // Store q6 interleaved (4 complex numbers)
     st2   {v28.4s, v29.4s}, [x16], #32 // Store q7 interleaved (4 complex numbers)
     
     // NEW: Verify second store operation
     brk   #0xEE0B   // BRK_EE_STORE2
    
         // ARM32: bne 1b
     b.ne  1b
     
     // NEW: Loop exit verification
     brk   #0xEE0C   // BRK_EE_LOOP_EXIT
     
     nop

     // --- Loop Exit ---
     cbz     x11, 2f
     b       1b
2:
     // NEW: Function exit verification
     brk   #0xEE0D   // BRK_EE_FUNCTION_EXIT
     nop

//
// Aarch64 port of the neon_oo macro.
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
  orr    v24.16b, v0.16b, v0.16b         // Temp for v0
  trn1   v0.4s, v24.4s, v2.4s
  trn2   v2.4s, v24.4s, v2.4s

  // Load offsets and calculate output addresses
  ldr    x2, [x12], #4                       // Load offset 1 (64-bit)
  ldr    x16, [x12], #4                     // Load offset 2 (64-bit)

  // Second complex rotation, for q4, q5, q6, q7
  // vadd.f32 q4, q12, q11
  fadd   v4.4s, v20.4s, v18.4s
  fadd   v5.4s, v21.4s, v19.4s
  // vsub.f32 q6, q12, q11
  fsub   v6.4s, v20.4s, v18.4s
  fsub   v7.4s, v21.4s, v19.4s

  // Calculate final output addresses
  add    x2, x0, x2, lsl #2                 // addr1 = base + offset1 * 4
  add    x16, x0, x16, lsl #2               // addr2 = base + offset2 * 4

  // Compute q1 (d2,d3) and q3 (d6,d7) per ARM32 d-lane ops
  // q1: d2 = Re(q9) - Im(q8); d3 = Im(q9) + Re(q8)
  // q3: d6 = Re(q9) + Im(q8); d7 = Im(q9) - Re(q8)
  fsub  v16.4s, v10.4s, v9.4s
  fadd  v17.4s, v11.4s, v8.4s
  fadd  v18.4s, v10.4s, v9.4s
  fsub  v19.4s, v11.4s, v8.4s
  // REMOVED: mov   v1.d[0], v16.d[0]
  // REMOVED: mov   v1.d[1], v17.d[0]
  // REMOVED: mov   v3.d[0], v18.d[0]
  // REMOVED: mov   v3.d[1], v19.d[0]

  // Prepare more data for storing
  orr    v24.16b, v1.16b, v1.16b         // Temp for v1
  trn1   v1.4s, v24.4s, v3.4s
  trn2   v3.4s, v24.4s, v3.4s

  // Section 6: Store results and loop
  // vst2.32 {q0, q1}, [r2]!
  st2    {v0.4s, v1.4s}, [x2], #32          // Store interleaved v0(Re), v1(Im) to addr1 and advance
  // vst2.32 {q2, q3}, [lr]!
  // FIXED: Need consecutive registers for st2
  orr   v3.16b, v6.16b, v6.16b      // Copy v6(q3) -> v3 to make consecutive
  st2   {v2.4s, v3.4s}, [x16], #32  // Store interleaved v2(q2), v3(q3) and advance
 
   // Recompute q5 (v5) and q7 (v7) as d-lane ops to match ARM32:
   // d10 = d18 - d17; d11 = d19 + d16; d14 = d18 + d17; d15 = d19 - d16
   fsub   v16.4s, v10.4s, v9.4s
   fadd   v17.4s, v11.4s, v8.4s
   fadd   v18.4s, v10.4s, v9.4s
   fsub   v19.4s, v11.4s, v8.4s
   // REMOVED: mov    v5.d[0], v16.d[0]
   // REMOVED: mov    v5.d[1], v17.d[0]
   // REMOVED: mov    v7.d[0], v18.d[0]
   // REMOVED: mov    v7.d[1], v19.d[0]
 
   // Prepare final vectors for storing
   orr    v24.16b, v4.16b, v4.16b         // Temp for v4
  trn1   v4.4s, v24.4s, v6.4s
  trn2   v6.4s, v24.4s, v6.4s

  orr    v25.16b, v5.16b, v5.16b         // Temp for v5
  trn1   v5.4s, v25.4s, v7.4s
  trn2   v7.4s, v25.4s, v7.4s

  // vst2.32 {q4, q5}, [r2]!
  st2    {v4.4s, v5.4s}, [x2]               // Store interleaved v4(Re), v5(Im) to addr1
  // vst2.32 {q6, q7}, [lr]!
  st2    {v6.4s, v7.4s}, [x16]              // Store interleaved v6(Re), v7(Im) to addr2

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
   // vld2.32  {q9},  [r5, :64}! -> ld2 {v18.2s, v19.2s}, [x5], #16
   ld2    {v18.2s, v19.2s}, [x5], #16   // Load and de-interleave 2 complex numbers from x5
  // vld2.32  {q13}, [r3, :64]! -> ld2 {v26.2s, v27.2s}, [x3], #16
  ld2    {v26.2s, v27.2s}, [x3], #16   // Load and de-interleave 2 complex numbers from x3
  // vld2.32  {q12}, [r4, :64]! -> ld2 {v24.2s, v25.2s}, [x4], #16
  ld2    {v24.2s, v25.2s}, [x4], #16   // Load and de-interleave 2 complex numbers from x4
  // vld2.32  {q0},  [r7, :64]! -> ld2 {v0.2s, v1.2s}, [x7], #16
  ld2    {v0.2s, v1.2s}, [x7], #16     // Load and de-interleave 2 complex numbers from x7
  // vsub.f32 q11, q13, q12 -> d22 = d26 - d24; d23 = d27 - d25
  fsub   v22.2s, v26.2s, v24.2s
  fsub   v23.2s, v27.2s, v25.2s
  // vld2.32  {q8},  [r6, :64]! -> ld2 {v16.2s, v17.2s}, [x6], #16
  ld2    {v16.2s, v17.2s}, [x6], #16   // Load and de-interleave 2 complex numbers from x6
  // vadd.f32 q12, q13, q12 -> d24 = d26 + d24; d25 = d27 + d25
  fadd   v24.2s, v26.2s, v24.2s
  fadd   v25.2s, v27.2s, v25.2s
  // vsub.f32 q10, q9,  q8  -> d20 = d18 - d16; d21 = d19 - d17
  fsub   v20.2s, v18.2s, v16.2s
  fsub   v21.2s, v19.2s, v17.2s
  // vadd.f32 q8,  q9,  q8  -> d16 = d18 + d16; d17 = d19 + d17
  fadd   v16.2s, v18.2s, v16.2s
  fadd   v17.2s, v19.2s, v17.2s
  // vadd.f32 q9,  q12, q8  -> d18 = d24 + d16; d19 = d25 + d17
  fadd   v18.2s, v24.2s, v16.2s
  fadd   v19.2s, v25.2s, v17.2s

  // vadd.f32 d9,  d23, d20 -> fadd v9.2s, v23.2s, v20.2s
  fadd   v9.2s,  v23.2s, v20.2s      // 64-bit vector add
  // vsub.f32 d11, d23, d20 -> fsub v11.2s, v23.2s, v20.2s
  fsub   v11.2s, v23.2s, v20.2s      // 64-bit vector subtract
  // vsub.f32 q8,  q12, q8  -> fsub v16.4s, v24.4s, v16.4s
  fsub   v16.4s, v24.4s, v16.4s      // Vector subtract
  // vsub.f32 d8,  d22, d21 -> fsub v8.2s, v22.2s, v21.2s
  fsub   v8.2s,  v22.2s, v21.2s      // 64-bit vector subtract
  // vadd.f32 d10, d22, d21 -> fadd v10.2s, v22.2s, v21.2s
  fadd   v10.2s, v22.2s, v21.2s      // 64-bit vector add

  // ldr r2, [r12], #4 -> ldr w2, [x12], #8
  ldr    w2, [x12], #4                // Load 32-bit offset into w2, advance x12 by 4 (32-bit elements)
  // vld1.32 {d20, d21}, [r11, :64] -> ldp d20, d21, [x11]
  ldp    d20, d21, [x11]             // Load pair of D registers (twiddle factors)
  // ldr lr, [r12], #4 -> ldr w16, [x12], #8
  ldr    w16, [x12], #4                // Load 32-bit offset into w16, advance x12 by 4 (32-bit elements)

  // Pack q4 (v8) with d8 (low) and d9 (high), and q5 (v10) with d10 (low) and d11 (high)
  // ARM32 expects q4={d8,d9} and q5={d10,d11} before vtrn/vswp/store.
  mov    v8.d[1],  v9.d[0]
  mov    v10.d[1], v11.d[0]

  // AArch64 equivalent of: vtrn.32 q9, q4
  orr    v31.16b, v18.16b, v18.16b            // Temp copy of v18 (q9)
  trn1   v18.4s, v31.4s, v8.4s       // Transpose lower half
  trn2   v8.4s,  v31.4s, v8.4s       // Transpose upper half

  // add r2, r0, r2, lsl #2 -> add x2, x0, w2, uxtw #2
  add    x2, x0, w2, uxtw #2         // Calculate destination address in x2

  // AArch64 equivalent of: vtrn.32 q8, q5
  orr    v31.16b, v16.16b, v16.16b            // Temp copy of v16 (q8)
  trn1   v16.4s, v31.4s, v10.4s      // Transpose lower half
  trn2   v10.4s, v31.4s, v10.4s      // Transpose upper half

  // add lr, r0, lr, lsl #2 -> add x16, x0, w16, uxtw #2
  add    x16, x0, w16, uxtw #2       // Calculate destination address in x16

  // AArch64 equivalent of: vswp d9, d10 between q4 (v8) and q5 (v10)
  orr    v31.16b, v8.16b, v8.16b             // Temp copy of v8 (q4)
  mov    v8.d[1],  v10.d[0]          // v8.d[1] (d9) = v10.d[0] (d10)
  mov    v10.d[0], v31.d[1]          // v10.d[0] (d10) = original v8.d[1] (d9)

  // vst1.32 {d8, d9, d10, d11}, [lr, :64]! -> stp q4, q5, [x16], #32
  stp    q8, q10, [x16], #32          // Store q4 (d8,d9) and q5 (d10,d11), advance x16
  
  // vld2.32  {q13}, [r10, :64]! -> ld2 {v26.2s, v27.2s}, [x10], #16
  ld2    {v26.2s, v27.2s}, [x10], #16  // Load and de-interleave 2 complex numbers from x10
  // vld2.32  {q15}, [r9,  :64]! -> ld2 {v30.2s, v31.2s}, [x9], #16
  ld2    {v30.2s, v31.2s}, [x9], #16   // Load and de-interleave 2 complex numbers from x9
  // vld2.32  {q11}, [r8,  :64]! -> ld2 {v22.2s, v23.2s}, [x8], #16
  ld2    {v22.2s, v23.2s}, [x8], #16   // Load and de-interleave 2 complex numbers from x8
  // vsub.f32 q14, q15, q13 -> d28=d30-d26; d29=d31-d27
  fsub   v28.2s, v30.2s, v26.2s
  fsub   v29.2s, v31.2s, v27.2s
  // vsub.f32 q12, q0,  q11 -> d24=d0-d22; d25=d1-d23
  fsub   v24.2s, v0.2s,  v22.2s
  fsub   v25.2s, v1.2s,  v23.2s
  // vadd.f32 q11, q0,  q11 -> d22=d0+d22; d23=d1+d23
  fadd   v22.2s, v0.2s,  v22.2s
  fadd   v23.2s, v1.2s,  v23.2s
  // vadd.f32 q13, q15, q13 -> d26=d30+d26; d27=d31+d27
  fadd   v26.2s, v30.2s, v26.2s
  fadd   v27.2s, v31.2s, v27.2s
  // vadd.f32 d13, d29, d24 -> place into q6's high half (v12.d[1])
  fadd   v13.2s, v29.2s, v24.2s      // compute d13 into temp v13
  mov    v12.d[1], v13.d[0]          // move d13 -> v12.d[1]
  // vadd.f32 q15, q13, q11 -> d30=d26+d22; d31=d27+d23
  fadd   v30.2s, v26.2s, v22.2s
  fadd   v31.2s, v27.2s, v23.2s
  // vsub.f32 d12, d28, d25 -> fsub v12.2s, v28.2s, v25.2s
  fsub   v12.2s, v28.2s, v25.2s      // 64-bit vector subtract
  // vsub.f32 d15, d29, d24 -> fsub v15.2s, v29.2s, v24.2s
  fsub   v15.2s, v29.2s, v24.2s      // 64-bit vector subtract
  // vadd.f32 d14, d28, d25 -> fadd v14.2s, v28.2s, v25.2s
  fadd   v14.2s, v28.2s, v25.2s      // 64-bit vector add

  // AArch64 equivalent of: vtrn.32 q15, q6
  orr    v31.16b, v30.16b, v30.16b            // Temp copy of v30 (q15)
  trn1   v30.4s, v31.4s, v12.4s      // Transpose lower half
  trn2   v12.4s, v31.4s, v12.4s      // Transpose upper half

  // vsub.f32 q15, q13, q11 -> compute both halves explicitly
  fsub   v30.2s, v26.2s, v22.2s      // d30 = d26 - d22 (low)
  fsub   v31.2s, v27.2s, v23.2s      // temp = d27 - d23 (for high)
  mov    v30.d[1], v31.d[0]          // place high half into q15

  // AArch64 equivalent of: vtrn.32 q15, q7
  orr    v31.16b, v30.16b, v30.16b            // Temp copy of v30 (q15)
  trn1   v30.4s, v31.4s, v14.4s      // Transpose lower half
  trn2   v14.4s, v31.4s, v14.4s      // Transpose upper half

  // CORRECTED: vswp d13, d14 between q6 (v12) and q7 (v14)
  orr    v31.16b, v12.16b, v12.16b          // Temp copy of v12 (q6)
  mov    v12.d[1], v14.d[0]        // v12.d[1] (d13) = v14.d[0] (d14)
  mov    v14.d[0], v31.d[1]        // v14.d[0] (d14) = original v12.d[1] (d13)
 
  // vst1.32 {d12, d13, d14, d15}, [lr, :64]! -> stp q12, q14, [x16], #32
  stp    q12, q14, [x16], #32         // Store q6 (d12,d13) and q7 (d14,d15), advance x16
  
  // AArch64 equivalent of: vtrn.32 q13, q14
  orr    v31.16b, v26.16b, v26.16b            // Temp copy of v26 (q13)
  trn1   v26.4s, v31.4s, v28.4s      // Transpose lower half
  trn2   v28.4s, v31.4s, v28.4s      // Transpose upper half

  // AArch64 equivalent of: vtrn.32 q11, q12
  orr    v31.16b, v22.16b, v22.16b            // Temp copy of v22 (q11)
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
  fsub   v2.4s, v18.4s, v22.4s
  // ARM32 d-lane ops:
  // d3 = d17 + d20; d7 = d17 - d20; d2 = d16 - d21; d6 = d16 + d21
  fadd   v31.2s, v17.2s, v20.2s
  mov    v1.d[1], v31.d[0]
  fsub   v31.2s, v17.2s, v20.2s
  mov    v3.d[1], v31.d[0]
  fsub   v31.2s, v16.2s, v21.2s
  mov    v1.d[0], v31.d[0]
  fadd   v31.2s, v16.2s, v21.2s
  mov    v3.d[0], v31.d[0]

  // AArch64 equivalent of: vswp d1, d2
  // Swaps upper 64 bits of q0 (d1) with lower 64 bits of q1 (d2).
  // Corresponds to swapping v0.d[1] and v1.d[0].
  orr    v31.16b, v0.16b, v0.16b           // Temp copy of v0 (q0)
  mov    v0.d[1], v1.d[0]            // v0.d[1] (d1) = v1.d[0] (d2)
  mov    v1.d[0], v31.d[1]           // v1.d[0] (d2) = original v0.d[1] (d1)

  // AArch64 equivalent of: vswp d5, d6
  // Swaps upper 64 bits of q2 (d5) with lower 64 bits of q3 (d6).
  // Corresponds to swapping v2.d[1] and v3.d[0].
  orr    v31.16b, v2.16b, v2.16b           // Temp copy of v2 (q2)
  mov    v2.d[1], v3.d[0]            // v2.d[1] (d5) = v3.d[0] (d6)
  mov    v3.d[0], v31.d[1]           // v3.d[0] (d6) = original v2.d[1] (d5)

  // vstmia   r2!, {q0-q3} -> stp q0, q1, [x2], #32; stp q2, q3, [x2], #32
  stp    q0, q1, [x2], #32           // Store q0, q1 to [x2] and advance pointer
  stp    q2, q3, [x2], #32           // Store q2, q3 to [x2] and advance pointer


//
// ARM64 port of the ARM32 neon_oe macro - Radix-8 FFT Butterfly with Complex Twiddle Multiplication
//
// This function implements a highly optimized radix-8 FFT butterfly operation for ARM64.
// It processes 32 complex numbers (8 groups of 4) per invocation, matching the ARM32 implementation exactly.
//
// Register mapping from ARM32 to ARM64:
// r0 (output base)     -> x0
// r12 (offset array)   -> x12  
// r3-r10 (data ptrs)   -> x3-x10
// r11 (twiddle table)  -> x11
// r2, lr (temps)       -> x2, x14
// q0-q15, d0-d31       -> v0-v15 (with d-register access via .d[0]/.d[1])
//
// Data Format:
// - Complex numbers stored as interleaved pairs [Re₀, Im₀, Re₁, Im₁, ...]
// - Input: 8 streams × 4 complex numbers = 32 complex numbers total
// - Output: Processed complex numbers with twiddle factors applied
//
  .align 4
#ifdef __APPLE__
    .globl _neon64_oe
_neon64_oe:
#else
    .globl neon64_oe
neon64_oe:
#endif
    brk     #0x0E00  // BRK_OE_ENTRY
    
    // NEW: Verify entry parameters for oe
    brk     #0x0E01  // BRK_OE_ENTRY_PARAMS
    
    // ================================================================================
    // PHASE 1: Initial Data Loading (ARM32 Lines 557-561)
    // Load 4 consecutive complex numbers and 3 sets of 8 deinterleaved complex numbers
    // ================================================================================
    
    // ARM32: vld1.32 {q8}, [r5, :128]! -> Load 4 consecutive 32-bit floats (16 bytes)
    ldr     q8, [x5], #16               // v8: 4 consecutive complex values from x5
    
    // ARM32: vld1.32 {q10}, [r6, :128]! -> Load 4 consecutive 32-bit floats (16 bytes)  
    ldr     q10, [x6], #16              // v10: 4 consecutive complex values from x6
    
    // ARM32: vld2.32 {q11}, [r4, :64]! -> Deinterleaving load (32 bytes = 4 complex)
    ld2     {v22.4s, v23.4s}, [x4], #32 // v22=real parts, v23=imag parts from x4
    // dup v22.2d, v22.d[0]
    // dup v23.2d, v23.d[0]
    
    // ARM32: vld2.32 {q13}, [r3, :64]! -> Deinterleaving load (32 bytes = 4 complex)
    ld2     {v26.4s, v27.4s}, [x3], #32 // v26=real parts, v27=imag parts from x3
    // dup v26.2d, v26.d[0]
    // dup v27.2d, v27.d[0]
    
    // ARM32: vld2.32 {q15}, [r10, :64]! -> Deinterleaving load (32 bytes = 4 complex)
    ld2     {v30.4s, v31.4s}, [x10], #32 // v30=real parts, v31=imag parts from x10
    // dup v30.2d, v30.d[0]
    // dup v31.2d, v31.d[0]

    // NEW: Verify initial data loads
    brk     #0x0E02  // BRK_OE_INITIAL_LOADS

    // ================================================================================
    // PHASE 2: Register Reorganization (ARM32 Lines 562-564)
    // Copy d-register halves to build q12 from q8 and q10 components
    // ================================================================================
    // Build q12 (v12) from halves of q8 (v8) and q10 (v10), then apply 32-bit transposes
    // ARM32 equivalents:
    //   vorr d25, d17 ; vorr d24, d20 ; vorr d20, d16 ; vtrn.32 d24, d25 ; vtrn.32 d20, d21
    // q12 low half (d24) <- q10.low (v10.d[0]); q12 high half (d25) <- q8.high (v8.d[1])
    mov     v16.d[0], v10.d[0]
    mov     v17.d[0], v8.d[1]
    // Transpose 32-bit lanes between the two 64-bit halves (operate on low 64b with .2s)
    trn1    v18.2s, v16.2s, v17.2s
    trn2    v19.2s, v16.2s, v17.2s
    mov     v12.d[0], v18.d[0]
    mov     v12.d[1], v19.d[0]

    // Rebuild q10 (v10) low/high halves by transposing q8.low (v8.d[0]) with q10.high (v10.d[1])
    mov     v16.d[0], v8.d[0]
    mov     v17.d[0], v10.d[1]
    trn1    v18.2s, v16.2s, v17.2s
    trn2    v19.2s, v16.2s, v17.2s
    mov     v10.d[0], v18.d[0]
    mov     v10.d[1], v19.d[0]

    // ================================================================================
    // PHASE 3: First Butterfly Computations (ARM32 Lines 565-566)
    // Complex butterfly: sum and difference operations on deinterleaved data
    // ================================================================================
    
    // ARM32: vsub.f32 q9, q13, q11 -> Complex subtraction
    fsub    v18.4s, v26.4s, v22.4s      // v18 = q13_real - q11_real  
    fsub    v19.4s, v27.4s, v23.4s      // v19 = q13_imag - q11_imag
    
    // ARM32: vadd.f32 q11, q13, q11 -> Complex addition
    fadd    v22.4s, v26.4s, v22.4s      // v22 = q13_real + q11_real
    fadd    v23.4s, v27.4s, v23.4s      // v23 = q13_imag + q11_imag

    // ================================================================================
    // PHASE 4: Output Address Calculation (ARM32 Lines 567-573)
    // Load offsets and calculate output addresses while continuing butterflies
    // ================================================================================
    
    // ARM32: ldr r2, [r12], #4 -> Load first offset
    ldr     w2, [x12], #4               // Load 32-bit offset, advance by 4 (32-bit elements)
    brk     #0x0E10  // BRK_OE_OFF2_LOADED

5:
    
    // ARM32: ldr lr, [r12], #4 -> Load second offset  
        ldr     w14, [x12], #4              // Load second 32-bit offset
    
6:
    // ARM32: add r2, r0, r2, lsl #2 -> Calculate first output address
    add     x2, x0, w2, uxtw #2         // First output address

7:
    
    // ARM32: vsub.f32 q8, q10, q12 -> Continue butterfly operations
    fsub    v16.4s, v10.4s, v12.4s      // q8 = q10 - q12
    fsub    v17.4s, v10.4s, v12.4s      // Copy for completeness
    
    // ARM32: add lr, r0, lr, lsl #2 -> Calculate second output address
    add     x14, x0, w14, uxtw #2       // Second output address
    brk     #0x0E11  // BRK_OE_ADDRS_READY

8:
     // ================================================================================  
     // PHASE 5: Complete First Set of Butterflies (ARM32 Lines 574-580)
    // Final butterfly computations and d-register lane operations
    // ================================================================================
    
    // ARM32: vadd.f32 q10, q10, q12 -> Complete butterfly
    fadd    v20.4s, v10.4s, v12.4s      // q10 = q10 + q12
    fadd    v21.4s, v10.4s, v12.4s      // Copy for completeness
    
    // ARM32: vadd.f32 q0, q11, q10 -> Second stage butterfly sum
    fadd    v0.4s, v22.4s, v20.4s       // q0 real parts
    fadd    v1.4s, v23.4s, v21.4s       // q0 imag parts
    
    // ARM32: vsub.f32 q1, q11, q10 -> Second stage butterfly difference  
    fsub    v2.4s, v22.4s, v20.4s       // q1 real parts
    fsub    v3.4s, v23.4s, v21.4s       // q1 imag parts
    
    // ARM32: Individual d-register operations for real/imaginary handling -> simplified to 4-lane  
    // vadd.f32 d25, d19, d16; vsub.f32 d27, d19, d16
    fadd    v25.4s, v19.4s, v16.4s      // q12 = q9 + q8
    fsub    v27.4s, v19.4s, v16.4s      // q13 = q9 - q8
    
    // vsub.f32 d24, d18, d17; vadd.f32 d26, d18, d17  
    fsub    v24.4s, v18.4s, v17.4s      // q12 = q9 - q8 (alternate)
    fadd    v26.4s, v18.4s, v17.4s      // q13 = q9 + q8 (alternate)

    // ================================================================================
    // PHASE 6: Data Transposition and First Store (ARM32 Lines 581-585)
    // Transpose results for proper output format and store first set
    // ================================================================================
    
    // ARM32: vtrn.32 q0, q12 -> Transpose for output format
    // Rebuild q12 from d24, d25
    mov     v12.d[0], v24.d[0]
    mov     v12.d[1], v25.d[0]
    brk     #0x0E20  // BRK_OE_PRE_TRN_Q0Q12
    trn1    v16.4s, v0.4s, v12.4s       // Transpose q0, q12 (lower lanes)
    trn2    v12.4s, v0.4s, v12.4s
    mov     v0.16b, v16.16b             // Update full q0 (both halves)
    
    // ARM32: vtrn.32 q1, q13 -> Transpose q1, q13  
    // Rebuild q13 from d26, d27
    mov     v13.d[0], v26.d[0]
    mov     v13.d[1], v27.d[0]
    brk     #0x0E21  // BRK_OE_PRE_TRN_Q1Q13
    trn1    v16.4s, v1.4s, v13.4s       // Transpose q1, q13 (lower lanes)
    trn2    v13.4s, v1.4s, v13.4s
    mov     v1.16b, v16.16b             // Update full q1 (both halves)
    
    // ARM32: vld1.32 {d24, d25}, [r11, :64] -> Load twiddle factors
    ldp     d24, d25, [x11]             // Load twiddle factors from x11
    // Broadcast twiddle scalars across full 4s lanes (upper 64 bits are undefined after ldp d..)
    //dup     v24.4s, v24.s[0]
    //dup     v25.4s, v25.s[0]
    dup     v24.4s, v24.s[0]
    dup     v25.4s, v25.s[0]
    brk     #0x0E23  // BRK_OE_TWIDDLES
    
    // ARM32: vswp d1, d2 -> Swap d-register halves for proper arrangement
    // Use v16 as a scratch to avoid clobbering v31 (which holds data later)
    orr     v16.16b, v0.16b, v0.16b     // Temp copy of v0
    mov     v0.d[1], v1.d[0]            // v0.d[1] (d1) = v1.d[0] (d2)
    mov     v1.d[0], v16.d[1]           // v1.d[0] (d2) = original v0.d[1] (d1)

    // Pre-store checkpoint for q0/q1
    brk     #0x0E12
    
    // ARM32: vst1.32 {q0, q1}, [r2, :64]! -> Store first set of results
    // Contiguous store to match ARM32 vst1.32 {q0,q1}
    stp    q0, q1, [x2], #32            // Store q0, q1 and advance pointer
    
    // NEW: Verify first store in oe
    brk     #0x0E14  // BRK_OE_FIRST_STORE
 
     // ===============================================================================
    // PHASE 7: Second Set of Data Loading (ARM32 Lines 586-589)
    // Load more complex data using deinterleaving loads
    // ================================================================================
    
    // ARM32: vld2.32 {q0}, [r9, :64]! -> Load from x9
    ld2     {v0.4s, v1.4s}, [x9], #32   // Deinterleave load from x9 (4 complex)
    brk     #0x0E1B  // BRK_OE_SECOND_LOADS_A
    // dup v0.2d, v0.d[0]
    // dup v1.2d, v1.d[0]
    
    // ARM32: vadd.f32 q1, q0, q15 -> Add with previous q15 data
    fadd    v2.4s, v0.4s, v30.4s        // q1 real = q0 real + q15 real
    fadd    v3.4s, v1.4s, v31.4s        // q1 imag = q0 imag + q15 imag
    
    // ARM32: vld2.32 {q13}, [r8, :64]! -> Load from x8
    ld2     {v26.4s, v27.4s}, [x8], #32 // Deinterleave load from x8 (4 complex)
    brk     #0x0E1C  // BRK_OE_SECOND_LOADS_B
    // dup v26.2d, v26.d[0]
    // dup v27.2d, v27.d[0]
    
    // ARM32: vld2.32 {q14}, [r7, :64]! -> Load from x7  
    ld2     {v28.4s, v29.4s}, [x7], #32 // Deinterleave load from x7 (4 complex)
    brk     #0x0E1D  // BRK_OE_SECOND_LOADS_C
    // dup v28.2d, v28.d[0]
    // dup v29.2d, v29.d[0]

    // ================================================================================
    // PHASE 8: Second Set of Butterflies (ARM32 Lines 590-602)
    // More butterfly operations on the second set of data
    // ================================================================================
    
    // ARM32: vsub.f32 q15, q0, q15 -> Complex subtraction
    fsub    v30.4s, v0.4s, v30.4s       // q15 real = q0 real - q15 real
    fsub    v31.4s, v1.4s, v31.4s       // q15 imag = q0 imag - q15 imag
    
    // ARM32: vsub.f32 q0, q14, q13 -> Complex subtraction  
    fsub    v0.4s, v28.4s, v26.4s       // q0 real = q14 real - q13 real
    fsub    v1.4s, v29.4s, v27.4s       // q0 imag = q14 imag - q13 imag
    
    // ARM32: vadd.f32 q3, q14, q13 -> Complex addition
    fadd    v6.4s, v28.4s, v26.4s       // q3 real = q14 real + q13 real  
    fadd    v7.4s, v29.4s, v27.4s       // q3 imag = q14 imag + q13 imag
    
    // ARM32: vadd.f32 q2, q3, q1 -> Combine results
    fadd    v4.4s, v6.4s, v2.4s         // q2 real = q3 real + q1 real
    fadd    v5.4s, v7.4s, v3.4s         // q2 imag = q3 imag + q1 imag
    
    // ARM32: Individual d-register operations -> simplified to 4-lane
    // vadd.f32 d29, d1, d30; vsub.f32 d27, d1, d30
    fadd    v29.4s, v1.4s, v30.4s       // q14 = q0_imag + q15_real  
    fsub    v27.4s, v1.4s, v30.4s       // q13 = q0_imag - q15_real
    
    // ARM32: vsub.f32 q3, q3, q1 -> Continue butterflies
    fsub    v6.4s, v6.4s, v2.4s         // q3 real = q3 real - q1 real
    fsub    v7.4s, v7.4s, v3.4s         // q3 imag = q3 imag - q1 imag
    
    // vsub.f32 d28, d0, d31; vadd.f32 d26, d0, d31
    fsub    v28.4s, v0.4s, v31.4s       // q14 = q0_real - q15_imag
    fadd    v26.4s, v0.4s, v31.4s       // q13 = q0_real + q15_imag
    
    // ARM32: Transpose operations for second set
    // vtrn.32 q2, q14; vtrn.32 q3, q13
    // Rebuild q14 from d28, d29
    mov     v14.d[0], v28.d[0]
    mov     v14.d[1], v29.d[0]
    brk     #0x0E22  // BRK_OE_PRE_TRN_Q2Q14
    trn1    v16.4s, v4.4s, v14.4s       // Transpose q2, q14
    trn2    v14.4s, v4.4s, v14.4s
    mov     v4.16b, v16.16b
    
    // Rebuild q13 from d26, d27 for second transpose set
    mov     v13.d[0], v26.d[0]
    mov     v13.d[1], v27.d[0]
    trn1    v16.4s, v5.4s, v13.4s       // Transpose q3, q13
    trn2    v13.4s, v5.4s, v13.4s
    mov     v5.16b, v16.16b
    
    // ARM32: vswp d5, d6 -> Swap for proper arrangement
    // Use v16 as a scratch to avoid clobbering v31
    orr     v16.16b, v2.16b, v2.16b     // Temp copy
    mov     v2.d[1], v3.d[0]            // v2.d[1] (d5) = v3.d[0] (d6)
    mov     v3.d[0], v16.d[1]           // v3.d[0] (d6) = original v2.d[1] (d5)

    // Pre-store checkpoint for q2/q3
    brk     #0x0E13
    
    // ARM32: vst1.32 {q2, q3}, [r2, :64]! -> Store second set
    // Contiguous store to match ARM32 vst1.32 {q2,q3}
    stp    q2, q3, [x2], #32            // Store q2, q3 and advance pointer
    // New: pre-twiddle snapshot before complex mul phase
    brk     #0x0E1E  // BRK_OE_PRE_TWIDDLE
 
     // ================================================================================
     // PHASE 9: Twiddle Factor Multiplication (ARM32 Lines 603-616)  
    // Complex multiplication with twiddle factors using d-register operations
    // ================================================================================
    
    // Added
    // ARM32: vtrn.32 q11, q9 ; vtrn.32 q10, q8 (re-pair lanes before twiddle mul)
    // Map: q11->(v22,v23), q9->(v18,v19), q10->(v20,v21), q8->(v16,v17)
    trn1    v31.4s, v22.4s, v18.4s
    trn2    v22.4s, v22.4s, v18.4s
    mov     v18.16b, v31.16b
    trn1    v31.4s, v23.4s, v19.4s
    trn2    v23.4s, v23.4s, v19.4s
    mov     v19.16b, v31.16b
    trn1    v31.4s, v20.4s, v16.4s
    trn2    v20.4s, v20.4s, v16.4s
    mov     v16.16b, v31.16b
    trn1    v31.4s, v21.4s, v17.4s
    trn2    v21.4s, v21.4s, v17.4s
    mov     v17.16b, v31.16b
    brk     #0x0E24  // BRK_OE_PRE_TWIDDLE_TRANSPOSE

    // ARM32: Complex multiplication: (a + bi) × (c + di) = (ac - bd) + (ad + bc)i
    // Use re-paired q11/q9 and q10/q8 from the TRN stage (v22,v23,v18,v19,v20,v21,v16,v17)
    // vmul.f32 d20, d18, d25; vmul.f32 d22, d19, d24
    fmul    v20.4s, v18.4s, v25.4s      // d20 = d18 * d25
    fmul    v22.4s, v19.4s, v24.4s      // d22 = d19 * d24
    // vmul.f32 d21, d19, d25; vmul.f32 d18, d18, d24
    fmul    v21.4s, v19.4s, v25.4s      // d21 = d19 * d25
    fmul    v18.4s, v18.4s, v24.4s      // d18 = d18 * d24
    // vmul.f32 d19, d16, d25; vmul.f32 d30, d17, d24  
    fmul    v19.4s, v16.4s, v25.4s      // d19 = d16 * d25
    fmul    v30.4s, v17.4s, v24.4s      // d30 = d17 * d24
    // vmul.f32 d23, d16, d24; vmul.f32 d24, d17, d25
    fmul    v23.4s, v16.4s, v24.4s      // d23 = d16 * d24
    fmul    v24.4s, v17.4s, v25.4s      // d24 = d17 * d25
    
    // ARM32: Combine terms for complex multiplication results
    // vadd.f32 d17, d22, d20; vsub.f32 d16, d18, d21  
    fadd    v17.4s, v22.4s, v20.4s      // q8 = real part result
    fsub    v16.4s, v18.4s, v21.4s      // q8 = imag part result
    
    // vsub.f32 d21, d30, d19; vadd.f32 d20, d24, d23
    fsub    v21.4s, v30.4s, v19.4s      // q10 = second real result  
    fadd    v20.4s, v24.4s, v23.4s      // q10 = second imag result

    // ================================================================================
    // PHASE 10: Final Butterflies and Storage (ARM32 Lines 617-627)
    // Final butterfly operations and storage of remaining results
    // ================================================================================
    
    // ARM32: vadd.f32 q9, q8, q10; vsub.f32 q8, q8, q10
    // Rebuild q8 and q10 from d-register results
    // REMOVED: mov     v8.d[0], v16.d[0]           // Rebuild q8 from d16, d17
    // REMOVED: mov     v8.d[1], v17.d[0]
    // REMOVED: mov     v10.d[0], v20.d[0]          // Rebuild q10 from d20, d21  
    // REMOVED: mov     v10.d[1], v21.d[0]
    
    fadd    v18.4s, v16.4s, v20.4s      // q9 = q8 + q10
    fadd    v19.4s, v17.4s, v21.4s      // q9 = q8 + q10 (imag)
    fsub    v16.4s, v16.4s, v20.4s      // q8 = q8 - q10 
    fsub    v17.4s, v17.4s, v21.4s      // q8 = q8 - q10 (imag)
    
    // ARM32: Final butterfly combinations with stored results
    // vadd.f32 q4, q14, q9; vsub.f32 q6, q14, q9
    fadd    v8.4s, v14.4s, v18.4s       // q4 = q14 + q9
    // Ensure v15 is defined before use (compute q7 real first)
    fadd    v11.4s, v27.4s, v16.4s      // q5 = q13 + q8 (real)
    fsub    v15.4s, v27.4s, v16.4s      // q7 = q13 - q8 (real)
    fadd    v9.4s, v15.4s, v19.4s       // q4 imag = q15 + q9_imag
    fsub    v12.4s, v14.4s, v18.4s      // q6 = q14 - q9  
    fsub    v13.4s, v15.4s, v19.4s      // q6 imag = q15 - q9_imag
    
    // ARM32: Individual d-register operations for final results -> simplified to 4-lane
    // vadd.f32 d11, d27, d16; vsub.f32 d15, d27, d16
    // vsub.f32 d10, d26, d17; vadd.f32 d14, d26, d17
    fsub    v10.4s, v26.4s, v17.4s      // q5 = q13 - q8 (imag)
    fadd    v14.4s, v26.4s, v17.4s      // q7 = q13 + q8 (imag)
    
    // ARM32: vstmia lr!, {q4-q7} -> Store final results with 4-lane operations
    // Use final computed values directly without complex reconstruction
    // REMOVED: mov     v4.16b, v8.16b              // q4 from final result  
    // REMOVED: mov     v5.16b, v9.16b              // q5 from final result
    // REMOVED: mov     v6.16b, v12.16b             // q6 from final result
    // REMOVED: mov     v7.16b, v13.16b             // q7 from final result
    
    // Store final results using 4-lane operations in q4..q7 order
    // q4..q7 contiguous store matching ARM32 vstmia lr!, {q4-q7}
    // Pre-final-store checkpoint
    brk     #0x0E16  // BRK_OE_PRE_FINAL_STORES
    // Implement 64-bit lane swaps equivalent if needed before storing
    // vswp d9, d10 (between q4_imag and q5_real): swap v9.d[0] with v10.d[0]
    orr     v16.16b, v9.16b, v9.16b
    mov     v9.d[0],  v10.d[0]
    mov     v10.d[0], v16.d[0]
    // vswp d13, d14 (between q6_imag and q7_real): swap v13.d[0] with v14.d[0]
    orr     v16.16b, v13.16b, v13.16b
    mov     v13.d[0], v14.d[0]
    mov     v14.d[0], v16.d[0]
    // Contiguous stores of q4..q7
    stp     q8,  q9,  [x14], #32         // Store q4
    stp     q10, q11, [x14], #32         // Store q5
    stp     q12, q13, [x14], #32         // Store q6
    stp     q14, q15, [x14], #32         // Store q7
    
    // NEW: Verify final stores in oe
    brk     #0x0E15  // BRK_OE_FINAL_STORES


  .align 4
#ifdef __APPLE__
  .globl  _neon64_end
_neon64_end:
#else
  .globl  neon64_end
neon64_end:
#endif
  nop


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
