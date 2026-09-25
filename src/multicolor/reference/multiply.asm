; M4 exact quarter-square multiplication. Identity:
; floor((a+b)^2/4)-floor((a-b)^2/4)=a*b, for integers a,b.
; 512-word table in two byte planes. No SMC, IRQ touches none of this state.
qs_factor=$6c
qs_carry=$6d
mul16x8_shift8:
 lda mul_a
 jsr product8
 lda mul_r+1
 sta qs_carry
 lda mul_a+1
 beq product_high_zero
 jsr product8
 clc
 lda mul_r
 adc qs_carry
 sta mul_r
 lda mul_r+1
 adc #0
 sta mul_r+1
 rts
product_high_zero:
 lda qs_carry
 sta mul_r
 lda #0
 sta mul_r+1
 rts
product8:
 sta qs_factor
 clc
 adc mul_b
 tax
 bcs product_sum_high
 lda quarter_lo,x
 sta mul_r
 lda quarter_hi,x
 sta mul_r+1
 jmp product_difference
product_sum_high:
 lda quarter_lo+256,x
 sta mul_r
 lda quarter_hi+256,x
 sta mul_r+1
product_difference:
 lda qs_factor
 sec
 sbc mul_b
 bcs product_positive
 eor #$ff
 clc
 adc #1
product_positive:
 tax
 sec
 lda mul_r
 sbc quarter_lo,x
 sta mul_r
 lda mul_r+1
 sbc quarter_hi,x
 sta mul_r+1
 rts
