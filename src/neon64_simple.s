/*
 * neon64_simple.s: Simplified ARM64 test functions for compatibility
 * Uses only basic ARMv8.0-A instructions that QEMU supports
 */

    .text
    .align 4

// Simple 4-point FFT using only basic ARM64 instructions
#ifdef __APPLE__
    .globl _neon64_simple_x4
_neon64_simple_x4:
#else
    .globl neon64_simple_x4
neon64_simple_x4:
#endif
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Load 4 complex numbers (8 floats)
    ld1     {v0.4s, v1.4s}, [x1]          // Load input data
    
    // Simple butterfly without advanced instructions
    // Just add/subtract operations for testing
    fadd    v2.4s, v0.4s, v1.4s          // A = x0 + x1
    fsub    v3.4s, v0.4s, v1.4s          // B = x0 - x1
    
    // Store results
    st1     {v2.4s, v3.4s}, [x2]         // Store output
    
    ldp     x29, x30, [sp], #16
    ret

// Simple 8-point test - using only basic operations
#ifdef __APPLE__
    .globl _neon64_simple_x8  
_neon64_simple_x8:
#else
    .globl neon64_simple_x8
neon64_simple_x8:
#endif
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    
    // Load 8 complex numbers (16 floats)
    ld1     {v0.4s, v1.4s}, [x1], #32    // Load first 4 complex numbers
    ld1     {v2.4s, v3.4s}, [x1]         // Load next 4 complex numbers
    
    // Simple operations without FCMLA/STNP
    fadd    v4.4s, v0.4s, v2.4s          // Simple addition
    fadd    v5.4s, v1.4s, v3.4s
    fsub    v6.4s, v0.4s, v2.4s          // Simple subtraction  
    fsub    v7.4s, v1.4s, v3.4s
    
    // Store results using basic ST1
    st1     {v4.4s, v5.4s}, [x2], #32
    st1     {v6.4s, v7.4s}, [x2]
    
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

    .end