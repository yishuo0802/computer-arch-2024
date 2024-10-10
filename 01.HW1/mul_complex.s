.data
    begin:   .string "============Test Case Start============\n"
    end:     .string "============Test Case End============\n\n"
    input1:  .string "Input num1:"
    input2:  .string "Input num2:"
    output1: .string "Result in FP32:"
    output2: .string "Result in FP16:"
    plus:    .string " + "
    img:     .string "i \n"
    status1: .string "Denormalization Unsupported! \n"
.text
main:
    li a0, 0x3FC00000 # a0: 1.5
    li a1, 0x3FE00000 # a1: 1.75
    li a2, 0xC0400000 # a2: -3.0
    li a3, 0xBFC00000 # a3: -1.5
    addi sp, sp, -4
    sw ra, 0(sp)
    jal ra, inference

    li a0, 0x40100000 # a0: 2.25
    li a1, 0x40D00000 # a1: 6.5
    li a2, 0x40580000 # a2: 3.375
    li a3, 0x41280000 # a3: 10.5
    jal ra, inference

    li a0, 0xBF900000 # a0: -1.125
    li a1, 0xC0600000 # a1: -3.5
    li a2, 0xC0900000 # a2: -4.5
    li a3, 0x40100000 # a3: 2.25
    jal ra, inference
    lw ra, 0(sp)
    addi sp, sp, 4

    j exit

add_float32:
    #a0: src1 #a1: src2
add_float32__prologue:
    addi sp, sp, -12
    sw s0, 0(sp)
    sw s1, 4(sp)
    sw s2, 8(sp)
add_float32__body:
    mv s0, a0
    mv s1, a1
    #Extract sign, exponent, and mantissa
    srli t0, s0, 31 # t0: src1 sign
    srli t1, s1, 31 # t1: src2 sign
    srli t2, s0, 23 # t2: src1 exponent
    andi t2, t2, 0xFF
    srli t3, s1, 23 # t3: src2 exponent
    andi t3, t3, 0xFF
    li s2, 0x7FFFFF
    and t4, s0, s2 # t4: src1 mantissa
    and t5, s1, s2 # t5: src2 mantissa
    # Set the implict leading one
    li s2, 0x800000
    or t4, t4, s2
    or t5, t5, s2

    # Compare exponents and align mantissas
    bge t2, t3, add_float32__align_a1

add_float32__align_a0:
    sub t6, t3, t2 # t6: exponent difference
    srl t4, t4, t6 # shift a0's mantissa
    add t2, t2, t6 # Set exponent of a0 to exponent of a1
    j add_float32__add_or_sub

add_float32__align_a1:
    sub t6, t2, t3 # t6: exponent difference
    srl t5, t5, t6 # shift a1's mantissa
    add t3, t3, t6 # Set exponent of a1 to exponent of a1

add_float32__add_or_sub:
    beq t0, t1, add_float32__add
add_float32__sub:
    blt t4, t5, add_float32_change_sign
    sub t4, t4, t5
    j add_float32__normalize
add_float32_change_sign:
    sub t4, t5, t4
    xori t0, t0, 1
    j add_float32__normalize

add_float32__add:
    add t4, t4, t5
add_float32__normalize:
    li s2, 0x800000
    blt t4, s2, add_float32__normalize_loop
    li s2, 0x1000000
    bge t4, s2, add_float32__shift_right
    j add_float32__pack_result
add_float32__normalize_loop:
    and t3, t4, s2 # check if leading bit is 1
    bne t3, zero, add_float32__pack_result
    slli t4, t4, 1 # mantissa left shift 1
    addi t2, t2, -1 # exponent - 1
    j add_float32__normalize_loop

add_float32__shift_right:
    srli t4, t4, 1 # mantissa right shift 1
    addi t2, t2, 1 # exponent + 1

add_float32__pack_result:
    slli t0, t0, 31
    slli t2, t2, 23
    or t0, t0, t2
    li s2, 0x7fffff
    and t4, t4, s2
    or a0, t0, t4

