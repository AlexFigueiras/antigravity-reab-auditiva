#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// Nominal PFFFT structure types
typedef struct PFFFT_Setup PFFFT_Setup;

typedef enum {
  PFFFT_REAL,
  PFFFT_COMPLEX
} pffft_direction_t;

// API interface
PFFFT_Setup *pffft_new_setup(int N, pffft_direction_t transform);
void pffft_destroy_setup(PFFFT_Setup *);
void pffft_transform_ordered(PFFFT_Setup *setup, const float *input, float *output, float *work, pffft_direction_t direction);
void *pffft_aligned_malloc(size_t nb_bytes);
void pffft_aligned_free(void *);

#ifdef __cplusplus
}
#endif
