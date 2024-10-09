#include <stdio.h>
#include <stdint.h>
#include <math.h>
#include <stdbool.h>
#include <limits.h>

typedef uint16_t fp16_t;

float bits_to_fp32(uint32_t w)
{
    union {
        uint32_t as_bits;
        float as_value;
    } fp32 = {.as_bits = w};
    return fp32.as_value;
}

uint32_t fp32_to_bits(float f)
{
    union {
        float as_value;
        uint32_t as_bits;
    } fp32 = {.as_value = f};
    return fp32.as_bits;
}

float fp16_to_fp32(fp16_t h)
{
    const uint32_t w = (uint32_t) h << 16;
    const uint32_t sign = w & UINT32_C(0x80000000);
    const uint32_t two_w = w + w;

    const uint32_t exp_offset = UINT32_C(0xE0) << 23;
    const float exp_scale = 0x1.0p-112f;
    const float normalized_value =
        bits_to_fp32((two_w >> 4) + exp_offset) * exp_scale;

    const uint32_t mask = UINT32_C(126) << 23;
    const float magic_bias = 0.5f;
    const float denormalized_value =
        bits_to_fp32((two_w >> 17) | mask) - magic_bias;

    const uint32_t denormalized_cutoff = UINT32_C(1) << 27;
    const uint32_t result =
        sign | (two_w < denormalized_cutoff ? fp32_to_bits(denormalized_value)
                                            : fp32_to_bits(normalized_value));
    return bits_to_fp32(result);
}

fp16_t fp32_to_fp16(float f)
{
    const float scale_to_inf = 0x1.0p+112f;
    const float scale_to_zero = 0x1.0p-110f;
    float base = (fabsf(f) * scale_to_inf) * scale_to_zero;

    const uint32_t w = fp32_to_bits(f);
    const uint32_t shl1_w = w + w;
    const uint32_t sign = w & UINT32_C(0x80000000);
    uint32_t bias = shl1_w & UINT32_C(0xFF000000);
    if (bias < UINT32_C(0x71000000))
        bias = UINT32_C(0x71000000);

    base = bits_to_fp32((bias >> 1) + UINT32_C(0x07800000)) + base;
    const uint32_t bits = fp32_to_bits(base);
    const uint32_t exp_bits = (bits >> 13) & UINT32_C(0x00007C00);
    const uint32_t mantissa_bits = bits & UINT32_C(0x00000FFF);
    const uint32_t nonsign = exp_bits + mantissa_bits;
    return (sign >> 16) |
           (shl1_w > UINT32_C(0xFF000000) ? UINT16_C(0x7E00) : nonsign);
}

void cal_complex(float num1_real, float num1_image, float num2_real, float num2_image) {
    printf("============Test Case Start============\n");
    printf("Input num1: %f + %fi \n", num1_real, num1_image);
    printf("Input num2: %f + %fi \n", num2_real, num2_image);

    float real_part_fp32 = num1_real * num2_real - num1_image * num2_image;
    float imag_part_fp32 = num1_real * num2_image + num1_image * num2_real;

    fp16_t num1_real_fp16 = fp32_to_fp16(num1_real);
    fp16_t num1_image_fp16 = fp32_to_fp16(num1_image);
    fp16_t num2_real_fp16 = fp32_to_fp16(num2_real);
    fp16_t num2_image_fp16 = fp32_to_fp16(num2_image);

    float real_part_fp16 = fp16_to_fp32(num1_real_fp16) * fp16_to_fp32(num2_real_fp16)
                         - fp16_to_fp32(num1_image_fp16) * fp16_to_fp32(num2_image_fp16);
    float imag_part_fp16 = fp16_to_fp32(num1_real_fp16) * fp16_to_fp32(num2_image_fp16)
                         + fp16_to_fp32(num1_image_fp16) * fp16_to_fp32(num2_real_fp16);

    printf("Result in FP32: %f + %fi \n", real_part_fp32, imag_part_fp32);
    printf("Result in FP16: %f + %fi \n", real_part_fp16, imag_part_fp16);
    printf("============Test Case End============\n\n");
}

int main() {
    float num1_real = 1.5f;
    float num1_image = 1.75f;
    float num2_real = -3.0f;
    float num2_image = -1.5f;
    cal_complex(num1_real, num1_image, num2_real, num2_image);
    num1_real = 2.25f;
    num1_image = 6.5f;
    num2_real = 3.375f;
    num2_image = 10.5f;
    cal_complex(num1_real, num1_image, num2_real, num2_image);
    num1_real = -1.125f;
    num1_image = -3.5f;
    num2_real = -4.5f;
    num2_image = 2.25f;
    cal_complex(num1_real, num1_image, num2_real, num2_image);
    return 0;
}
