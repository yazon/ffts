#include <stddef.h>
#include <stdio.h>
#include "src/ffts_internal.h"

int main() {
    printf("ARM64 struct _ffts_plan_t member offsets:\n");
    printf("offsets: %zu\n", offsetof(struct _ffts_plan_t, offsets));
    printf("ws: %zu\n", offsetof(struct _ffts_plan_t, ws));
    printf("oe_ws: %zu\n", offsetof(struct _ffts_plan_t, oe_ws));
    printf("eo_ws: %zu\n", offsetof(struct _ffts_plan_t, eo_ws));
    printf("ee_ws: %zu\n", offsetof(struct _ffts_plan_t, ee_ws));
    printf("is: %zu\n", offsetof(struct _ffts_plan_t, is));
    printf("ws_is: %zu\n", offsetof(struct _ffts_plan_t, ws_is));
    printf("i0: %zu\n", offsetof(struct _ffts_plan_t, i0));
    printf("i1: %zu\n", offsetof(struct _ffts_plan_t, i1));
    printf("n_luts: %zu\n", offsetof(struct _ffts_plan_t, n_luts));
    printf("N: %zu\n", offsetof(struct _ffts_plan_t, N));
    printf("lastlut: %zu\n", offsetof(struct _ffts_plan_t, lastlut));
    return 0;
}
