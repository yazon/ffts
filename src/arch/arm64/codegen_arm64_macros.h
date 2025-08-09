#ifndef FFTS_CODEGEN_ARM64_MACROS_H
#define FFTS_CODEGEN_ARM64_MACROS_H

#include <string.h>
#include <stdint.h>
#include <stddef.h>

/*
 * Copy the machine-code blob delimited by the two linker symbols into the
 * output buffer *p (which points to a stream of 32-bit words) and advance
 * the buffer pointer past the copied bytes.  The symbols are expected to be
 * defined in neon64.s with .globl visibility so their addresses resolve at
 * link time.
 */
#define ARM64_CAST_PTR(T, expr) ((T)(expr))

static inline uint32_t *arm64_copy_blob(uint32_t **p,
                                           const void *start_sym,
                                           const void *end_sym)
{
    uint32_t *dst = *p;
    const uint8_t *start = (const uint8_t *)start_sym;
    const uint8_t *end   = (const uint8_t *)end_sym;
    size_t bytes = (size_t)(end - start);
    memcpy(dst, start, bytes);
    *p += bytes / sizeof(uint32_t);
    return dst;      /* return address of copied code */
}

/*
 * Some kernels need a sign-dependent patch.
 *
 * On ARM32 NEON we flipped bit 21 (0x0020_0000) to toggle add/sub in certain
 * vector FP opcodes. On AArch64, FP vector add/sub and mla/mls differ by bit 23
 * (0x0080_0000) instead. Reuse the original instruction indices but flip the
 * correct AArch64 bit so FADD<->FSUB and FMLA<->FMLS toggle as intended.
 */
static inline void arm64_patch_neon64_x8_t(uint32_t *blob, int sign)
{
    if (sign < 0) {
        /* These word indices are identical to the ARM32 variant. */
        static const int idx[] = { 31, 32, 33, 34, 65, 66, 70, 74,
                                   97, 98, 102, 104 };
        for (unsigned i = 0; i < sizeof(idx)/sizeof(idx[0]); ++i) {
            blob[idx[i]] ^= 0x00800000u; /* toggle AArch64 add/sub select bit (bit 23) */
        }
    }
}

/* Patch helper that toggles bit 21 at the given word indices for negative sign */
static inline void arm64_patch_indices(uint32_t *blob, const int *indices, size_t count, int sign)
{
    if (sign < 0) {
        for (size_t i = 0; i < count; ++i) {
            blob[indices[i]] ^= 0x00800000u; /* AArch64 FADD<->FSUB / FMLA<->FMLS */
        }
    }
}

static inline void arm64_patch_neon64_ee(uint32_t *blob, int sign)
{
    static const int idx[] = {33,37,38,39,40,41,44,45,46,47,48,57};
    arm64_patch_indices(blob, idx, sizeof(idx)/sizeof(idx[0]), sign);
}

static inline void arm64_patch_neon64_oo(uint32_t *blob, int sign)
{
    static const int idx[] = {12,13,14,15,27,29,30,31,46,47,48,57};
    arm64_patch_indices(blob, idx, sizeof(idx)/sizeof(idx[0]), sign);
}

static inline void arm64_patch_neon64_eo(uint32_t *blob, int sign)
{
    static const int idx[] = {10,11,13,14,31,33,34,35,59,60,61,62};
    arm64_patch_indices(blob, idx, sizeof(idx)/sizeof(idx[0]), sign);
}

static inline void arm64_patch_neon64_oe(uint32_t *blob, int sign)
{
    static const int idx[] = {19,20,22,23,37,38,40,41,64,65,66,67};
    arm64_patch_indices(blob, idx, sizeof(idx)/sizeof(idx[0]), sign);
}

#endif /* FFTS_CODEGEN_ARM64_MACROS_H */ 