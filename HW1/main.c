#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "float.h"
#include "pow.h"

typedef uint16_t fp16_t;

// 函數用於逐行比較兩個文件，並返回不同的行數
int compare_files(const char* file1, const char* file2) {
    FILE* f1 = fopen(file1, "r");
    FILE* f2 = fopen(file2, "r");

    if (f1 == NULL || f2 == NULL) {
        printf("Error opening comparison files.\n");
        return -1;
    }

    char line1[100], line2[100];
    int differences = 0;
    int line_num = 0;

    // 逐行比較文件內容
    while (fgets(line1, sizeof(line1), f1) && fgets(line2, sizeof(line2), f2)) {
        line_num++;
        if (strcmp(line1, line2) != 0) {
            differences++;
            printf("Difference at line %d:\nGolden: %sOutput: %s\n", line_num, line1, line2);
        }
    }

    fclose(f1);
    fclose(f2);
    return differences;
}

int main() {
    const char* input_file = "testdata.txt";
    const char* golden_file_fp32 = "golden_fp32.txt";
    const char* golden_file_fp16 = "golden_fp16.txt";
    const char* output_file_fp32 = "output_fp32.txt";
    const char* output_file_fp16 = "output_fp16.txt";

    FILE* infile = fopen(input_file, "r");
    FILE* outfile_fp32 = fopen(output_file_fp32, "w");
    FILE* outfile_fp16 = fopen(output_file_fp16, "w");

    if (infile == NULL || output_file_fp32 == NULL) {
        printf("Error opening file\n");
        return 0;
    }

    double base;
    int exponent;
    char line[100];
    int num_values = 0;  // Track the number of values processed

    while (fgets(line, sizeof(line), infile)) {
        // 從文件中讀取 base 和 exponent
        if (sscanf(line, "%lf,%d", &base, &exponent) == 2) {
            // 計算 fp32 次方結果
            double result_fp32 = myPow(base, exponent);
            // 將 fp32 結果寫入 output_fp32 文件
            fprintf(outfile_fp32, "%lf\n", result_fp32);

            // 將 base 轉換為 fp16
            fp16_t base_fp16 = fp32_to_fp16((float)base);
            // 使用 fp16 進行次方計算
            fp16_t result_fp16 = myPow_fp16(base_fp16, exponent);
            // 將 fp16 結果以 16 進制格式寫入 output_fp16 文件
            fprintf(outfile_fp16, "0x%04x\n", result_fp16);
            num_values++;
        } else {
            fprintf(outfile_fp32, "Invalid input format: %s", line);
            fprintf(outfile_fp16, "Invalid input format: %s", line);
        }
    }

    fclose(infile);
    fclose(outfile_fp32);
    fclose(outfile_fp16);

    // Calculate memory usage for FP32 and FP16
    size_t memory_usage_fp32 = num_values * sizeof(float);  // Memory used by FP32 results
    size_t memory_usage_fp16 = num_values * sizeof(fp16_t); // Memory used by FP16 results

    // Print memory usage comparison
    printf("Memory usage for FP32 results: %zu bytes\n", memory_usage_fp32);
    printf("Memory usage for FP16 results: %zu bytes\n", memory_usage_fp16);
    printf("Memory savings by using FP16: %zu bytes (%.2f%% reduction)\n",
           memory_usage_fp32 - memory_usage_fp16,
           100.0 * (memory_usage_fp32 - memory_usage_fp16) / memory_usage_fp32);

    // 比較 golden 和 output 文件，計算不同結果的行數
    int differences = compare_files(golden_file_fp32, output_file_fp32);
    if (differences >= 0) {
        printf("FP32: Number of differing lines: %d\n", differences);
    }

    differences = compare_files(golden_file_fp16, output_file_fp16);
    if (differences >= 0) {
        printf("FP16: Number of differing lines: %d\n", differences);
    }


    return 0;
}