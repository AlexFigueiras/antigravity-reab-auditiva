#include "pffft.h"
#include <stdlib.h>
#include <math.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

struct PFFFT_Setup {
    int N;
};

PFFFT_Setup *pffft_new_setup(int N, pffft_direction_t transform) {
    PFFFT_Setup *s = (PFFFT_Setup*)malloc(sizeof(PFFFT_Setup));
    s->N = N;
    return s;
}

void pffft_destroy_setup(PFFFT_Setup *s) {
    free(s);
}

// Minimalistic O(N log N) complex FFT implementation for compatibility.
// In production, user will swap this with the actual SIMD PFFFT.c
static void c_fft(float *data, int n, int is_inverse) {
    int j = 0;
    for (int i = 0; i < n; i++) {
        if (j > i) {
            float temp_r = data[j*2];
            float temp_i = data[j*2+1];
            data[j*2] = data[i*2];
            data[j*2+1] = data[i*2+1];
            data[i*2] = temp_r;
            data[i*2+1] = temp_i;
        }
        int m = n / 2;
        while (m >= 1 && j >= m) {
            j -= m;
            m /= 2;
        }
        j += m;
    }
    for (int mmax = 1; mmax < n; mmax *= 2) {
        int istep = mmax * 2;
        float theta = (is_inverse ? M_PI : -M_PI) / mmax;
        float wtemp = sin(0.5 * theta);
        float wpr = -2.0 * wtemp * wtemp;
        float wpi = sin(theta);
        float wr = 1.0;
        float wi = 0.0;
        for (int m = 0; m < mmax; m++) {
            for (int i = m; i < n; i += istep) {
                j = i + mmax;
                float tempr = wr * data[j*2] - wi * data[j*2+1];
                float tempi = wr * data[j*2+1] + wi * data[j*2];
                data[j*2] = data[i*2] - tempr;
                data[j*2+1] = data[i*2+1] - tempi;
                data[i*2] += tempr;
                data[i*2+1] += tempi;
            }
            wr = (wtemp = wr) * wpr - wi * wpi + wr;
            wi = wi * wpr + wtemp * wpi + wi;
        }
    }
    if (is_inverse) {
        for (int i = 0; i < n; i++) {
            data[i*2] /= n;
            data[i*2+1] /= n;
        }
    }
}

void pffft_transform_ordered(PFFFT_Setup *setup, const float *input, float *output, float *work, pffft_direction_t direction) {
    int N = setup->N;
    // pffft_direction_t logic
    if (direction == PFFFT_REAL) { // Treat as forward for now, copy data
        for (int i=0; i<N*2; i++) output[i] = input[i];
        c_fft(output, N, 0);
    } else { // PFFFT_COMPLEX (inverse)
        for (int i=0; i<N*2; i++) output[i] = input[i];
        c_fft(output, N, 1);
    }
}

void *pffft_aligned_malloc(size_t nb_bytes) {
    return malloc(nb_bytes); // standard malloc for the stub
}

void pffft_aligned_free(void * p) {
    free(p); // standard free for the stub
}