add_float32__epilogue:
    lw s0, 0(sp)
    lw s1, 4(sp)
    lw s2, 8(sp)
    addi sp, sp, 12
    ret

mul_uint32:
mul_uint32__prologue:
    # a0 = a0 * a1
    #? optimize find the smaller one
    addi sp, sp, -8
    sw s0, 0(sp)
    sw s1, 4(sp)
    mv s0, a0
    mv s1, a1
mul_uint32__body:
    li t0, 0 # init value
    li t1, 0 # loop index
mul_uint32__loop_start:
    bge t1, s1, mul_uint32__loop_end
    add t0, t0, s0
    addi t1, t1, 1
    j mul_uint32__loop_start
mul_uint32__loop_end:
mul_uint32__epilogue:
    lw s0, 0(sp)
    lw s1, 4(sp)
    addi sp, sp, 8

    mv a0, t0
    ret

mul_float32:
    #a0 = a0 * a1
mul_float32__prologue:
    addi sp, sp, -12
    sw s0, 0(sp)
    sw s1, 4(sp)
    sw s2, 8(sp)
    mv s0, a0
    mv s1, a1
mul_float32__body:
# Extract sign bits
    srli t0, s0, 31
    andi t0, t0, 1 # t0: sign of a0
    srli t1, s1, 31
    andi t1, t1, 1 # t1: sign of a1
# Extract exponent
    slli t2, s0, 1
    srli t2, t2, 24 # t2: exponent of a0
    slli t3, s1, 1
    srli t3, t3, 24 # t3: exponent of a1
# Extract mantissa
    li s2, 0x7FFFFF
    and t4, s0, s2
    li s2, 0x800000
    or t4, t4, s2 # t4: mantissa of a0
    li s2, 0x7FFFFF
    and t5, s1, s2
    li s2, 0x800000
    or t5, t5, s2 # t5: mantissa of a1
# Determine sign
    xor t0, t0, t1 # t0: sign of result
# Add exponent
    add t2, t2, t3 # t2: exponent of result
    li t6, 127 # t6: bias
    sub t2, t2, t6
# Multiply mantissa
    addi sp, sp, -28
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw t1, 8(sp)
    sw t2, 12(sp)
    sw t3, 16(sp)
    sw t4, 20(sp)
    sw t5, 24(sp)
    srli a0, t4, 8
    srli a1, t5, 8
    jal ra, mul_uint32
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw t1, 8(sp)
    lw t2, 12(sp)
    lw t3, 16(sp)
    lw t4, 20(sp)
    lw t5, 24(sp)
    addi sp, sp, 28
    srli t4, a0, 7 # t4: mantissa of result
# Normalize
    srai t5, t4, 24
    andi t5, t5, 1
    beq t5, zero, mul_float32__norm_done
    addi t2, t2, 1 # exponent + 1
    srli t4, t4, 1 # mantissa normalize
mul_float32__norm_done:

    # Pack the result
    slli t0, t0, 31
    slli t2, t2, 23
    li s2, 0x7fffff
    and t4, t4, s2
    or a0, t0, t2
    or a0, a0, t4
mul_float32__epilogue:
    lw s0, 0(sp)
    lw s1, 4(sp)
    lw s2, 8(sp)
    addi sp, sp, 12
    ret

fp16_to_fp32:
    # a0: input fp16_t h
fp16_to_fp32__prologue:
    addi sp, sp, -12
    sw s0, 0(sp)
    sw s1, 4(sp)
    sw s2, 8(sp)
fp16_to_fp32__body:
    mv s0, a0 # w
    slli s0, s0, 16
    li s2, 0x80000000
    and t0, s0, s2 # t0: sign
    add s0, s0, s0 # two_w

    li t1, 0xE0 # t1: exp_offset
    slli t1, t1, 23
    li t2, 0x07800000 # t2: exp_scale
    srli t3, s0, 4 # t3: normalized_value
    add t3, t3, t1

    addi sp, sp, -20
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw t1, 8(sp)
    sw t2, 12(sp)
    sw t3, 16(sp)
    mv a0, t3
    mv a1, t2
    jal ra, mul_float32
    mv t3, a0
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw t1, 8(sp)
    lw t2, 12(sp)
    lw t3, 16(sp)
    addi sp, sp, 20
    mv t3, a0
    li t4, 126
    slli t4, t4, 23 # t4: mask
    li t5, 0x3F000000 # t5: magic_bias
    srli t6, s0, 17 # t6: denormalized_value
    or t6, t6, t4
    sub t6, t6, t5

    li s1, 1
    slli s1, s1, 27 # s1: denormalized_cutoff
    bltu s0, s1, fp16_to_fp32__taken
    j fp16_to_fp32__nottaken
