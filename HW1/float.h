#ifndef FLOAT_H
#define FLOAT_H

#include <stdint.h>

typedef uint16_t fp16_t;
static inline fp16_t fp32_to_fp16(float f);
static inline float fp16_to_fp32(float f);
static inline float bits_to_fp32(uint32_t w);
static inline uint32_t fp32_to_bits(float f);

#endif // FLOAT_H