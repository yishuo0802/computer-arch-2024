#include <stdio.h>
#include <stdbool.h>
#include <limits.h>

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

