//
// Optimized ARM64 neon64_oe - Radix-8 FFT Butterfly with Twiddle Multiplication
//
// This is a streamlined version of the ARM32 neon_oe port that reduces register
// complexity while maintaining exact functional behavior.
//
// Register Usage:
// x0: Output base, x12: Offsets, x3-x10: Data streams, x11: Twiddles
// x2, x14: Temp addresses
//
.align 4
#ifdef __APPLE__
    .globl _neon64_oe_optimized
_neon64_oe_optimized:
#else
    .globl neon64_oe_optimized  
neon64_oe_optimized:
#endif

    // Phase 1: Load data (ARM32 lines 557-561)
    ldr     q8, [x5], #16                   // vld1.32 {q8}, [r5, :128]!
    ldr     q10, [x6], #16                  // vld1.32 {q10}, [r6, :128]!
    ld2     {v22.4s, v23.4s}, [x4], #32    // vld2.32 {q11}, [r4, :128]!
    ld2     {v26.4s, v27.4s}, [x3], #32    // vld2.32 {q13}, [r3, :128]!
    ld2     {v30.4s, v31.4s}, [x10], #32   // vld2.32 {q15}, [r10, :128]!

    // Phase 2: Register reorganization (ARM32 lines 562-564) - Simplified
    ext     v25.8b, v8.8b, v8.8b, #8       // d25 = upper half of q8 (d17)
    mov     v24.8b, v10.8b                 // d24 = lower half of q10 (d20)
    mov     v20.8b, v8.8b                  // d20 = lower half of q8 (d16)
    
    // Phase 3: First butterflies (ARM32 lines 565-566)
    fsub    v18.4s, v26.4s, v22.4s         // q9 = q13 - q11 (complex subtract)
    fsub    v19.4s, v27.4s, v23.4s
    fadd    v22.4s, v26.4s, v22.4s         // q11 = q13 + q11 (complex add)  
    fadd    v23.4s, v27.4s, v23.4s

    // Phase 4: Address calculation with transpose (ARM32 lines 567-573)
    ldr     w2, [x12], #8                  // Load first offset
    trn1    v16.2s, v24.2s, v25.2s         // vtrn.32 d24, d25
    trn2    v25.2s, v24.2s, v25.2s
    mov     v24.16b, v16.16b
    
    ldr     w14, [x12], #8                 // Load second offset
    ext     v21.8b, v10.8b, v10.8b, #8     // Extract upper half for transpose
    trn1    v16.2s, v20.2s, v21.2s         // vtrn.32 d20, d21
    trn2    v21.2s, v20.2s, v21.2s
    mov     v20.16b, v16.16b
    
    add     x2, x0, w2, uxtw #2            // Calculate addresses
    add     x14, x0, w14, uxtw #2

    // Phase 5: Complete butterflies (ARM32 lines 574-580) - Optimized
    // Build q12 = {d24, d25} and q10 = {d20, d21}
    mov     v12.d[0], v24.d[0]
    mov     v12.d[1], v25.d[0]
    mov     v10.d[0], v20.d[0]
    mov     v10.d[1], v21.d[0]
    
    fsub    v16.4s, v10.4s, v12.4s         // q8 = q10 - q12
    fadd    v20.4s, v10.4s, v12.4s         // q10 = q10 + q12
    
    fadd    v0.4s, v22.4s, v20.4s          // q0 = q11 + q10
    fadd    v1.4s, v23.4s, v20.4s
    fsub    v2.4s, v22.4s, v20.4s          // q1 = q11 - q10
    fsub    v3.4s, v23.4s, v20.4s

    // Individual d-register operations (optimized)
    fadd    v25.2s, v19.2s, v16.2s         // d25 = d19 + d16
    fsub    v27.2s, v19.2s, v16.2s         // d27 = d19 - d16
    fsub    v24.2s, v18.2s, v17.2s         // d24 = d18 - d17
    fadd    v26.2s, v18.2s, v17.2s         // d26 = d18 + d17

    // Phase 6: Transpose and store (ARM32 lines 581-585) - Streamlined
    mov     v12.d[0], v24.d[0]             // Rebuild q12 = {d24, d25}
    mov     v12.d[1], v25.d[0]
    mov     v13.d[0], v26.d[0]             // Rebuild q13 = {d26, d27}
    mov     v13.d[1], v27.d[0]
    
    trn1    v16.4s, v0.4s, v12.4s          // Transpose operations
    trn2    v12.4s, v0.4s, v12.4s
    mov     v0.16b, v16.16b
    trn1    v16.4s, v1.4s, v13.4s
    trn2    v13.4s, v1.4s, v13.4s
    mov     v1.16b, v16.16b

    ldp     d24, d25, [x11]                // Load twiddle factors
    
    // Swap d1, d2 (simplified)
    mov     v16.d[0], v0.d[1]              // Save d1
    mov     v0.d[1], v1.d[0]               // d1 = d2
    mov     v1.d[0], v16.d[0]              // d2 = saved d1
    
    stp     q0, q1, [x2], #32              // Store first results

    // Phase 7-8: Second set processing (ARM32 lines 586-602) - Optimized
    ld2     {v0.4s, v1.4s}, [x9], #32      // Load from x9
    fadd    v2.4s, v0.4s, v30.4s           // Add with q15
    fadd    v3.4s, v1.4s, v31.4s
    
    ld2     {v26.4s, v27.4s}, [x8], #32    // Load from x8, x7
    ld2     {v28.4s, v29.4s}, [x7], #32

    fsub    v30.4s, v0.4s, v30.4s          // Second set butterflies
    fsub    v31.4s, v1.4s, v31.4s
    fsub    v0.4s, v28.4s, v26.4s
    fsub    v1.4s, v29.4s, v27.4s
    fadd    v6.4s, v28.4s, v26.4s
    fadd    v7.4s, v29.4s, v27.4s
    
    fadd    v4.4s, v6.4s, v2.4s            // Combine results
    fadd    v5.4s, v7.4s, v3.4s
    fsub    v6.4s, v6.4s, v2.4s
    fsub    v7.4s, v7.4s, v3.4s

    // Individual d-register ops
    fadd    v29.2s, v1.2s, v30.2s
    fsub    v27.2s, v1.2s, v30.2s
    fsub    v28.2s, v0.2s, v31.2s
    fadd    v26.2s, v0.2s, v31.2s

    // Transpose and swap operations (streamlined)
    mov     v14.d[0], v28.d[0]
    mov     v14.d[1], v29.d[0]
    mov     v13.d[0], v26.d[0]
    mov     v13.d[1], v27.d[0]
    
    trn1    v16.4s, v4.4s, v14.4s
    trn2    v14.4s, v4.4s, v14.4s
    mov     v4.16b, v16.16b
    trn1    v16.4s, v5.4s, v13.4s
    trn2    v13.4s, v5.4s, v13.4s
    mov     v5.16b, v16.16b

    // Swap d5, d6
    mov     v16.d[0], v2.d[1]
    mov     v2.d[1], v3.d[0]
    mov     v3.d[0], v16.d[0]
    
    stp     q2, q3, [x2], #32              // Store second results

    // Phase 9: Twiddle multiplication (ARM32 lines 603-616) - Optimized
    // Direct complex multiplication without excessive register moves
    fmul    v20.2s, v6.2s, v25.2s          // Complex multiply with twiddles
    fmul    v22.2s, v7.2s, v24.2s
    fmul    v21.2s, v7.2s, v25.2s
    fmul    v18.2s, v6.2s, v24.2s
    fmul    v19.2s, v4.2s, v25.2s
    fmul    v30.2s, v5.2s, v24.2s
    fmul    v23.2s, v4.2s, v24.2s
    fmul    v31.2s, v5.2s, v25.2s

    fadd    v17.2s, v22.2s, v20.2s         // Combine results
    fsub    v16.2s, v18.2s, v21.2s
    fsub    v21.2s, v30.2s, v19.2s
    fadd    v20.2s, v31.2s, v23.2s

    // Phase 10: Final butterflies and store (ARM32 lines 617-627)
    mov     v8.d[0], v16.d[0]              // Rebuild final q-registers
    mov     v8.d[1], v17.d[0]
    mov     v10.d[0], v20.d[0]
    mov     v10.d[1], v21.d[0]
    
    fadd    v18.4s, v8.4s, v10.4s          // Final butterflies
    fsub    v16.4s, v8.4s, v10.4s
    
    fadd    v4.4s, v14.4s, v18.4s          // Combine with stored results
    fadd    v5.4s, v14.4s, v18.4s
    fsub    v6.4s, v14.4s, v18.4s
    fsub    v7.4s, v14.4s, v18.4s
    
    // Final d-register operations
    fadd    v11.2s, v27.2s, v16.2s
    fsub    v15.2s, v27.2s, v16.2s
    fsub    v10.2s, v26.2s, v17.2s
    fadd    v14.2s, v26.2s, v17.2s
    
    // Rebuild and swap final results
    mov     v4.d[0], v4.d[0]
    mov     v4.d[1], v5.d[0]
    mov     v5.d[0], v10.d[0]
    mov     v5.d[1], v11.d[0]
    mov     v6.d[0], v6.d[0]
    mov     v6.d[1], v7.d[0]
    mov     v7.d[0], v14.d[0]
    mov     v7.d[1], v15.d[0]
    
    // Final swaps
    mov     v16.d[0], v4.d[1]
    mov     v4.d[1], v5.d[0]
    mov     v5.d[0], v16.d[0]
    mov     v16.d[0], v6.d[1]
    mov     v6.d[1], v7.d[0]
    mov     v7.d[0], v16.d[0]
    
    stp     q4, q5, [x14], #32             // Store final results
    stp     q6, q7, [x14], #32

    ret 