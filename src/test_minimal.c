#include <stdio.h>
#include <stdlib.h>
#include <complex.h>
#include <math.h>

// Forward declarations for ARM64 functions
extern void neon64_static_e_f(void *plan, float *input, float *output);
extern void neon64_static_e_i(void *plan, float *input, float *output);
extern void neon64_static_o_f(void *plan, float *input, float *output);
extern void neon64_static_o_i(void *plan, float *input, float *output);
extern void neon64_static_x4_f(void *plan, float *input, float *output);
extern void neon64_static_x4_i(void *plan, float *input, float *output);
extern void neon64_static_x8_f(void *plan, float *input, float *output);
extern void neon64_static_x8_i(void *plan, float *input, float *output);

// Mock plan structure to test basic assembly functions
typedef struct {
    void *offsets;        // offset 0
    void *ws;             // offset 8
    void *ee_ws;          // offset 16
    int i1;               // offset 24
    int i0;               // offset 28
    int is;               // offset 32
    int eos;              // offset 36
    int N;                // offset 40
} test_plan_t;

void test_function_exists(const char* name, void* func_ptr) {
    printf("Testing function %s: %s\n", name, func_ptr ? "EXISTS" : "NULL");
}

void test_simple_call(const char* name, void (*func)(void*, float*, float*)) {
    printf("Testing basic call to %s...\n", name);
    
    // Create minimal test data
    float input[32] = {0};  // 16 complex numbers (32 floats)
    float output[32] = {0};
    
    // Initialize some test data
    for(int i = 0; i < 16; i++) {
        input[i*2] = (float)i;      // real part
        input[i*2+1] = (float)i;    // imaginary part
    }
    
    // Create minimal plan
    test_plan_t plan = {0};
    plan.N = 8;
    plan.i0 = 1;
    plan.i1 = 1;
    
    // Dummy workspace data
    static float ws_data[32] = {1.0f, 0.0f, 0.707f, 0.707f}; // Some twiddle factors
    plan.ee_ws = ws_data;
    
    static int offset_data[8] = {0, 8, 16, 24, 32, 40, 48, 56};
    plan.offsets = offset_data;
    
    printf("  Input data prepared, calling function...\n");
    
    if (func) {
        func(&plan, input, output);
        printf("  Call completed successfully!\n");
        
        // Print first few outputs to verify
        printf("  First 4 outputs: ");
        for(int i = 0; i < 8; i++) {
            printf("%.3f ", output[i]);
        }
        printf("\n");
    } else {
        printf("  Function pointer is NULL\n");
    }
}

int main() {
    printf("=== ARM64 Assembly Function Minimal Test ===\n\n");
    
    // Test 1: Check if functions exist
    printf("Step 1: Testing function existence...\n");
    test_function_exists("neon64_static_x4_f", (void*)neon64_static_x4_f);
    test_function_exists("neon64_static_x4_i", (void*)neon64_static_x4_i);
    test_function_exists("neon64_static_x8_f", (void*)neon64_static_x8_f);
    test_function_exists("neon64_static_x8_i", (void*)neon64_static_x8_i);
    test_function_exists("neon64_static_e_f", (void*)neon64_static_e_f);
    test_function_exists("neon64_static_e_i", (void*)neon64_static_e_i);
    test_function_exists("neon64_static_o_f", (void*)neon64_static_o_f);
    test_function_exists("neon64_static_o_i", (void*)neon64_static_o_i);
    printf("\n");
    
    // Test 2: Try simplest function first (4-point FFT)
    printf("Step 2: Testing simplest function (4-point FFT)...\n");
    test_simple_call("neon64_static_x4_f", neon64_static_x4_f);
    printf("\n");
    
    // Test 3: Try 8-point FFT
    printf("Step 3: Testing 8-point FFT...\n");
    test_simple_call("neon64_static_x8_f", neon64_static_x8_f);
    printf("\n");
    
    // Test 4: Try even transform
    printf("Step 4: Testing even transform...\n");
    test_simple_call("neon64_static_e_f", neon64_static_e_f);
    printf("\n");
    
    // Test 5: Try odd transform
    printf("Step 5: Testing odd transform...\n");
    test_simple_call("neon64_static_o_f", neon64_static_o_f);
    printf("\n");
    
    printf("=== Test Completed ===\n");
    return 0;
} 