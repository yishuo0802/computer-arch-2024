.data
    str1: "============Inference Start============\n"
    str2: "base (fp32): "
    test1: 13 2 4
    test2: 13 2 4

.text
mul_int32:
mul_int32__prologue:
    # a0 = a0 * a1
    #? optimize find the smaller one
    addi sp, sp, -8
    sw s0, 0(sp)
    sw s1, 4(sp)
    mv s0, a0
    mv s1, a1
mul_int32__body:
    li t0, 0 # init value
    li t1, 0 # loop index
mul_int32__loop_start:
    bge t1, s1, mul_int32__loop_end
    add t0, t0, s0
    addi t1, t1, 1
    j mul_int32__loop_start
mul_int32__loop_end:
mul_int32__epilogue:
    lw s0, 0(sp)
    lw s1, 4(sp)
    addi sp, sp, 8

    mv a0, t1
    ret

mul_float32:
    #a0 = a0 * a1
mul_float32__prologue:
    addi sp, sp, -8
    sw s0, 0(sp)
    sw s1, 4(sp)
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
    andi t4, s0, 0x7FFFFF
    ori t4, t4, 0x800000 # t4: mantissa of a0
    andi t5, s1, 0x7FFFFF
    ori t5, t5, 0x800000 # t5: mantissa of a1
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
    mv a0, t4
    mv a1, t5
    jal ra, mul_int32
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw t1, 8(sp)
    lw t2, 12(sp)
    lw t3, 16(sp)
    lw t4, 20(sp)
    lw t5, 24(sp)
    addi sp, sp, 28
    mv t4, a0 # t4: mantissa of result
# Normalize

bits_to_fp32: #TODO
    # a0: input uint32 w
    # t0: temp value for fp32
bits_to_fp32__prologue:
    addi sp, sp, -4
    sw s0, 0(sp)
bits_to_fp32__body:
    mv s0, a0
    mv t0, s0
    mv a0, t0
bits_to_fp32__epilogue:
    lw s0, 0(sp)
    addi sp, sp, 4
    ret

fp32_to_bits: #TODO
    # a0: input float f
    # t0: temp
fp32_to_bits__prologue:
    addi sp, sp, -4
    sw s0, 0(sp)
fp32_to_bits__body:
    mv s0, a0
    mv t0, s0
    mv a0, t0
fp32_to_bits__epilogue:
    lw s0, 0(sp)
    addi sp, sp, 4
    ret

fp16_to_fp32:
    # a0: input fp16_t h
fp16_to_fp32__prologue:
    addi sp, sp, -8
    sw s0, 0(sp)
    sw s1, 4(sp)
fp16_to_fp32__body:
    mv s0, a0 # w
    slli s0, s0, 16
    andi t0, s0, 0x80000000 # t0: sign
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
    jal ra, bits_to_fp32
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw t1, 8(sp)
    lw t2, 12(sp)
    lw t3, 16(sp)
    addi sp, sp, 20

    addi sp, sp, -20
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw t1, 8(sp)
    sw t2, 12(sp)
    sw t3, 16(sp)
    mv a0, a0
    mv a1, t2
    jal ra, mul_float32
    mv t3, a0
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw t1, 8(sp)
    lw t2, 12(sp)
    lw t3, 16(sp)
    addi sp, sp, 20

    li t4, 126 # t4: mask
    slli t4, t4, 23

    li t5, 0x3F000000 # t5: magic_bias
    srli t6, s0, 17 # t6: denormalized_value
    or t6, t6 , t4
    addi sp, sp, -32
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw t1, 8(sp)
    sw t2, 12(sp)
    sw t3, 16(sp)
    sw t4, 20(sp)
    sw t5, 24(sp)
    sw t6, 28(sp)
    mv a0, t6
    jal ra, bits_to_fp32
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw t1, 8(sp)
    lw t2, 12(sp)
    lw t3, 16(sp)
    lw t4, 20(sp)
    lw t5, 24(sp)
    lw t6, 28(sp)
    addi sp, sp, 32
    sub t6, a0, t5

    li s1, 1
    slli s1, s1, 27 # s1: denormalized_cutoff
    blt s0, s1, fp16_to_fp32__taken
    j fp16_to_fp32__nottaken
fp16_to_fp32__taken:
    addi sp, sp, -32
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw t1, 8(sp)
    sw t2, 12(sp)
    sw t3, 16(sp)
    sw t4, 20(sp)
    sw t5, 24(sp)
    sw t6, 28(sp)
    mv a0, t6
    jal ra, fp32_to_bits
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw t1, 8(sp)
    lw t2, 12(sp)
    lw t3, 16(sp)
    lw t4, 20(sp)
    lw t5, 24(sp)
    lw t6, 28(sp)
    addi sp, sp, 32
    j fp16_to_fp32__if_end
