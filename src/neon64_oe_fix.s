    // Fixed neon64_oe implementation
    // Key fixes:
    // 1. Build q12 correctly from q8 and q10 halves
    // 2. Fix offset loading increment from #8 to #4
    // 3. Activate dup instructions for proper 4-lane operations
    // 4. Fix butterfly operations to use correct registers

    // PHASE 1: Initial Data Loading
    ldr     q8, [x5], #16               // v8: 4 consecutive complex values from x5
    ldr     q10, [x6], #16              // v10: 4 consecutive complex values from x6
    
    ld2     {v22.4s, v23.4s}, [x4], #32 // v22=real parts, v23=imag parts from x4
    dup     v22.2d, v22.d[0]            // Duplicate lower half to upper half
    dup     v23.2d, v23.d[0]
    
    ld2     {v26.4s, v27.4s}, [x3], #32 // v26=real parts, v27=imag parts from x3
    dup     v26.2d, v26.d[0]
    dup     v27.2d, v27.d[0]
    
    ld2     {v30.4s, v31.4s}, [x10], #32 // v30=real parts, v31=imag parts from x10
    dup     v30.2d, v30.d[0]
    dup     v31.2d, v31.d[0]

    // PHASE 2: Build q12 from q8 and q10 components
    // ARM32: vorr d25, d17, d17  -> Copy high half of q8 to high half of q12
    // ARM32: vorr d24, d20, d20  -> Copy low half of q10 to low half of q12
    // ARM32: vorr d20, d16, d16  -> Copy low half of q8 to low half of q10
    
    // Extract halves and build q12 (v24=low, v25=high)
    mov     v24.d[0], v10.d[0]          // d24 = low half of q10
    mov     v25.d[0], v8.d[1]           // d25 = high half of q8
    mov     v12.d[0], v24.d[0]          // Build q12: low half from q10
    mov     v12.d[1], v25.d[0]          // Build q12: high half from q8
    
    // Update q10 by copying low half of q8 to low half of q10
    mov     v20.d[0], v8.d[0]           // d20 = low half of q8
    mov     v10.d[0], v20.d[0]          // Copy to low half of q10
    
    // PHASE 3: First Butterfly Computations
    fsub    v18.4s, v26.4s, v22.4s      // v18 = q13_real - q11_real  
    fsub    v19.4s, v27.4s, v23.4s      // v19 = q13_imag - q11_imag
    
    fadd    v22.4s, v26.4s, v22.4s      // v22 = q13_real + q11_real
    fadd    v23.4s, v27.4s, v23.4s      // v23 = q13_imag + q11_imag

    // PHASE 4: Output Address Calculation
    ldr     w2, [x12], #4               // FIX: Load 32-bit offset, advance by 4 (not 8)
    
    // Transpose operations on d24, d25 (now containing q12 halves)
    trn1    v16.2s, v24.2s, v25.2s      // Transpose 32-bit elements
    trn2    v25.2s, v24.2s, v25.2s
    mov     v24.16b, v16.16b
    
    ldr     w14, [x12], #4              // FIX: Load second offset, advance by 4
    
    // Extract d21 from q10 for transpose
    ext     v21.16b, v10.16b, v10.16b, #8  // Extract high half of q10
    
    // Transpose d20, d21
    trn1    v16.2s, v20.2s, v21.2s
    trn2    v21.2s, v20.2s, v21.2s
    mov     v20.16b, v16.16b
    
    add     x2, x0, w2, uxtw #2         // First output address
    
    // Continue butterfly operations with correct q8, q10, q12
    fsub    v16.4s, v10.4s, v12.4s      // q8 real = q10 - q12
    fsub    v17.4s, v10.4s, v12.4s      // q8 imag = q10 - q12
    
    add     x14, x0, w14, uxtw #2       // Second output address

    // PHASE 5: Complete First Set of Butterflies
    fadd    v20.4s, v10.4s, v12.4s      // q10 = q10 + q12
    fadd    v21.4s, v10.4s, v12.4s      // Both parts
    
    fadd    v0.4s, v22.4s, v20.4s       // q0 = q11 + q10
    fadd    v1.4s, v23.4s, v21.4s
    
    fsub    v2.4s, v22.4s, v20.4s       // q1 = q11 - q10
    fsub    v3.4s, v23.4s, v21.4s
    
    // Individual d-register operations
    fadd    v25.2s, v19.2s, v16.2s      // d25 = d19 + d16
    fsub    v27.2s, v19.2s, v16.2s      // d27 = d19 - d16
    
    fsub    v24.2s, v18.2s, v17.2s      // d24 = d18 - d17
    fadd    v26.2s, v18.2s, v17.2s      // d26 = d18 + d17

    // Continue with rest of implementation...