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

double myPow(double x, int n) {
    bool overflow = false;
    if (n == 0) return 1.0;
    else if (n < 0) {
        if (overflow = n == INT_MIN) n++;
        n = -n;
        x = 1.0 / x;
    }
    double res = myPow(x, n / 2);
    res *= res;
    if (overflow) res *= x;
    if (n & 1) res *= x;
    return res;
}

fp16_t myPow_fp16(fp16_t base_fp16, int n) {
    bool overflow = false;
    float base_fp32 = fp16_to_fp32(base_fp16);  // 將 base 轉換為 fp32

    if (n == 0) return fp32_to_fp16(1.0f);
    if (n < 0) {
        if (overflow = (n == INT_MIN)) n++;
        n = -n;
        base_fp32 = 1.0f / base_fp32;
    }
    float result_fp32 = fp16_to_fp32(myPow_fp16(fp32_to_fp16(base_fp32), n / 2));
    result_fp32 *= result_fp32;
    if (overflow) result_fp32 *= base_fp32;
    if (n & 1) result_fp32 *= base_fp32;

    return fp32_to_fp16(result_fp32);  // 將結果轉換回 fp16
}

void inference (float base_fp32, int exponent) {
    printf("============Inference Start============\n");
    printf("base (fp32): %f\n", base_fp32);
    printf("exponent: %d\n", exponent);
    double golden = pow(base_fp32, exponent);
    printf("golden: %f\n", golden);
    // Calculate result using fp32
    double result_fp32 = myPow(base_fp32, exponent);
    printf("Result (fp32): %f\n", result_fp32);

    // Convert base to fp16
    fp16_t base_fp16 = fp32_to_fp16(base_fp32);
    printf("Base (fp16 format): %04x\n", base_fp16);

    // Calculate result using fp16
    fp16_t result_fp16 = myPow_fp16(base_fp16, exponent);
    float result_fp16_fp32 = fp16_to_fp32(result_fp16); // Convert back to fp32 for display
    printf("Result (fp16, converted back to fp32): %f\n", result_fp16_fp32);
    printf("Precision Loss in FP32: %f\n",(golden - result_fp32));
    printf("Precision Loss in FP16: %f\n",(golden - result_fp16_fp32));
    printf("============Inference End============\n\n");
    return;
}

int main() {
    float base_fp32 = 1.25;
    int exponent = 5;
    inference(base_fp32, exponent);
    base_fp32 = -2.375;
    exponent = 3;
    inference(base_fp32, exponent);
    base_fp32 = 0.005;
    exponent = 3;
    inference(base_fp32, exponent);
    return 0;
}