fp16_to_fp32__taken:
    mv a0, t6
fp16_to_fp32__nottaken:
    mv a0, t3
fp16_to_fp32__if_end:
    or a0, t0, a0 # a0: result
fp16_to_fp32__epilogue:
    lw s0, 0(sp)
    lw s1, 4(sp)
    lw s2, 8(sp)
    addi sp, sp, 12
    ret

fp32_to_fp16:
    # a0: input float f
fp32_to_fp16__prologue:
    addi sp, sp, -16
    sw s0, 0(sp)
    sw s1, 4(sp)
    sw s2, 8(sp)
    sw s3, 12(sp)
fp32_to_fp16__body:
    mv s0, a0
    li t0, 0x77800000 # t0: scale_to_inf
    li t1, 0x08800000 # t1: scale_to_zero
    li s3, 0x7fffffff
    and t2, s0, s3 # t2: fabs(f)
    addi sp, sp, -16
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw t1, 8(sp)
    sw t2, 12(sp)
    mv a0, t2
    mv a1, t0
    jal ra, mul_float32
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw t1, 8(sp)
    lw t2, 12(sp)
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw t1, 8(sp)
    sw t2, 12(sp)
    mv a0, a0
    mv a1, t1
    jal ra, mul_float32
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw t1, 8(sp)
    lw t2, 12(sp)
    addi sp, sp, 16
    mv t2, a0 # t2: base

    mv a0, s0

    mv t3, a0 # t3: w
    add t4, t3, t3 # t4: shl1_w
    li s3, 0x80000000
    and t5, t3, s3 # t5: sign
    li s3, 0xFF000000
    and t6, t4, s3 # t6: bias
    li s1, 0x71000000
    bgeu t6, s1, fp32_to_fp16__bge_taken
    mv t6, s1
fp32_to_fp16__bge_taken:
    srli s1, t6, 1
    li s3, 0x07800000
    add s1, s1, s3

    addi sp, sp, -32
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw t1, 8(sp)
    sw t2, 12(sp)
    sw t3, 16(sp)
    sw t4, 20(sp)
    sw t5, 24(sp)
    sw t6, 28(sp)
    mv a0, s1
    mv a1, t2
    jal ra, add_float32
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw t1, 8(sp)
    lw t2, 12(sp)
    lw t3, 16(sp)
    lw t4, 20(sp)
    lw t5, 24(sp)
    lw t6, 28(sp)
    addi sp, sp, 32

    mv t2, a0 # t2: base, bits

    srai t0, t2, 13
    li s3, 0x00007C00
    and t0, t0, s3 # t0: exp_bits
    li s3, 0x00000FFF
    and t1, t2, s3 # t1: mantissa_bits
    add t0, t0, t1 # t0: nonsign
    srli s0, t5, 16
    li s1, 0xFF000000
    mv s2, zero
    bltu s1, t4, fp32_to_fp16__bge_taken2
    or s0, s0, t0
    j fp32_to_fp16__bge_taken2_end
fp32_to_fp16__bge_taken2:
    li s3, 0x7E00
    or s0, s0, s3
fp32_to_fp16__bge_taken2_end:
    mv a0, s0
fp32_to_fp16__epilogue:
    lw s0, 0(sp)
    lw s1, 4(sp)
    lw s2, 8(sp)
    lw s3, 12(sp)
    addi sp, sp, 16
    ret

inference:
inference__prologue:
    addi sp, sp, -20
    sw s0, 0(sp)
    sw s1, 4(sp)
    sw s2, 8(sp)
    sw s3, 12(sp)
    sw s4, 16(sp)
