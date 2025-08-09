#include <stdio.h>
#include <string.h>
#include <stdint.h>

// Ensure attributes are defined before using macros
#include "../src/ffts_attributes.h"
// Ensure we include the project's NEON macro layer
#include "../src/macros.h"

// Simple print helper: store a V4SF to memory and print 4 lanes
static void print_v4sf(const char *label, V4SF v) {
    float out[4];
    V4SF_ST(out, v);
    printf("%s: %.6f %.6f %.6f %.6f\n", label, out[0], out[1], out[2], out[3]);
}

static void print_arr4(const char *label, const float *a) {
    printf("%s: %.6f %.6f %.6f %.6f\n", label, a[0], a[1], a[2], a[3]);
}

static void test_basic_ops(void) {
    float a_in[4] = {1.0f, 2.0f, 3.0f, 4.0f};
    float b_in[4] = {10.0f, 20.0f, 30.0f, 40.0f};

    V4SF a = V4SF_LD(a_in);
    V4SF b = V4SF_LD(b_in);

    print_v4sf("LD a", a);
    print_v4sf("LD b", b);

    V4SF add = V4SF_ADD(a, b);
    V4SF sub = V4SF_SUB(a, b);
    V4SF mul = V4SF_MUL(a, b);
    print_v4sf("ADD(a,b)", add);
    print_v4sf("SUB(a,b)", sub);
    print_v4sf("MUL(a,b)", mul);

    // Test store path as well
    float out_store[4] = {0};
    V4SF_ST(out_store, add);
    print_arr4("ST(add)", out_store);
}

static void test_reorg_macros(void) {
    float in[4] = {1.0f, 2.0f, 3.0f, 4.0f}; // {r0,i0,r1,i1}
    V4SF v = V4SF_LD(in);

    V4SF swapped = V4SF_SWAP_PAIRS(v);
    print_v4sf("SWAP_PAIRS(a)", swapped); // Expect {2,1,4,3}

    V4SF re = V4SF_DUPLICATE_RE(v);
    V4SF im = V4SF_DUPLICATE_IM(v);
    print_v4sf("DUP_RE(a)", re); // Expect {1,1,3,3}
    print_v4sf("DUP_IM(a)", im); // Expect {2,2,4,4}

    float a_in[4] = {1,2,3,4};
    float b_in[4] = {5,6,7,8};
    V4SF a = V4SF_LD(a_in);
    V4SF b = V4SF_LD(b_in);

    V4SF ulo = V4SF_UNPACK_LO(a, b);
    V4SF uhi = V4SF_UNPACK_HI(a, b);
    print_v4sf("UNPACK_LO(a,b)", ulo); // Expect {1,2,5,6}
    print_v4sf("UNPACK_HI(a,b)", uhi); // Expect {3,4,7,8}

    V4SF blend = V4SF_BLEND(a, b);
    print_v4sf("BLEND(a,b)", blend); // Expect {1,2,7,8}
}

static void test_literal_and_xor(void) {
    // Explicit literal patterns
    V4SF lit_mask = V4SF_LIT4(-0.0f, +0.0f, -0.0f, +0.0f);
    print_v4sf("LIT4(-0,+0,-0,+0)", lit_mask);

    V4SF lit_nums = V4SF_LD((float[4]){11.0f, 12.0f, 13.0f, 14.0f});
    print_v4sf("LD(11,12,13,14)", lit_nums);

    // Test XOR sign flip on lanes 0 and 2 using the mask
    V4SF a = V4SF_LD((float[4]){1.25f, -2.5f, 3.75f, -4.5f});
    V4SF x = V4SF_XOR(a, lit_mask);
    print_v4sf("XOR(a,mask)", x);
}

static void test_imuli(void) {
    V4SF a = V4SF_LD((float[4]){1.0f, 2.0f, 3.0f, 4.0f}); // {r0,i0,r1,i1}
    V4SF m0 = V4SF_IMULI(0, a); // multiply by -i
    V4SF m1 = V4SF_IMULI(1, a); // multiply by +i
    print_v4sf("IMULI(inv=0,a)", m0); // Expect {2,-1,4,-3}
    print_v4sf("IMULI(inv=1,a)", m1); // Expect {-2,1,-4,3}
}

static V4SF do_imul(V4SF a, V4SF tw_interleaved) {
#if defined(__aarch64__)
    return V4SF_IMUL(a, tw_interleaved);
#else
    V4SF re = V4SF_DUPLICATE_RE(tw_interleaved);
    V4SF im = V4SF_DUPLICATE_IM(tw_interleaved);
    return V4SF_IMUL(a, re, im);
#endif
}

static V4SF do_imulj(V4SF a, V4SF tw_interleaved) {
#if defined(__aarch64__)
    return V4SF_IMULJ(a, tw_interleaved);
#else
    V4SF re = V4SF_DUPLICATE_RE(tw_interleaved);
    V4SF im = V4SF_DUPLICATE_IM(tw_interleaved);
    return V4SF_IMULJ(a, re, im);
#endif
}

static void test_imul_and_imulj(void) {
    // a = {ar0, ai0, ar1, ai1}
    V4SF a = V4SF_LD((float[4]){1.0f, 2.0f, 3.0f, 4.0f});
    // twiddle b = {br0, bi0, br1, bi1}
    V4SF b = V4SF_LD((float[4]){0.5f, -1.0f, 2.0f, 0.25f});

    V4SF c = do_imul(a, b);
    V4SF d = do_imulj(a, b);

    print_v4sf("IMUL(a,b)", c);
    print_v4sf("IMULJ(a,b)", d);
}

static void test_v4sf2_ld_st(void) {
    // Interleaved memory: {r0,i0, r1,i1, r2,i2, r3,i3}
    float interleaved[8] = {1, 2, 3, 4, 5, 6, 7, 8};

    V4SF2 p = V4SF2_LD(interleaved);

    float out0[4], out1[4];
    V4SF_ST(out0, p.val[0]);
    V4SF_ST(out1, p.val[1]);

    print_arr4("V4SF2_LD.val0(re)", out0); // expected {1,3,5,7}
    print_arr4("V4SF2_LD.val1(im)", out1); // expected {2,4,6,8}

    // Store back interleaved using ST2
    float interleaved_out[8] = {0};
    V4SF2_ST(interleaved_out, p);
    printf("V4SF2_ST: ");
    for (int i = 0; i < 8; ++i) {
        printf("%.6f%s", interleaved_out[i], (i == 7 ? "\n" : " "));
    }
}

int main(void) {
    puts("== BASIC OPS ==");
    test_basic_ops();

    puts("\n== REORG MACROS ==");
    test_reorg_macros();

    puts("\n== LITERAL & XOR ==");
    test_literal_and_xor();

    puts("\n== IMULI ==");
    test_imuli();

    puts("\n== IMUL / IMULJ ==");
    test_imul_and_imulj();

    puts("\n== V4SF2 LOAD/STORE ==");
    test_v4sf2_ld_st();

    return 0;
} 