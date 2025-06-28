#include <stdio.h>

// Function to simulate ffts_ctzl (count trailing zeros)
static int ffts_ctzl(size_t n) {
    int count = 0;
    while ((n & 1) == 0) {
        n >>= 1;
        count++;
    }
    return count;
}

int main() {
    size_t sizes[] = {16, 32, 64, 128, 256};
    
    for (int i = 0; i < 5; i++) {
        size_t N = sizes[i];
        int N_log_2 = ffts_ctzl(N);
        printf("N=%zu, N_log_2=%d, N_log_2 & 1 = %d => %s function\n", 
               N, N_log_2, N_log_2 & 1, (N_log_2 & 1) ? "neon_static_o" : "neon_static_e");
        
        if (N == 32) {
            printf("  Calls: neon_static_x8_t_{f|i}(dout, 32, ws + 8)\n");
        } else if (N == 64) {
            printf("  Calls: 3x neon_static_x4_{f|i}(data + offset, ws)\n");
            printf("         neon_static_x8_t_{f|i}(dout, 64, ws + 32)\n");
        }
    }
    
    return 0;
}
