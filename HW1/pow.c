#include <stdio.h>
#include <stdbool.h>
#include <limits.h>
#include <float.h>
#include <stdint.h>

typedef uint16_t fp16_t;

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