inference__body:

    mv s0, a0 # s0: num1 real
    mv s1, a1 # s1: num1 img
    mv s2, a2 # s2: num2 real
    mv s3, a3 # s3: num2 img

    li a7, 4
    la a0, begin
    ecall
    li a7, 4
    la a0, input1
    ecall
    li a7, 2
    mv a0, s0
    ecall
    li a7, 4
    la a0, plus
    ecall
    li a7, 2
    mv a0, s1
    ecall
    li a7, 4
    la a0, img
    ecall
    li a7, 4
    la a0, input2
    ecall
    li a7, 2
    mv a0, s2
    ecall
    li a7, 4
    la a0, plus
    ecall
    li a7, 2
    mv a0, s3
    ecall
    li a7, 4
    la a0, img
    ecall

    addi sp, sp, -4
    sw ra, 0(sp)
    mv a0, s0
    mv a1, s2
    jal ra, mul_float32
    mv t0, a0
    addi sp, sp, -4
    sw t0, 0(sp)
    mv a0, s1
    mv a1, s3
    jal ra, mul_float32
    lw t0, 0(sp)
    addi sp, sp, 4
    # put the sub symbol into sign bit
    li s4, 0x80000000
    xor t1, a0, s4

    addi sp, sp, -8
    sw t0, 0(sp)
    sw t1, 4(sp)
    mv a0, t0
    mv a1, t1
    jal ra, add_float32
    lw t0, 0(sp)
    lw t1, 4(sp)
    addi sp, sp, 8
    mv t0, a0 # t0: real_part_fp32

    addi sp, sp, -4
    sw t0, 0(sp)
    mv a0, s0
    mv a1, s3
    jal ra, mul_float32
    lw t0, 0(sp)
    addi sp, sp, 4
    mv t1, a0

    addi sp, sp, -8
    sw t0, 0(sp)
    sw t1, 4(sp)
    mv a0, s1
    mv a1, s2
    jal ra, mul_float32
    lw t0, 0(sp)
    lw t1, 4(sp)
    addi sp, sp, 8

    addi sp, sp, -8
    sw t0, 0(sp)
    sw t1, 4(sp)
    mv a0, a0
    mv a1, t1
    jal ra, add_float32
    lw t0, 0(sp)
    lw t1, 4(sp)
    addi sp, sp, 8
    mv t1, a0 # t1: imag_part_fp32

    addi sp, sp, -8
    sw t0, 0(sp)
    sw t1, 4(sp)
    mv a0, s0
    jal ra, fp32_to_fp16
    lw t0, 0(sp)
    lw t1, 4(sp)
    addi sp, sp, 8
    mv s0, a0 # s0: fp16 num1_real

    addi sp, sp, -8
    sw t0, 0(sp)
    sw t1, 4(sp)
    mv a0, s1
    jal ra, fp32_to_fp16
    lw t0, 0(sp)
    lw t1, 4(sp)
    addi sp, sp, 8
    mv s1, a0 # s1: fp16 num1_img

    addi sp, sp, -8
    sw t0, 0(sp)
    sw t1, 4(sp)
    mv a0, s2
    jal ra, fp32_to_fp16
    lw t0, 0(sp)
    lw t1, 4(sp)
    addi sp, sp, 8
    mv s2, a0 # s2: fp16 num2_real

    addi sp, sp, -8
    sw t0, 0(sp)
    sw t1, 4(sp)
    mv a0, s3
    jal ra, fp32_to_fp16
    lw t0, 0(sp)
    lw t1, 4(sp)
    addi sp, sp, 8
    mv s3, a0 # s3: fp16 num2_img

    addi sp, sp, -8
    sw t0, 0(sp)
    sw t1, 4(sp)
    mv a0, s0
    jal ra, fp16_to_fp32
    lw t0, 0(sp)
    lw t1, 4(sp)
    addi sp, sp, 8
    mv s0, a0 # s0: fp16 num1_real to fp32

    addi sp, sp, -8
    sw t0, 0(sp)
    sw t1, 4(sp)
    mv a0, s1
    jal ra, fp16_to_fp32
    lw t0, 0(sp)
    lw t1, 4(sp)
    addi sp, sp, 8
    mv s1, a0 # s1: fp16 num1_img to fp32

    addi sp, sp, -8
    sw t0, 0(sp)
    sw t1, 4(sp)
    mv a0, s2
    jal ra, fp16_to_fp32
    lw t0, 0(sp)
    lw t1, 4(sp)
    addi sp, sp, 8
    mv s2, a0 # s2: fp16 num2_real to fp32

    addi sp, sp, -8
    sw t0, 0(sp)
    sw t1, 4(sp)
    mv a0, s3
    jal ra, fp16_to_fp32
    lw t0, 0(sp)
    lw t1, 4(sp)
    addi sp, sp, 8
    mv s3, a0 # s3: fp16 num2_img to fp32

    addi sp, sp, -8
    sw t0, 0(sp)
    sw t1, 4(sp)
    mv a0, s0
    mv a1, s2
    jal ra, mul_float32
    lw t0, 0(sp)
    lw t1, 4(sp)
    addi sp, sp, 8
    mv t2, a0

    addi sp, sp, -12
    sw t0, 0(sp)
    sw t1, 4(sp)
    sw t2, 8(sp)
    mv a0, s1
    mv a1, s3
    jal ra, mul_float32
    lw t0, 0(sp)
    lw t1, 4(sp)
    lw t2, 8(sp)
    addi sp, sp, 12
    # put the sub symbol into sign bit
    li s4, 0x80000000
    xor t3, a0, s4

    addi sp, sp, -16
    sw t0, 0(sp)
    sw t1, 4(sp)
    sw t2, 8(sp)
    sw t3, 12(sp)
    mv a0, t2
    mv a1, t3
    jal ra, add_float32
    lw t0, 0(sp)
    lw t1, 4(sp)
    lw t2, 8(sp)
    lw t3, 12(sp)
    addi sp, sp, 16
    mv t2, a0 # t2: real_part_fp16

    addi sp, sp, -12
    sw t0, 0(sp)
    sw t1, 4(sp)
    sw t2, 8(sp)
    mv a0, s0
    mv a1, s3
    jal ra, mul_float32
    lw t0, 0(sp)
    lw t1, 4(sp)
    lw t2, 8(sp)
    addi sp, sp, 12
    mv t3, a0

    addi sp, sp, -16
    sw t0, 0(sp)
    sw t1, 4(sp)
    sw t2, 8(sp)
    sw t3, 12(sp)
    mv a0, s1
    mv a1, s2
    jal ra, mul_float32
    lw t0, 0(sp)
    lw t1, 4(sp)
    lw t2, 8(sp)
    lw t3, 12(sp)
    addi sp, sp, 16

    addi sp, sp, -16
    sw t0, 0(sp)
    sw t1, 4(sp)
    sw t2, 8(sp)
    sw t3, 12(sp)
    mv a0, a0
    mv a1, t3
    jal ra, add_float32
    lw t0, 0(sp)
    lw t1, 4(sp)
    lw t2, 8(sp)
    lw t3, 12(sp)
    lw ra, 16(sp)
    addi sp, sp, 20
    mv t3, a0 # t3: imag_part_fp16

    li a7, 4
    la a0, output1
    ecall
    li a7, 2
    mv a0, t0
    ecall
    li a7, 4
    la a0, plus
    ecall
    li a7, 2
    mv a0, t1
    ecall
    li a7, 4
    la a0, img
    ecall
    li a7, 4
    la a0, output2
    ecall
    li a7, 2
    mv a0, t2
    ecall
    li a7, 4
    la a0, plus
    ecall
    li a7, 2
    mv a0, t3
    ecall
    li a7, 4
    la a0, img
    ecall
inference__epilogue:
    lw s0, 0(sp)
    lw s1, 4(sp)
    lw s2, 8(sp)
    lw s3, 12(sp)
    lw s4, 16(sp)
    addi sp, sp, 20
    ret
exit:
    li a7, 10
    ecall