fp16_to_fp32__nottaken:
    addi sp, sp, -32
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw t1, 8(sp)
    sw t2, 12(sp)
    sw t3, 16(sp)
    sw t4, 20(sp)
    sw t5, 24(sp)
    sw t6, 28(sp)
    mv a0, t3
    jal ra, fp32_to_bits
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw t1, 8(sp)
    lw t2, 12(sp)
    lw t3, 16(sp)
    lw t4, 20(sp)
    lw t5, 24(sp)
    lw t6, 28(sp)
    addi sp, sp, 32
fp16_to_fp32__if_end:
    or a0, t0, a0 # a0: result
    addi sp, sp, -32
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw t1, 8(sp)
    sw t2, 12(sp)
    sw t3, 16(sp)
    sw t4, 20(sp)
    sw t5, 24(sp)
    sw t6, 28(sp)
    mv a0, a0
    jal ra, bits_to_fp32
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw t1, 8(sp)
    lw t2, 12(sp)
    lw t3, 16(sp)
    lw t4, 20(sp)
    lw t5, 24(sp)
    lw t6, 28(sp)
    addi sp, sp, 32
fp16_to_fp32__epilogue:
    lw s0, 0(sp)
    lw s1, 4(sp)
    addi sp, sp, 8
    ret

fp32_to_fp16:
    # a0: input float f
fp32_to_fp16__prologue:
    addi sp, sp, -12
    sw s0, 0(sp)
    sw s1, 4(sp)
    sw s2, 8(sp)
fp32_to_fp16__body:
    mv s0, a0
    li t0, 0x77800000 # t0: scale_to_inf
    li t1, 0x08800000 # t1: scale_to_zero
    and t2, s0, 0x7fffffff # t2: fabs(f)
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
    addi sp, sp, 16
    addi sp, sp, -16
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

    addi sp, sp, -16
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw t1, 8(sp)
    sw t2, 12(sp)
    mv a0, s0
    jal ra, fp32_to_bits
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw t1, 8(sp)
    lw t2, 12(sp)
    addi sp, sp, 16
    mv t3, a0 # t3: w
    add t4, t3, t3 # t4: shl1_w
    andi t5, t3, 0x80000000 # t5: sign
    andi t6, t4, 0xFF000000 # t6: bias
    li s1, 0x71000000
    bge t6, s1, fp32_to_fp16__bge_taken
    mv t6, s1
fp32_to_fp16__bge_taken:
    srai s1, t6, 1
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
    jal ra, bits_to_fp32
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw t1, 8(sp)
    lw t2, 12(sp)
    lw t3, 16(sp)
    lw t4, 20(sp)
    lw t5, 24(sp)
    lw t6, 28(sp)
    addi sp, sp, 32
    addi s1, a0, 0x07800000
    add t2, t2, s1 # t2: base
    addi sp, sp, -32
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw t1, 8(sp)
    sw t2, 12(sp)
    sw t3, 16(sp)
    sw t4, 20(sp)
    sw t5, 24(sp)
    sw t6, 28(sp)
    mv a0, t2
    jal ra, fp32_to_bits
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw t1, 8(sp)
    lw t2, 12(sp)
    lw t3, 16(sp)
    lw t4, 20(sp)
    lw t5, 24(sp)
    lw t6, 28(sp)
    addi sp, sp, 32
    mv t2, a0 # t2: bits
    srai t0, t2, 13
    andi t0, t0, 0x00007C00 # t0: exp_bits
    andi t1, t1, 0x00000FFF # t1: mantissa_bits
    add t0, t0, t1 # t0: nonsign
    srai s0, t5, 16
    li s1, 0xFF000000
    mv s2, zero
    bge s1, t4, fp32_to_fp16__bge_taken2
    or s0, s0, t0
    j fp32_to_fp16__bge_taken2_end
fp32_to_fp16__bge_taken2:
    ori s0, s0, 0x7E00
fp32_to_fp16__bge_taken2_end:
    mv a0, s0
fp32_to_fp16__epilogue:
    lw s0, 0(sp)
    lw s1, 4(sp)
    lw s2, 8(sp)
    addi sp, sp, 12
    ret

inference:
    li a7, ???
    la a0, str1
    ecall

main:
    li a0, 0x3FA00000 // a0: 1.25
    li a1, 5 // a1: 5
    addi sp, sp, -4
    sw ra, 0(sp)
    jal ra, inference

    li a0, 0xC0300000 // a0: -2.375
    li a1, 5 // a1: 5
    addi sp, sp, -4
    sw ra, 0(sp)
    jal ra, inference

    li a0, 0x200000 // a0: 1.25
    li a1, 5 // a1: 5
    addi sp, sp, -4
    sw ra, 0(sp)
    jal ra, inference

