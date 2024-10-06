import sys

# 讀取testdata.txt，計算pow(a, b)，並將結果寫入golden.txt
def calculate_pow_from_file(input_file, output_file_fp32, output_file_fp16):
    with open(input_file, "r") as infile, open(output_file_fp32, "w") as outfile:
        for line in infile:
            try:
                # 移除換行符號並分割成a和b
                a_str, b_str = line.strip().split(',')
                # 將數字轉換成正確的型別
                a = float(a_str) if '.' in a_str else int(a_str, 0)
                b = int(b_str, 0)
                # 計算a的b次方
                result = pow(a, b)
                # 將結果寫入輸出文件
                outfile.write(f"{result:.6f}\n")
            except OverflowError:
                outfile.write(f"pow({a}, {b}) = Overflow\n")
            except Exception as e:
                outfile.write(f"pow({a}, {b}) = Error: {str(e)}\n")
                
    with open(input_file, "r") as infile, open(output_file_fp16, "w") as outfile:
        for line in infile:
            try:
                # 移除換行符號並分割成a和b
                a_str, b_str = line.strip().split(',')
                # 將數字轉換成正確的型別
                a = float(a_str) if '.' in a_str else int(a_str, 0)
                b = int(b_str, 0)
                # 計算a的b次方
                result = pow(a, b)
                # 將結果寫入輸出文件
                outfile.write(f"{result:.6f}\n")
            except OverflowError:
                outfile.write(f"pow({a}, {b}) = Overflow\n")
            except Exception as e:
                outfile.write(f"pow({a}, {b}) = Error: {str(e)}\n")

# 設定檔案名稱
input_file = "testdata.txt"
output_file32 = "golden_fp32.txt"
output_file16 = "golden_fp16.txt"

# 增加 int 的最大字串轉換限制
sys.set_int_max_str_digits(100000)

# 執行函式
calculate_pow_from_file(input_file, output_file32, output_file16)
