#ifndef FFTS_CODEGEN_ARM64_MACROS_H
#define FFTS_CODEGEN_ARM64_MACROS_H

#include <string.h>
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>

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

/* Toggle AArch64 FP add/sub and mla/mls (vector) by flipping bit 23 where applicable */
static inline void arm64_patch_fp_toggle(uint32_t *blob, size_t size_words, int sign)
{
#ifndef FFTS_ARM64_DISABLE_SIGN_PATCH
    if (sign >= 0) return;
    for (size_t i = 0; i < size_words; ++i) {
        uint32_t w = blob[i];
        /* Match vector FADD/FSUB (0x0e20/0x0ea0 .. with op=0xd4 in bits 15..10) */
        if ( ( (w & 0xFF000000u) == 0x0E000000u ) && /* AdvSIMD FP data */
             ( (w & 0x0000FC00u) == (0xD4u << 10) ) ) {
            /* Toggle bit 23 to swap FADD<->FSUB */
            blob[i] ^= 0x00800000u;
            continue;
        }
        /* Match vector FMLA/FMLS (0x0e20/0x0ea0 .. with op=0xCC in bits 15..10) */
        if ( ( (w & 0xFF000000u) == 0x0E000000u ) &&
             ( (w & 0x0000FC00u) == (0xCCu << 10) ) ) {
            /* Toggle bit 23 to swap FMLA<->FMLS */
            blob[i] ^= 0x00800000u;
            continue;
        }
    }
#else
    (void)blob; (void)size_words; (void)sign;
#endif
}

static inline void arm64_patch_neon64_x8_t(uint32_t *blob, int sign)
{
#ifndef FFTS_ARM64_DISABLE_SIGN_PATCH
    if (sign >= 0) return;
    extern const uint8_t neon64_x8_t[];
    extern const uint8_t neon64_ee[];
    size_t size_words = (size_t)(neon64_ee - neon64_x8_t) / sizeof(uint32_t);
    arm64_patch_fp_toggle(blob, size_words, sign);
#else
    (void)blob; (void)sign;
#endif
}

/* Patch helper that toggles bit 21 at the given word indices for negative sign */
static inline void arm64_patch_indices(uint32_t *blob, const int *indices, size_t count, int sign)
{
#ifndef FFTS_ARM64_DISABLE_SIGN_PATCH
    if (sign < 0) {
        const char *dbg = getenv("FFTS_DEBUG_PATCH");
        for (size_t i = 0; i < count; ++i) {
            if (dbg) {
                fprintf(stderr, "[ARM64][patch] blob=%p idx=%zu before=%08x\n", (void*)blob, (size_t)indices[i], blob[indices[i]]);
            }
            blob[indices[i]] ^= 0x00800000u; /* AArch64 FADD<->FSUB / FMLA<->FMLS */
            if (dbg) {
                fprintf(stderr, "[ARM64][patch] blob=%p idx=%zu after =%08x\n", (void*)blob, (size_t)indices[i], blob[indices[i]]);
            }
        }
    }
#else
    (void)blob; (void)indices; (void)count; (void)sign;
#endif
}

static inline void arm64_patch_neon64_ee(uint32_t *blob, int sign)
{
    (void)blob; (void)sign;
}

static inline void arm64_patch_neon64_oo(uint32_t *blob, int sign)
{
    (void)blob; (void)sign;
}

static inline void arm64_patch_neon64_eo(uint32_t *blob, int sign)
{
    (void)blob; (void)sign;
}

static inline void arm64_patch_neon64_oe(uint32_t *blob, int sign)
{
    (void)blob; (void)sign;
}

#endif /* FFTS_CODEGEN_ARM64_MACROS_H */ 