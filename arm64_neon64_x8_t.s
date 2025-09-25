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

  mov      x3, x0               // x3 = &data[0] (base pointer)
  add      x5, x0, x1, lsl #1   // x5 = &data[0] + stride*2 = &data[2]
  add      x4, x0, x1           // x4 = &data[0] + stride*1 = &data[1]  
  add      x7, x5, x1, lsl #1   // x7 = &data[2] + stride*2 = &data[4]
  add      x6, x5, x1           // x6 = &data[2] + stride*1 = &data[3]
  add      x9, x7, x1, lsl #1   // x9 = &data[4] + stride*2 = &data[6]
  add      x8, x7, x1           // x8 = &data[4] + stride*1 = &data[5]
  add      x10, x9, x1          // x10 = &data[6] + stride*1 = &data[7]
  mov      x12, x2              // x12 = LUT current pointer (advances each iteration)

  brk      #0x8D01 // BRK_X8T_PTRS_READY

  // --- Loop Counter Setup ---
  // Initialize counter to -(stride/32). Each iteration processes 32 bytes
  // (4 complex numbers × 8 bytes per complex number)
  lsr      x11, x1, #5          // x11 = stride / 32 (number of iterations)
  neg      x11, x11             // x11 = -(stride / 32) (count up to 0)

  brk      #0x0810

1:  // === Main Loop Body ===
  
  // --- Phase 1: Load Twiddle Factors and Initial Data ---
  brk      #0x8C10 // BRK_X8_PRE_LUT_LOAD0
  ld1      {v2.4s,  v3.4s},  [x12], #32  // Load 8 twiddle factors (32 bytes) with post-increment
  brk      #0x8C11 // BRK_X8_POST_LUT_LOAD0
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
  brk      #0x8C12 // BRK_X8_PRE_LUT_LOAD1
  ld1      {v2.4s,  v3.4s},  [x12], #32  // Load next 8 twiddle factors
  brk      #0x8C13 // BRK_X8_POST_LUT_LOAD1

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
  ld1      {v14.4s, v15.4s}, [x9]        // Load 8 floats from data[6]
  ld1      {v12.4s, v13.4s}, [x7]        // Load 8 floats from data[4]

  // Begin complex multiplications for second stage
  fmul     v1.4s,  v14.4s, v2.4s         // Complex multiplication: data[6] × twiddle
  fmul     v0.4s,  v14.4s, v3.4s

  // Store intermediate results to data[1] (no post-increment)
  brk      #0x8C20 // BRK_X8_PRE_ST_DATA0
  st1      {v4.4s,  v5.4s},  [x4], #32
  brk      #0x8C21 // BRK_X8_POST_ST_DATA0

  // Continue complex multiplications
  fmul     v14.4s, v15.4s, v3.4s         // Continue data[6] × twiddle
  fmul     v4.4s,  v15.4s, v2.4s
  fadd     v15.4s, v9.4s,  v8.4s          // Combine previous results

  // Store intermediate results to data[3] (no post-increment)  
  brk      #0x8C22 // BRK_X8_PRE_ST_DATA2
  st1      {v6.4s,  v7.4s},  [x6], #32
  brk      #0x8C23 // BRK_X8_POST_ST_DATA2

  // Process data[4] with twiddle factors
  fmul     v8.4s,  v12.4s, v3.4s         // Complex multiplication: data[4] × twiddle
  fmul     v5.4s,  v13.4s, v3.4s
  fmul     v12.4s, v12.4s, v2.4s
  fmul     v9.4s,  v13.4s, v2.4s
  fadd     v14.4s, v14.4s, v1.4s         // Complete complex multiplication
  fsub     v13.4s, v4.4s,  v0.4s
  fadd     v0.4s,  v9.4s,  v8.4s

  // Load data from stream 0 for final butterfly combinations
  ld1      {v8.4s,  v9.4s},  [x3]        // Load 8 floats from data[0]

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
  brk      #0x8C20 // BRK_X8_PRE_ST_DATA0
  st2      {v0.4s,  v1.4s},  [x3], #32   // Store to data[0] with transpose and post-increment
  brk      #0x8C21 // BRK_X8_POST_ST_DATA0

  fsub     v5.4s,  v13.4s, v15.4s        // Continue preparing output data
  ld1      {v14.4s, v15.4s}, [x10]       // Load data[7] for final processing
  fsub     v7.4s,  v9.4s,  v12.4s
  ld1      {v12.4s, v13.4s}, [x8]        // Load data[5] for final processing

  st2      {v2.4s,  v3.4s},  [x5], #32   // Store to data[2] with transpose and post-increment

  // Load final set of twiddle factors
  ld1      {v2.4s,  v3.4s},  [x12], #32

  fadd     v6.4s,  v8.4s,  v10.4s
  fmul     v8.4s,  v14.4s, v2.4s         // Process data[7] × twiddle

  st2      {v4.4s,  v5.4s},  [x7], #32   // Store to data[4] with transpose and post-increment

  // --- Phase 6: Final Data Processing (Second Half) ---
  fmul     v10.4s, v15.4s, v3.4s         // Continue data[7] × twiddle
  fmul     v9.4s,  v13.4s, v3.4s         // Process data[5] × twiddle
  fmul     v11.4s, v12.4s, v2.4s
  fmul     v14.4s, v14.4s, v3.4s

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
  cbnz     x11, 1b