; Standalone tick simulation. CIA row choice adapted from 1.3.0 keyboard scan.
; Square radius48/256 cell, conservative at corners; independent axis rejection
; gives wall sliding. Each queued logical tick performs its own <=6/256 step.
candidate_x=$58
candidate_y=$5a
box_x0=$5c
box_x1=$5d
box_y0=$5e
box_y1=$5f
keys=$60
move_x=$61
move_y=$62
auto_index=$63
auto_left=$64
auto_key=$66
key_row=$67
collision_ptr=$68
input_override=$6a ; $ff normal input; 0..15 deterministic monitor tests
init_simulation:
 lda #0
 sta auto_index
 sta auto_left
 sta auto_left+1
 lda #$ff
 sta input_override
 rts
simulation_tick:
 jsr read_input
input_sampled:
 lda keys
 and #4
 beq sim_not_left
 sec
 lda cam_angle
 sbc #2
 sta cam_angle
 lda cam_angle+1
 sbc #0
 and #1
 sta cam_angle+1
sim_not_left:
 lda keys
 and #8
 beq sim_not_right
 clc
 lda cam_angle
 adc #2
 sta cam_angle
 lda cam_angle+1
 adc #0
 and #1
 sta cam_angle+1
sim_not_right:
 lda keys
 and #3
 beq simulation_done
 cmp #3
 beq simulation_done
 ldy cam_angle
 lda cam_angle+1
 bne sim_direction_high
 lda movement_x,y
 sta move_x
 lda movement_y,y
 jmp sim_direction_done
sim_direction_high:
 lda movement_x+256,y
 sta move_x
 lda movement_y+256,y
sim_direction_done:
 sta move_y
 lda keys
 and #2
 beq sim_forward
 lda #0
 sec
 sbc move_x
 sta move_x
 lda #0
 sec
 sbc move_y
 sta move_y
sim_forward:
 ldx #0
 lda move_x
 bpl sim_dx_positive
 dex
sim_dx_positive:
 clc
 adc cam_x
 sta candidate_x
 txa
 adc cam_x+1
 sta candidate_x+1
 lda cam_y
 sta candidate_y
 lda cam_y+1
 sta candidate_y+1
 jsr collision_check
 bcs sim_x_blocked
 lda candidate_x
 sta cam_x
 lda candidate_x+1
 sta cam_x+1
sim_x_blocked:
 lda cam_x
 sta candidate_x
 lda cam_x+1
 sta candidate_x+1
 ldx #0
 lda move_y
 bpl sim_dy_positive
 dex
sim_dy_positive:
 clc
 adc cam_y
 sta candidate_y
 txa
 adc cam_y+1
 sta candidate_y+1
 jsr collision_check
 bcs simulation_done
 lda candidate_y
 sta cam_y
 lda candidate_y+1
 sta cam_y+1
simulation_done:
 rts

read_input:
 lda input_override
 cmp #$ff
 beq input_normal
 sta keys
 rts
input_normal:
.if AUTO_RUN != 0
 lda auto_left
 ora auto_left+1
 bne auto_count
 ldx auto_index
 lda auto_duration_lo,x
 sta auto_left
 lda auto_duration_hi,x
 sta auto_left+1
 lda auto_keys,x
 sta auto_key
 inc auto_index
 lda auto_index
 cmp #ROUTE_LENGTH
 bcc auto_count
 lda #0
 sta auto_index
auto_count:
 lda auto_left
 bne auto_low
 dec auto_left+1
auto_low:
 dec auto_left
 lda auto_key
 sta keys
 rts
.else
 ; Joystick port2 active-low directions, no fire action in v1.
 lda #0
 sta $dc02
 lda $dc00
 eor #$ff
 and #15
 sta keys
 lda #$ff
 sta $dc02
 ; Row1: W(bit1), A(bit2), S(bit5). Row2: D(bit2).
 lda #$fd
 sta $dc00
 lda $dc01
 sta key_row
 and #2
 bne input_not_w
 lda keys
 ora #1
 sta keys
input_not_w:
 lda key_row
 and #$20
 bne input_not_s
 lda keys
 ora #2
 sta keys
input_not_s:
 lda key_row
 and #4
 bne input_not_a
 lda keys
 ora #4
 sta keys
input_not_a:
 lda #$fb
 sta $dc00
 lda $dc01
 and #4
 bne input_not_d
 lda keys
 ora #8
 sta keys
input_not_d:
 lda #$ff
 sta $dc00
 rts
.endif

collision_check:
 sec
 lda candidate_x
 sbc #48
 lda candidate_x+1
 sbc #0
 cmp #32
 bcs collision_blocked
 sta box_x0
 clc
 lda candidate_x
 adc #48
 lda candidate_x+1
 adc #0
 cmp #32
 bcs collision_blocked
 sta box_x1
 sec
 lda candidate_y
 sbc #48
 lda candidate_y+1
 sbc #0
 cmp #32
 bcs collision_blocked
 sta box_y0
 clc
 lda candidate_y
 adc #48
 lda candidate_y+1
 adc #0
 cmp #32
 bcs collision_blocked
 sta box_y1
 lda box_y0
 jsr collision_row
 bcs collision_blocked
 lda box_y1
 jsr collision_row
 rts
collision_row:
 pha
 lsr
 lsr
 lsr
 clc
 adc #$3c
 sta collision_ptr+1
 pla
 asl
 asl
 asl
 asl
 asl
 sta collision_ptr
 ldy box_x0
 lda (collision_ptr),y
 bne collision_blocked
 ldy box_x1
 lda (collision_ptr),y
 bne collision_blocked
 clc
 rts
collision_blocked:
 sec
 rts
