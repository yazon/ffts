#include <stdio.h>
#include <stdlib.h>
#include "../include/ffts.h"

int main() {
    printf("Starting minimal FFTS test...\n");
    
    // Try to create the smallest possible FFT plan
    ffts_plan_t *p = ffts_init_1d(2, FFTS_FORWARD);
    
    if (p) {
        printf("FFT plan created successfully!\n");
        ffts_free(p);
        printf("FFT plan freed successfully!\n");
    } else {
        printf("Failed to create FFT plan\n");
        return 1;
    }
    
    printf("Test completed successfully!\n");
    return 0;
} 