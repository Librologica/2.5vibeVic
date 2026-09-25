INITIAL_X=1408
INITIAL_Y=1664
INITIAL_ANGLE=0
AUTO_RUN=1
ROUTE_LENGTH=16
MC_COLOR=11
MC_AUX=176
MC_BACKGROUND=104
; New native VIC-I backend. Copyright 2026 librologica.digital.
; PolyForm Noncommercial 1.0.0. Only documented 6502 instructions, no SMC.
drawbuf=$70
ptr_l=$71
ptr_r=$73
compose_tmp=$75
height_ptr=$76
frame_count=$78
ticks=$7a
standard=$7c
max_raster=$7d
strip_lo=$0200
strip_hi=$0220
depth_lo=$3a00
depth_hi=$3a20
ray_side=$3a40
ray_steps=$3a60
ray_mat=$3a80
ray_t_lo=$3aa0
ray_t_hi=$3ac0
ray_face=$3ae0
ray_along=$3b00
ray_top=$3b20
pixel_top=$3b40
edge_queue=$0380

*=$1201
 .word basic_end
 .word 10
 .byte $9e
 .text "8192"
 .byte 0
basic_end:
 .word 0
*=$2000
entry:
 sei
 cld
 lda #$7f
 sta $911e
 sta $912e
 lda $9114
 lda $9124
 lda #0
 sta $9002
 sta $900a
 sta $900b
 sta $900c
 sta $900d
 sta $900e
 sta ticks
 sta ticks+1
 sta frame_count
 sta frame_count+1
 sta drawbuf
 jsr detect_standard
 jsr init_video
 jsr init_camera
 jsr init_simulation
 lda #<irq
 sta $0314
 lda #>irq
 sta $0315
 ; KERNAL IRQ entry saves A/X/Y, custom handler restores them; no KERNAL tick.
 lda #$40
 sta $912b
 ldx standard
 lda timer_lo,x
 sta $9124
 lda timer_hi,x
 sta $9125
 lda #$c0
 sta $912e
 cli
main:
 sei
 jsr latch_pose
 cli
render_frame_begin:
 jsr raycast_all
geometry_done:
 jsr select_strips
strips_done:
 jsr compose
render_frame_end:
 nop
 ; Publish only during bottom border. Timer IRQ never modifies video pointers.
wait_bottom:
 lda $9004
 cmp #126
 bcc wait_bottom
 ldx drawbuf
 lda video_pointer,x
 sta $9005
 txa
 eor #1
 sta drawbuf
 inc frame_count
 bne presentation_done
 inc frame_count+1
presentation_done:
 jmp main

detect_standard:
 lda #0
 sta max_raster
detect_wait_zero:
 lda $9004
 bne detect_wait_zero
detect_wait_nonzero:
 lda $9004
 beq detect_wait_nonzero
detect_frame:
 lda $9004
 cmp max_raster
 bcc detect_lower
 sta max_raster
detect_lower:
 lda $9004
 bne detect_frame
 lda max_raster
 cmp #140
 lda #0
 bcc detect_ntsc
 lda #1
detect_ntsc:
 sta standard
 rts

init_video:
 ldx #0
init_clear:
 lda #0
.for block=0,block<6,block+=1
 sta $1000+block*256,x
 sta $1800+block*256,x
.endfor
 lda #$ff
 sta $1600,x
 sta $1700,x
 sta $1e00,x
 sta $1f00,x
 lda #MC_COLOR
 sta $9600,x
 sta $9700,x
 inx
 bne init_clear
 ldx #0
init_screen:
 txa
 sta $1600,x
 sta $1e00,x
 inx
 cpx #192
 bne init_screen
 ldx standard
 lda origin_x,x
 sta $9000
 lda origin_y,x
 sta $9001
 lda #24
 sta $9003
 lda #$dc
 sta $9005
 lda #MC_AUX
 sta $900e
 lda #MC_BACKGROUND
 sta $900f
 lda #$90
 sta $9002
 rts

irq:
 lda $9124
 inc ticks
 bne irq_tick
 inc ticks+1
irq_tick:
 jsr simulation_tick
irq_exit:
 pla
 tay
 pla
 tax
 pla
 rti

select_strips:
 ldx #0
select_next:
 ; depth Q8.8 >>4 -> 12-bit direct LUT index, midpoint depth quantization.
 lda depth_lo,x
 sta height_ptr
 lda depth_hi,x
 lsr
 ror height_ptr
 lsr
 ror height_ptr
 lsr
 ror height_ptr
 lsr
 ror height_ptr
 cmp #4
 bcc select_depth_in_range
 lda #$ff
 sta height_ptr
 lda #3
select_depth_in_range:
 ora #$7c
 sta height_ptr+1
 ldy #0
 lda (height_ptr),y
 sta ray_top,x
 ldy ray_side,x
 beq select_side_done
 clc
 adc #49
select_side_done:
 tay
 lda strip_address_lo,y
 sta strip_lo,x
 lda strip_address_hi,y
 sta strip_hi,x
 inx
 cpx #32
 bne select_next
 jmp prepare_edges
; NTSC 1022727 Hz / 50, PAL 1108405 Hz /50, subtract T1's two clocks.
timer_lo: .byte <20453,<22166
timer_hi: .byte >20453,>22166
origin_x: .byte 14,15
origin_y: .byte 51,49
video_pointer: .byte $dc,$fe

; Standalone Q8.8 512-direction grid DDA. No polygon code/buffers.
cam_x=$20
cam_y=$22
cam_angle=$24
pose_x=$26
pose_y=$28
pose_angle=$2a
ray_index=$2c
cell_x=$2d
cell_y=$2e
map_ptr=$30
delta_x=$32
delta_y=$34
side_x=$36
side_y=$38
hit_t=$3a
dir_x=$3c
dir_y=$3e
dir_sign=$40
steps=$41
hit_side=$42
hit_u=$43
hit_mat=$44
angle=$45
mul_a=$48
mul_b=$4a
mul_r=$4b
temp=$50
init_camera:
 lda #<INITIAL_X
 sta cam_x
 lda #>INITIAL_X
 sta cam_x+1
 lda #<INITIAL_Y
 sta cam_y
 lda #>INITIAL_Y
 sta cam_y+1
 lda #<INITIAL_ANGLE
 sta cam_angle
 lda #>INITIAL_ANGLE
 sta cam_angle+1
 rts
latch_pose:
 ldx #5
latch_pose_loop:
 lda cam_x,x
 sta pose_x,x
 dex
 bpl latch_pose_loop
 rts

raycast_all:
 lda #0
 sta ray_index
ray_next:
 ldx ray_index
 clc
 lda pose_angle
 adc ray_offset_lo,x
 sta angle
 lda pose_angle+1
 adc ray_offset_hi,x
 and #1
 sta angle+1
 tay
 jsr load_direction
 lda pose_x+1
 sta cell_x
 lda pose_y+1
 sta cell_y
 ; map pointer = $3c00 + y*32 + x, origin validated.
 lda cell_y
 lsr
 lsr
 lsr
 clc
 adc #$3c
 sta map_ptr+1
 lda cell_y
 asl
 asl
 asl
 asl
 asl
 ora cell_x
 sta map_ptr
 lda delta_x
 sta mul_a
 lda delta_x+1
 sta mul_a+1
 lda pose_x
 sta mul_b
 jsr mul16x8_shift8
 lda mul_r
 sta side_x
 lda mul_r+1
 sta side_x+1
 lda dir_sign
 and #1
 bne ray_x_negative
 sec
 lda delta_x
 sbc side_x
 sta side_x
 lda delta_x+1
 sbc side_x+1
 sta side_x+1
ray_x_negative:
 lda dir_x
 ora dir_x+1
 bne ray_x_nonparallel
 lda #$ff
 sta side_x
 sta side_x+1
ray_x_nonparallel:
 lda delta_y
 sta mul_a
 lda delta_y+1
 sta mul_a+1
 lda pose_y
 sta mul_b
 jsr mul16x8_shift8
 lda mul_r
 sta side_y
 lda mul_r+1
 sta side_y+1
 lda dir_sign
 and #2
 bne ray_y_negative
 sec
 lda delta_y
 sbc side_y
 sta side_y
 lda delta_y+1
 sbc side_y+1
 sta side_y+1
ray_y_negative:
 lda dir_y
 ora dir_y+1
 bne ray_y_nonparallel
 lda #$ff
 sta side_y
 sta side_y+1
ray_y_nonparallel:
 lda #0
 sta steps
dda_begin:
 inc steps
 lda steps
 cmp #65
 bcs ray_miss
 lda side_y+1
 cmp side_x+1
 bcc dda_y
 bne dda_x
 lda side_y
 cmp side_x
 bcc dda_y
 ; Exact ties enter X first, then Y if X cell is empty.
dda_x:
 lda #0
 sta hit_side
 lda side_x
 sta hit_t
 lda side_x+1
 sta hit_t+1
 lda dir_sign
 and #1
 bne dda_x_neg
 inc cell_x
 inc map_ptr
 bne dda_x_address
 inc map_ptr+1
 jmp dda_x_address
dda_x_neg:
 dec cell_x
 lda map_ptr
 bne dda_x_dec
 dec map_ptr+1
dda_x_dec:
 dec map_ptr
dda_x_address:
 lda cell_x
 cmp #32
 bcs ray_miss
 ldy #0
 lda (map_ptr),y
 bne ray_hit
 clc
 lda side_x
 adc delta_x
 sta side_x
 lda side_x+1
 adc delta_x+1
 sta side_x+1
 bcc dda_begin
 lda #$ff
 sta side_x
 sta side_x+1
 jmp dda_begin
dda_y:
 lda #1
 sta hit_side
 lda side_y
 sta hit_t
 lda side_y+1
 sta hit_t+1
 lda dir_sign
 and #2
 bne dda_y_neg
 inc cell_y
 clc
 lda map_ptr
 adc #32
 sta map_ptr
 bcc dda_y_address
 inc map_ptr+1
 jmp dda_y_address
dda_y_neg:
 dec cell_y
 sec
 lda map_ptr
 sbc #32
 sta map_ptr
 bcs dda_y_address
 dec map_ptr+1
dda_y_address:
 lda cell_y
 cmp #32
 bcs ray_miss
 ldy #0
 lda (map_ptr),y
 bne ray_hit
 clc
 lda side_y
 adc delta_y
 sta side_y
 lda side_y+1
 adc delta_y+1
 sta side_y+1
 bcc dda_begin
 lda #$ff
 sta side_y
 sta side_y+1
 jmp dda_begin
ray_miss:
 lda #0
 sta hit_mat
 lda #$ff
 sta hit_t
 sta hit_t+1
 sta mul_r
 sta mul_r+1
 jmp ray_store
ray_hit:
 sta hit_mat
 ldx ray_index
 lda ray_cos_axis,x
 beq depth_multiply
 lda hit_t
 sta mul_r
 lda hit_t+1
 sta mul_r+1
 jmp ray_store
depth_multiply:
 lda hit_t
 sta mul_a
 lda hit_t+1
 sta mul_a+1
 lda ray_cos,x
 sta mul_b
 jsr mul16x8_shift8
ray_store:
 ldx ray_index
 lda hit_side
 bne store_face_y
 lda cell_y
 sta ray_along,x
 lda dir_sign
 and #1
 sta temp
 lda cell_x
 jmp store_face_key
store_face_y:
 lda cell_x
 sta ray_along,x
 lda dir_sign
 lsr
 and #1
 ora #2
 sta temp
 lda cell_y
store_face_key:
 asl
 asl
 ora temp
 sta ray_face,x
 lda hit_t
 sta ray_t_lo,x
 lda hit_t+1
 sta ray_t_hi,x
 lda mul_r
 sta depth_lo,x
 lda mul_r+1
 sta depth_hi,x
 lda hit_mat
 sta ray_mat,x
 lda hit_side
 sta ray_side,x
 lda steps
 sta ray_steps,x
 inc ray_index
 lda ray_index
 cmp #32
 bne ray_next
raycast_done:
 rts

; Exact floor(unsigned16 * unsigned8 /256). Decimal mode is clear.
; Fixed 8 iterations; carry represents the 17th bit before right shift.
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

load_direction:
 ldy angle
 lda angle+1
 bne direction_high
 lda direction_0+0,y
 sta delta_x
 lda direction_1+0,y
 sta delta_x+1
 lda direction_2+0,y
 sta delta_y
 lda direction_3+0,y
 sta delta_y+1
 lda direction_4+0,y
 sta dir_sign
 lda delta_x+1
 eor #$ff
 sta dir_x
 lda delta_y+1
 eor #$ff
 sta dir_y
 lda #0
 sta dir_x+1
 sta dir_y+1
 rts
direction_high:
 lda direction_0+256,y
 sta delta_x
 lda direction_1+256,y
 sta delta_x+1
 lda direction_2+256,y
 sta delta_y
 lda direction_3+256,y
 sta delta_y+1
 lda direction_4+256,y
 sta dir_sign
 lda delta_x+1
 eor #$ff
 sta dir_x
 lda delta_y+1
 eor #$ff
 sta dir_y
 lda #0
 sta dir_x+1
 sta dir_y+1
 rts
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
 lda #0
 sta $9123
 lda $9113
 and #$e3
 sta $9113
 lda $9111
 eor #$ff
 lsr
 lsr
 and #7
 sta keys
 lda #$7f
 sta $9122
 lda #$ff
 sta $9120
 lda $9120
 bmi input_no_joy_right
 lda keys
 ora #8
 sta keys
input_no_joy_right:
 lda #$ff
 sta $9122
 lda #$fd
 sta $9120
 lda $9121
 and #2
 bne input_not_w
 lda keys
 ora #1
 sta keys
input_not_w:
 lda #$df
 sta $9120
 lda $9121
 and #2
 bne input_not_s
 lda keys
 ora #2
 sta keys
input_not_s:
 lda #$fb
 sta $9120
 lda $9121
 sta key_row
 and #2
 bne input_not_a
 lda keys
 ora #4
 sta keys
input_not_a:
 lda key_row
 and #4
 bne input_not_d
 lda keys
 ora #8
 sta keys
input_not_d:
 lda #$ff
 sta $9120
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
compose:
 lda drawbuf
 bne compose_b
compose_a:
 ldx #0
compose_a_col:
 txa
 lsr
 lsr
 tay
 lda strip_lo,y
 sta ptr_l
 lda strip_hi,y
 sta ptr_l+1
 iny
 lda strip_lo,y
 sta ptr_r
 lda strip_hi,y
 sta ptr_r+1
 ldy #0
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1000,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1001,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1002,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1003,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1004,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1005,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1006,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1007,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1080,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1081,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1082,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1083,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1084,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1085,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1086,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1087,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1100,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1101,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1102,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1103,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1104,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1105,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1106,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1107,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1180,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1181,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1182,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1183,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1184,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1185,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1186,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1187,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1200,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1201,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1202,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1203,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1204,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1205,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1206,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1207,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1280,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1281,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1282,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1283,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1284,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1285,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1286,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1287,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1300,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1301,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1302,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1303,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1304,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1305,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1306,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1307,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1380,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1381,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1382,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1383,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1384,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1385,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1386,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1387,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1400,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1401,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1402,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1403,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1404,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1405,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1406,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1407,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1480,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1481,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1482,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1483,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1484,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1485,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1486,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1487,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1500,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1501,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1502,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1503,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1504,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1505,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1506,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1507,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1580,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1581,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1582,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1583,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1584,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1585,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1586,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1587,x
 txa
 clc
 adc #8
 tax
 bpl compose_a_col
 jmp refine_edges
compose_b:
 ldx #0
compose_b_col:
 txa
 lsr
 lsr
 tay
 lda strip_lo,y
 sta ptr_l
 lda strip_hi,y
 sta ptr_l+1
 iny
 lda strip_lo,y
 sta ptr_r
 lda strip_hi,y
 sta ptr_r+1
 ldy #0
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1800,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1801,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1802,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1803,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1804,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1805,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1806,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1807,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1880,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1881,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1882,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1883,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1884,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1885,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1886,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1887,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1900,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1901,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1902,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1903,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1904,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1905,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1906,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1907,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1980,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1981,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1982,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1983,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1984,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1985,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1986,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1987,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1a00,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1a01,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1a02,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1a03,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1a04,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1a05,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1a06,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1a07,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1a80,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1a81,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1a82,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1a83,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1a84,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1a85,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1a86,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1a87,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1b00,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1b01,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1b02,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1b03,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1b04,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1b05,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1b06,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1b07,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1b80,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1b81,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1b82,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1b83,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1b84,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1b85,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1b86,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1b87,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1c00,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1c01,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1c02,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1c03,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1c04,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1c05,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1c06,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1c07,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1c80,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1c81,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1c82,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1c83,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1c84,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1c85,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1c86,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1c87,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1d00,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1d01,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1d02,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1d03,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1d04,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1d05,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1d06,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1d07,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1d80,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1d81,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1d82,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1d83,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1d84,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1d85,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1d86,x
 iny
 lda (ptr_l),y
 and #$f0
 sta compose_tmp
 lda (ptr_r),y
 and #$0f
 ora compose_tmp
 sta $1d87,x
 txa
 clc
 adc #8
 tax
 bpl compose_b_col
 jmp refine_edges
; Sparse 2-bit multicolor refinement, 64 logical columns, 32 ray centres.
; Main-thread-only state; IRQ scratch is separate.
; No SMC, no extra rays, unchanged solid/sky/floor for all unchanged rows.
edge_t=$80
edge_x=$81
edge_old=$82
edge_new=$83
edge_end=$84
edge_y=$85
edge_mask=$86
edge_notmask=$87
edge_ptr=$88
edge_col=$8a
edge_base=$8b
edge_wall=$8c
edge_direction=$8d
edge_count=$8e
edge_cursor=$8f
edge_delta=$90
edge_pair_base=$91
edge_right=$92

prepare_edges:
 lda #0
 sta edge_count
 ldx #0
 ldy #0
edge_initialize:
 lda ray_top,x
 sta pixel_top,y
 sta pixel_top+1,y
 iny
 iny
 inx
 cpx #32
 bne edge_initialize
 ldx #0
edge_pair:
 lda ray_mat,x
 beq edge_pair_next
 lda ray_mat+1,x
 beq edge_pair_next
 lda ray_face,x
 cmp ray_face+1,x
 bne edge_pair_next
 sec
 lda ray_along+1,x
 sbc ray_along,x
 clc
 adc #1
 cmp #3
 bcs edge_pair_next
 lda ray_top,x
 sta edge_t
 lda ray_top+1,x
 sta edge_right
 sec
 sbc edge_t
 beq edge_pair_next
 clc
 adc #48
 tay
 sty edge_delta
 txa
 pha
 asl
 tax
 stx edge_pair_base
 clc
 lda edge_lerp_1,y
 adc edge_t
 sta pixel_top+1,x
 cmp edge_t
 beq edge_no_queue_1
 lda #1
 jsr edge_enqueue
edge_no_queue_1:
 ldy edge_delta
 clc
 lda edge_lerp_3,y
 adc edge_t
 sta pixel_top+2,x
 cmp edge_right
 beq edge_no_queue_3
 lda #2
 jsr edge_enqueue
edge_no_queue_3:
 pla
 tax
edge_pair_next:
 inx
 cpx #31
 bne edge_pair
 rts

edge_enqueue:
 clc
 adc edge_pair_base
 ldy edge_count
 sta edge_queue,y
 inc edge_count
 rts

refine_edges:
 lda edge_count
 bne edge_any
 rts
edge_any:
 lda drawbuf
 asl
 asl
 asl
 ora #$10
 sta edge_base
 lda #0
 sta edge_cursor
edge_pixel:
 ldy edge_cursor
 ldx edge_queue,y
 stx edge_x
 txa
 lsr
 tay
 lda ray_top,y
 sta edge_old
 lda ray_side,y
 sta edge_wall
 lda pixel_top,x
 sta edge_new
 cmp edge_old
 beq edge_pixel_next
 lda edge_masks,x
 sta edge_mask
 eor #$ff
 sta edge_notmask
 lda edge_columns,x
 sta edge_col
 lda edge_new
 cmp edge_old
 bcc edge_expand
 ; Shrink wall: [old,new) -> sky at top, floor at mirrored bottom.
 lda #0
 sta edge_direction
 lda edge_new
 sta edge_end
 lda edge_old
 jmp edge_rows
edge_expand:
 lda #1
 sta edge_direction
 lda edge_old
 sta edge_end
 lda edge_new
edge_rows:
 sta edge_y
edge_row_loop:
 ldy edge_y
 jsr edge_address
 lda edge_direction
 beq edge_top_sky
 jsr edge_wall_pattern
 jmp edge_top_write
edge_top_sky:
 lda #0
edge_top_write:
 jsr edge_write
 lda #95
 sec
 sbc edge_y
 tay
 jsr edge_address
 lda edge_direction
 bne edge_bottom_wall
 lda edge_floor,y
 jmp edge_bottom_write
edge_bottom_wall:
 jsr edge_wall_pattern
edge_bottom_write:
 jsr edge_write
 inc edge_y
 lda edge_y
 cmp edge_end
 bne edge_row_loop
 ldx edge_x
edge_pixel_next:
 inc edge_cursor
 lda edge_cursor
 cmp edge_count
 bne edge_pixel
 rts

edge_address:
 lda edge_row_lo,y
 clc
 adc edge_col
 sta edge_ptr
 lda edge_row_hi,y
 ora edge_base
 sta edge_ptr+1
 rts
edge_wall_pattern:
 lda edge_wall
 bne edge_shaded
 lda #$ff
 rts
edge_shaded:
 lda edge_shade,y
 rts
edge_write:
 and edge_mask
 sta compose_tmp
 ldy #0
 lda (edge_ptr),y
 and edge_notmask
 ora compose_tmp
 sta (edge_ptr),y
 rts

code_end:
edge_lerp_1:
 .byte $f4,$f4,$f5,$f5,$f5,$f5,$f6,$f6,$f6,$f6,$f7,$f7,$f7,$f7,$f8,$f8
 .byte $f8,$f8,$f9,$f9,$f9,$f9,$fa,$fa,$fa,$fa,$fb,$fb,$fb,$fb,$fc,$fc
 .byte $fc,$fc,$fd,$fd,$fd,$fd,$fe,$fe,$fe,$fe,$ff,$ff,$ff,$ff,$00,$00
 .byte $00,$00,$01,$01,$01,$01,$02,$02,$02,$02,$03,$03,$03,$03,$04,$04
 .byte $04,$04,$05,$05,$05,$05,$06,$06,$06,$06,$07,$07,$07,$07,$08,$08
 .byte $08,$08,$09,$09,$09,$09,$0a,$0a,$0a,$0a,$0b,$0b,$0b,$0b,$0c,$0c
 .byte $0c
edge_lerp_3:
 .byte $dc,$dd,$de,$de,$df,$e0,$e1,$e1,$e2,$e3,$e4,$e4,$e5,$e6,$e7,$e7
 .byte $e8,$e9,$ea,$ea,$eb,$ec,$ed,$ed,$ee,$ef,$f0,$f0,$f1,$f2,$f3,$f3
 .byte $f4,$f5,$f6,$f6,$f7,$f8,$f9,$f9,$fa,$fb,$fc,$fc,$fd,$fe,$ff,$ff
 .byte $00,$01,$02,$02,$03,$04,$05,$05,$06,$07,$08,$08,$09,$0a,$0b,$0b
 .byte $0c,$0d,$0e,$0e,$0f,$10,$11,$11,$12,$13,$14,$14,$15,$16,$17,$17
 .byte $18,$19,$1a,$1a,$1b,$1c,$1d,$1d,$1e,$1f,$20,$20,$21,$22,$23,$23
 .byte $24
edge_row_lo:
 .byte $00,$01,$02,$03,$04,$05,$06,$07,$80,$81,$82,$83,$84,$85,$86,$87
 .byte $00,$01,$02,$03,$04,$05,$06,$07,$80,$81,$82,$83,$84,$85,$86,$87
 .byte $00,$01,$02,$03,$04,$05,$06,$07,$80,$81,$82,$83,$84,$85,$86,$87
 .byte $00,$01,$02,$03,$04,$05,$06,$07,$80,$81,$82,$83,$84,$85,$86,$87
 .byte $00,$01,$02,$03,$04,$05,$06,$07,$80,$81,$82,$83,$84,$85,$86,$87
 .byte $00,$01,$02,$03,$04,$05,$06,$07,$80,$81,$82,$83,$84,$85,$86,$87
edge_row_hi:
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
 .byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
 .byte $04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04
 .byte $05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05
edge_masks:
 .byte $c0,$30,$0c,$03,$c0,$30,$0c,$03,$c0,$30,$0c,$03,$c0,$30,$0c,$03
 .byte $c0,$30,$0c,$03,$c0,$30,$0c,$03,$c0,$30,$0c,$03,$c0,$30,$0c,$03
 .byte $c0,$30,$0c,$03,$c0,$30,$0c,$03,$c0,$30,$0c,$03,$c0,$30,$0c,$03
 .byte $c0,$30,$0c,$03,$c0,$30,$0c,$03,$c0,$30,$0c,$03,$c0,$30,$0c,$03
edge_columns:
 .byte $00,$00,$00,$00,$08,$08,$08,$08,$10,$10,$10,$10,$18,$18,$18,$18
 .byte $20,$20,$20,$20,$28,$28,$28,$28,$30,$30,$30,$30,$38,$38,$38,$38
 .byte $40,$40,$40,$40,$48,$48,$48,$48,$50,$50,$50,$50,$58,$58,$58,$58
 .byte $60,$60,$60,$60,$68,$68,$68,$68,$70,$70,$70,$70,$78,$78,$78,$78
edge_floor:
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
edge_shade:
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
low_end:
 .cerror * > $3a00, "Code collides with descriptors"
*=$3c00
 .binary "map.bin"
*=$4000
scaled_strips:
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$11
 .byte $00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$44,$11
 .byte $00,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$11,$44,$11
 .byte $00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff
 .byte $ff,$ff,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff
 .byte $ff,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $00,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$11
 .byte $00,$00,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$44,$11
 .byte $00,$00,$00,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$11,$44,$11
 .byte $00,$00,$00,$00,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$aa,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$aa,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$aa,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$aa,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$aa,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$aa,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$aa,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$aa,$aa,$aa
 .byte $aa,$aa,$aa,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$aa,$aa
 .byte $aa,$aa,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$aa
 .byte $aa,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
 .byte $44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11,$44,$11
strip_address_lo:
 .byte $00,$60,$c0,$20,$80,$e0,$40,$a0,$00,$60,$c0,$20,$80,$e0,$40,$a0
 .byte $00,$60,$c0,$20,$80,$e0,$40,$a0,$00,$60,$c0,$20,$80,$e0,$40,$a0
 .byte $00,$60,$c0,$20,$80,$e0,$40,$a0,$00,$60,$c0,$20,$80,$e0,$40,$a0
 .byte $00,$60,$c0,$20,$80,$e0,$40,$a0,$00,$60,$c0,$20,$80,$e0,$40,$a0
 .byte $00,$60,$c0,$20,$80,$e0,$40,$a0,$00,$60,$c0,$20,$80,$e0,$40,$a0
 .byte $00,$60,$c0,$20,$80,$e0,$40,$a0,$00,$60,$c0,$20,$80,$e0,$40,$a0
 .byte $00,$60
strip_address_hi:
 .byte $40,$40,$40,$41,$41,$41,$42,$42,$43,$43,$43,$44,$44,$44,$45,$45
 .byte $46,$46,$46,$47,$47,$47,$48,$48,$49,$49,$49,$4a,$4a,$4a,$4b,$4b
 .byte $4c,$4c,$4c,$4d,$4d,$4d,$4e,$4e,$4f,$4f,$4f,$50,$50,$50,$51,$51
 .byte $52,$52,$52,$53,$53,$53,$54,$54,$55,$55,$55,$56,$56,$56,$57,$57
 .byte $58,$58,$58,$59,$59,$59,$5a,$5a,$5b,$5b,$5b,$5c,$5c,$5c,$5d,$5d
 .byte $5e,$5e,$5e,$5f,$5f,$5f,$60,$60,$61,$61,$61,$62,$62,$62,$63,$63
 .byte $64,$64
ray_offset_lo:
 .byte $d6,$d9,$db,$dd,$e0,$e2,$e5,$e8,$ea,$ed,$f0,$f3,$f6,$f9,$fc,$ff
 .byte $01,$04,$07,$0a,$0d,$10,$13,$16,$18,$1b,$1e,$20,$23,$25,$27,$2a
ray_offset_hi:
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
ray_cos:
 .byte $df,$e3,$e6,$e9,$ed,$ef,$f2,$f5,$f7,$f9,$fb,$fd,$fe,$ff,$00,$00
 .byte $00,$00,$ff,$fe,$fd,$fb,$f9,$f7,$f5,$f2,$ef,$ed,$e9,$e6,$e3,$df
ray_cos_axis:
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$01
 .byte $01,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
movement_x:
 .byte $00,$00,$00,$00,$00,$00,$00,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
 .byte $02,$02,$02,$02,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
 .byte $03,$03,$03,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04
 .byte $04,$04,$04,$04,$04,$04,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05
 .byte $05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$06
 .byte $06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06
 .byte $06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06
 .byte $06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06
 .byte $06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06
 .byte $06,$06,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05
 .byte $05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$04,$04,$04,$04,$04
 .byte $04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$03,$03
 .byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$02,$02,$02
 .byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe
 .byte $fe,$fe,$fe,$fe,$fd,$fd,$fd,$fd,$fd,$fd,$fd,$fd,$fd,$fd,$fd,$fd
 .byte $fd,$fd,$fd,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc
 .byte $fc,$fc,$fc,$fc,$fc,$fc,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb
 .byte $fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fa
 .byte $fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa
 .byte $fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa
 .byte $fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa
 .byte $fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa
 .byte $fa,$fa,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb
 .byte $fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fc,$fc,$fc,$fc,$fc
 .byte $fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fd,$fd
 .byte $fd,$fd,$fd,$fd,$fd,$fd,$fd,$fd,$fd,$fd,$fd,$fd,$fd,$fe,$fe,$fe
 .byte $fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00
movement_y:
 .byte $06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06
 .byte $06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06
 .byte $06,$06,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05
 .byte $05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$04,$04,$04,$04,$04
 .byte $04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$03,$03
 .byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$02,$02,$02
 .byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe
 .byte $fe,$fe,$fe,$fe,$fd,$fd,$fd,$fd,$fd,$fd,$fd,$fd,$fd,$fd,$fd,$fd
 .byte $fd,$fd,$fd,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc
 .byte $fc,$fc,$fc,$fc,$fc,$fc,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb
 .byte $fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fa
 .byte $fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa
 .byte $fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa
 .byte $fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa
 .byte $fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa
 .byte $fa,$fa,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb
 .byte $fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fc,$fc,$fc,$fc,$fc
 .byte $fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fd,$fd
 .byte $fd,$fd,$fd,$fd,$fd,$fd,$fd,$fd,$fd,$fd,$fd,$fd,$fd,$fe,$fe,$fe
 .byte $fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$ff,$ff,$ff,$ff
 .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
 .byte $02,$02,$02,$02,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
 .byte $03,$03,$03,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04
 .byte $04,$04,$04,$04,$04,$04,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05
 .byte $05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$06
 .byte $06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06
 .byte $06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06
auto_keys:
 .byte $01,$09,$01,$09,$01,$09,$01,$09,$01,$09,$01,$09,$01,$09,$01,$09
auto_duration_lo:
 .byte $20,$40,$00,$40,$20,$40,$00,$40,$56,$40,$56,$40,$56,$40,$56,$40
auto_duration_hi:
 .byte $03,$00,$03,$00,$03,$00,$03,$00,$01,$00,$01,$00,$01,$00,$01,$00
 .align 256
quarter_lo:
 .byte $00,$00,$01,$02,$04,$06,$09,$0c,$10,$14,$19,$1e,$24,$2a,$31,$38
 .byte $40,$48,$51,$5a,$64,$6e,$79,$84,$90,$9c,$a9,$b6,$c4,$d2,$e1,$f0
 .byte $00,$10,$21,$32,$44,$56,$69,$7c,$90,$a4,$b9,$ce,$e4,$fa,$11,$28
 .byte $40,$58,$71,$8a,$a4,$be,$d9,$f4,$10,$2c,$49,$66,$84,$a2,$c1,$e0
 .byte $00,$20,$41,$62,$84,$a6,$c9,$ec,$10,$34,$59,$7e,$a4,$ca,$f1,$18
 .byte $40,$68,$91,$ba,$e4,$0e,$39,$64,$90,$bc,$e9,$16,$44,$72,$a1,$d0
 .byte $00,$30,$61,$92,$c4,$f6,$29,$5c,$90,$c4,$f9,$2e,$64,$9a,$d1,$08
 .byte $40,$78,$b1,$ea,$24,$5e,$99,$d4,$10,$4c,$89,$c6,$04,$42,$81,$c0
 .byte $00,$40,$81,$c2,$04,$46,$89,$cc,$10,$54,$99,$de,$24,$6a,$b1,$f8
 .byte $40,$88,$d1,$1a,$64,$ae,$f9,$44,$90,$dc,$29,$76,$c4,$12,$61,$b0
 .byte $00,$50,$a1,$f2,$44,$96,$e9,$3c,$90,$e4,$39,$8e,$e4,$3a,$91,$e8
 .byte $40,$98,$f1,$4a,$a4,$fe,$59,$b4,$10,$6c,$c9,$26,$84,$e2,$41,$a0
 .byte $00,$60,$c1,$22,$84,$e6,$49,$ac,$10,$74,$d9,$3e,$a4,$0a,$71,$d8
 .byte $40,$a8,$11,$7a,$e4,$4e,$b9,$24,$90,$fc,$69,$d6,$44,$b2,$21,$90
 .byte $00,$70,$e1,$52,$c4,$36,$a9,$1c,$90,$04,$79,$ee,$64,$da,$51,$c8
 .byte $40,$b8,$31,$aa,$24,$9e,$19,$94,$10,$8c,$09,$86,$04,$82,$01,$80
 .byte $00,$80,$01,$82,$04,$86,$09,$8c,$10,$94,$19,$9e,$24,$aa,$31,$b8
 .byte $40,$c8,$51,$da,$64,$ee,$79,$04,$90,$1c,$a9,$36,$c4,$52,$e1,$70
 .byte $00,$90,$21,$b2,$44,$d6,$69,$fc,$90,$24,$b9,$4e,$e4,$7a,$11,$a8
 .byte $40,$d8,$71,$0a,$a4,$3e,$d9,$74,$10,$ac,$49,$e6,$84,$22,$c1,$60
 .byte $00,$a0,$41,$e2,$84,$26,$c9,$6c,$10,$b4,$59,$fe,$a4,$4a,$f1,$98
 .byte $40,$e8,$91,$3a,$e4,$8e,$39,$e4,$90,$3c,$e9,$96,$44,$f2,$a1,$50
 .byte $00,$b0,$61,$12,$c4,$76,$29,$dc,$90,$44,$f9,$ae,$64,$1a,$d1,$88
 .byte $40,$f8,$b1,$6a,$24,$de,$99,$54,$10,$cc,$89,$46,$04,$c2,$81,$40
 .byte $00,$c0,$81,$42,$04,$c6,$89,$4c,$10,$d4,$99,$5e,$24,$ea,$b1,$78
 .byte $40,$08,$d1,$9a,$64,$2e,$f9,$c4,$90,$5c,$29,$f6,$c4,$92,$61,$30
 .byte $00,$d0,$a1,$72,$44,$16,$e9,$bc,$90,$64,$39,$0e,$e4,$ba,$91,$68
 .byte $40,$18,$f1,$ca,$a4,$7e,$59,$34,$10,$ec,$c9,$a6,$84,$62,$41,$20
 .byte $00,$e0,$c1,$a2,$84,$66,$49,$2c,$10,$f4,$d9,$be,$a4,$8a,$71,$58
 .byte $40,$28,$11,$fa,$e4,$ce,$b9,$a4,$90,$7c,$69,$56,$44,$32,$21,$10
 .byte $00,$f0,$e1,$d2,$c4,$b6,$a9,$9c,$90,$84,$79,$6e,$64,$5a,$51,$48
 .byte $40,$38,$31,$2a,$24,$1e,$19,$14,$10,$0c,$09,$06,$04,$02,$01,$00
quarter_hi:
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$02,$02
 .byte $02,$02,$02,$02,$02,$02,$02,$02,$03,$03,$03,$03,$03,$03,$03,$03
 .byte $04,$04,$04,$04,$04,$04,$04,$04,$05,$05,$05,$05,$05,$05,$05,$06
 .byte $06,$06,$06,$06,$06,$07,$07,$07,$07,$07,$07,$08,$08,$08,$08,$08
 .byte $09,$09,$09,$09,$09,$09,$0a,$0a,$0a,$0a,$0a,$0b,$0b,$0b,$0b,$0c
 .byte $0c,$0c,$0c,$0c,$0d,$0d,$0d,$0d,$0e,$0e,$0e,$0e,$0f,$0f,$0f,$0f
 .byte $10,$10,$10,$10,$11,$11,$11,$11,$12,$12,$12,$12,$13,$13,$13,$13
 .byte $14,$14,$14,$15,$15,$15,$15,$16,$16,$16,$17,$17,$17,$18,$18,$18
 .byte $19,$19,$19,$19,$1a,$1a,$1a,$1b,$1b,$1b,$1c,$1c,$1c,$1d,$1d,$1d
 .byte $1e,$1e,$1e,$1f,$1f,$1f,$20,$20,$21,$21,$21,$22,$22,$22,$23,$23
 .byte $24,$24,$24,$25,$25,$25,$26,$26,$27,$27,$27,$28,$28,$29,$29,$29
 .byte $2a,$2a,$2b,$2b,$2b,$2c,$2c,$2d,$2d,$2d,$2e,$2e,$2f,$2f,$30,$30
 .byte $31,$31,$31,$32,$32,$33,$33,$34,$34,$35,$35,$35,$36,$36,$37,$37
 .byte $38,$38,$39,$39,$3a,$3a,$3b,$3b,$3c,$3c,$3d,$3d,$3e,$3e,$3f,$3f
 .byte $40,$40,$41,$41,$42,$42,$43,$43,$44,$44,$45,$45,$46,$46,$47,$47
 .byte $48,$48,$49,$49,$4a,$4a,$4b,$4c,$4c,$4d,$4d,$4e,$4e,$4f,$4f,$50
 .byte $51,$51,$52,$52,$53,$53,$54,$54,$55,$56,$56,$57,$57,$58,$59,$59
 .byte $5a,$5a,$5b,$5c,$5c,$5d,$5d,$5e,$5f,$5f,$60,$60,$61,$62,$62,$63
 .byte $64,$64,$65,$65,$66,$67,$67,$68,$69,$69,$6a,$6a,$6b,$6c,$6c,$6d
 .byte $6e,$6e,$6f,$70,$70,$71,$72,$72,$73,$74,$74,$75,$76,$76,$77,$78
 .byte $79,$79,$7a,$7b,$7b,$7c,$7d,$7d,$7e,$7f,$7f,$80,$81,$82,$82,$83
 .byte $84,$84,$85,$86,$87,$87,$88,$89,$8a,$8a,$8b,$8c,$8d,$8d,$8e,$8f
 .byte $90,$90,$91,$92,$93,$93,$94,$95,$96,$96,$97,$98,$99,$99,$9a,$9b
 .byte $9c,$9d,$9d,$9e,$9f,$a0,$a0,$a1,$a2,$a3,$a4,$a4,$a5,$a6,$a7,$a8
 .byte $a9,$a9,$aa,$ab,$ac,$ad,$ad,$ae,$af,$b0,$b1,$b2,$b2,$b3,$b4,$b5
 .byte $b6,$b7,$b7,$b8,$b9,$ba,$bb,$bc,$bd,$bd,$be,$bf,$c0,$c1,$c2,$c3
 .byte $c4,$c4,$c5,$c6,$c7,$c8,$c9,$ca,$cb,$cb,$cc,$cd,$ce,$cf,$d0,$d1
 .byte $d2,$d3,$d4,$d4,$d5,$d6,$d7,$d8,$d9,$da,$db,$dc,$dd,$de,$df,$e0
 .byte $e1,$e1,$e2,$e3,$e4,$e5,$e6,$e7,$e8,$e9,$ea,$eb,$ec,$ed,$ee,$ef
 .byte $f0,$f1,$f2,$f3,$f4,$f5,$f6,$f7,$f8,$f9,$fa,$fb,$fc,$fd,$fe,$ff
tables_end:
 .cerror * > $7000, "Tables collide with directions"
*=$7000
direction_0:
 .byte $ff,$7d,$bf,$2b,$61,$4f,$98,$a8,$34,$13,$2b,$6e,$d1,$4c,$d9,$77
 .byte $20,$d4,$90,$54,$1e,$ec,$c0,$97,$72,$50,$30,$13,$f8,$df,$c7,$b1
 .byte $9d,$8a,$78,$67,$57,$48,$39,$2c,$1f,$13,$07,$fc,$f2,$e8,$df,$d5
 .byte $cd,$c5,$bd,$b5,$ae,$a7,$a0,$9a,$94,$8e,$88,$82,$7d,$78,$73,$6f
 .byte $6a,$66,$61,$5d,$5a,$56,$52,$4f,$4b,$48,$45,$42,$3f,$3c,$39,$36
 .byte $34,$31,$2f,$2d,$2a,$28,$26,$24,$22,$20,$1f,$1d,$1b,$1a,$18,$17
 .byte $15,$14,$12,$11,$10,$0f,$0e,$0d,$0c,$0b,$0a,$09,$08,$07,$06,$06
 .byte $05,$04,$04,$03,$03,$02,$02,$02,$01,$01,$01,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$01,$01,$01,$02,$02,$02,$03,$03,$04,$04
 .byte $05,$06,$06,$07,$08,$09,$0a,$0b,$0c,$0d,$0e,$0f,$10,$11,$12,$14
 .byte $15,$17,$18,$1a,$1b,$1d,$1f,$20,$22,$24,$26,$28,$2a,$2d,$2f,$31
 .byte $34,$36,$39,$3c,$3f,$42,$45,$48,$4b,$4f,$52,$56,$5a,$5d,$61,$66
 .byte $6a,$6f,$73,$78,$7d,$82,$88,$8e,$94,$9a,$a0,$a7,$ae,$b5,$bd,$c5
 .byte $cd,$d5,$df,$e8,$f2,$fc,$07,$13,$1f,$2c,$39,$48,$57,$67,$78,$8a
 .byte $9d,$b1,$c7,$df,$f8,$13,$30,$50,$72,$97,$c0,$ec,$1e,$54,$90,$d4
 .byte $20,$77,$d9,$4c,$d1,$6e,$2b,$13,$34,$a8,$98,$4f,$61,$2b,$bf,$7d
 .byte $ff,$7d,$bf,$2b,$61,$4f,$98,$a8,$34,$13,$2b,$6e,$d1,$4c,$d9,$77
 .byte $20,$d4,$90,$54,$1e,$ec,$c0,$97,$72,$50,$30,$13,$f8,$df,$c7,$b1
 .byte $9d,$8a,$78,$67,$57,$48,$39,$2c,$1f,$13,$07,$fc,$f2,$e8,$df,$d5
 .byte $cd,$c5,$bd,$b5,$ae,$a7,$a0,$9a,$94,$8e,$88,$82,$7d,$78,$73,$6f
 .byte $6a,$66,$61,$5d,$5a,$56,$52,$4f,$4b,$48,$45,$42,$3f,$3c,$39,$36
 .byte $34,$31,$2f,$2d,$2a,$28,$26,$24,$22,$20,$1f,$1d,$1b,$1a,$18,$17
 .byte $15,$14,$12,$11,$10,$0f,$0e,$0d,$0c,$0b,$0a,$09,$08,$07,$06,$06
 .byte $05,$04,$04,$03,$03,$02,$02,$02,$01,$01,$01,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$01,$01,$01,$02,$02,$02,$03,$03,$04,$04
 .byte $05,$06,$06,$07,$08,$09,$0a,$0b,$0c,$0d,$0e,$0f,$10,$11,$12,$14
 .byte $15,$17,$18,$1a,$1b,$1d,$1f,$20,$22,$24,$26,$28,$2a,$2d,$2f,$31
 .byte $34,$36,$39,$3c,$3f,$42,$45,$48,$4b,$4f,$52,$56,$5a,$5d,$61,$66
 .byte $6a,$6f,$73,$78,$7d,$82,$88,$8e,$94,$9a,$a0,$a7,$ae,$b5,$bd,$c5
 .byte $cd,$d5,$df,$e8,$f2,$fc,$07,$13,$1f,$2c,$39,$48,$57,$67,$78,$8a
 .byte $9d,$b1,$c7,$df,$f8,$13,$30,$50,$72,$97,$c0,$ec,$1e,$54,$90,$d4
 .byte $20,$77,$d9,$4c,$d1,$6e,$2b,$13,$34,$a8,$98,$4f,$61,$2b,$bf,$7d
direction_1:
 .byte $ff,$51,$28,$1b,$14,$10,$0d,$0b,$0a,$09,$08,$07,$06,$06,$05,$05
 .byte $05,$04,$04,$04,$04,$03,$03,$03,$03,$03,$03,$03,$02,$02,$02,$02
 .byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
 .byte $02,$02,$02,$02,$02,$03,$03,$03,$03,$03,$03,$03,$04,$04,$04,$04
 .byte $05,$05,$05,$06,$06,$07,$08,$09,$0a,$0b,$0d,$10,$14,$1b,$28,$51
 .byte $ff,$51,$28,$1b,$14,$10,$0d,$0b,$0a,$09,$08,$07,$06,$06,$05,$05
 .byte $05,$04,$04,$04,$04,$03,$03,$03,$03,$03,$03,$03,$02,$02,$02,$02
 .byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
 .byte $02,$02,$02,$02,$02,$03,$03,$03,$03,$03,$03,$03,$04,$04,$04,$04
 .byte $05,$05,$05,$06,$06,$07,$08,$09,$0a,$0b,$0d,$10,$14,$1b,$28,$51
direction_2:
 .byte $00,$00,$00,$00,$00,$00,$01,$01,$01,$02,$02,$02,$03,$03,$04,$04
 .byte $05,$06,$06,$07,$08,$09,$0a,$0b,$0c,$0d,$0e,$0f,$10,$11,$12,$14
 .byte $15,$17,$18,$1a,$1b,$1d,$1f,$20,$22,$24,$26,$28,$2a,$2d,$2f,$31
 .byte $34,$36,$39,$3c,$3f,$42,$45,$48,$4b,$4f,$52,$56,$5a,$5d,$61,$66
 .byte $6a,$6f,$73,$78,$7d,$82,$88,$8e,$94,$9a,$a0,$a7,$ae,$b5,$bd,$c5
 .byte $cd,$d5,$df,$e8,$f2,$fc,$07,$13,$1f,$2c,$39,$48,$57,$67,$78,$8a
 .byte $9d,$b1,$c7,$df,$f8,$13,$30,$50,$72,$97,$c0,$ec,$1e,$54,$90,$d4
 .byte $20,$77,$d9,$4c,$d1,$6e,$2b,$13,$34,$a8,$98,$4f,$61,$2b,$bf,$7d
 .byte $ff,$7d,$bf,$2b,$61,$4f,$98,$a8,$34,$13,$2b,$6e,$d1,$4c,$d9,$77
 .byte $20,$d4,$90,$54,$1e,$ec,$c0,$97,$72,$50,$30,$13,$f8,$df,$c7,$b1
 .byte $9d,$8a,$78,$67,$57,$48,$39,$2c,$1f,$13,$07,$fc,$f2,$e8,$df,$d5
 .byte $cd,$c5,$bd,$b5,$ae,$a7,$a0,$9a,$94,$8e,$88,$82,$7d,$78,$73,$6f
 .byte $6a,$66,$61,$5d,$5a,$56,$52,$4f,$4b,$48,$45,$42,$3f,$3c,$39,$36
 .byte $34,$31,$2f,$2d,$2a,$28,$26,$24,$22,$20,$1f,$1d,$1b,$1a,$18,$17
 .byte $15,$14,$12,$11,$10,$0f,$0e,$0d,$0c,$0b,$0a,$09,$08,$07,$06,$06
 .byte $05,$04,$04,$03,$03,$02,$02,$02,$01,$01,$01,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$01,$01,$01,$02,$02,$02,$03,$03,$04,$04
 .byte $05,$06,$06,$07,$08,$09,$0a,$0b,$0c,$0d,$0e,$0f,$10,$11,$12,$14
 .byte $15,$17,$18,$1a,$1b,$1d,$1f,$20,$22,$24,$26,$28,$2a,$2d,$2f,$31
 .byte $34,$36,$39,$3c,$3f,$42,$45,$48,$4b,$4f,$52,$56,$5a,$5d,$61,$66
 .byte $6a,$6f,$73,$78,$7d,$82,$88,$8e,$94,$9a,$a0,$a7,$ae,$b5,$bd,$c5
 .byte $cd,$d5,$df,$e8,$f2,$fc,$07,$13,$1f,$2c,$39,$48,$57,$67,$78,$8a
 .byte $9d,$b1,$c7,$df,$f8,$13,$30,$50,$72,$97,$c0,$ec,$1e,$54,$90,$d4
 .byte $20,$77,$d9,$4c,$d1,$6e,$2b,$13,$34,$a8,$98,$4f,$61,$2b,$bf,$7d
 .byte $ff,$7d,$bf,$2b,$61,$4f,$98,$a8,$34,$13,$2b,$6e,$d1,$4c,$d9,$77
 .byte $20,$d4,$90,$54,$1e,$ec,$c0,$97,$72,$50,$30,$13,$f8,$df,$c7,$b1
 .byte $9d,$8a,$78,$67,$57,$48,$39,$2c,$1f,$13,$07,$fc,$f2,$e8,$df,$d5
 .byte $cd,$c5,$bd,$b5,$ae,$a7,$a0,$9a,$94,$8e,$88,$82,$7d,$78,$73,$6f
 .byte $6a,$66,$61,$5d,$5a,$56,$52,$4f,$4b,$48,$45,$42,$3f,$3c,$39,$36
 .byte $34,$31,$2f,$2d,$2a,$28,$26,$24,$22,$20,$1f,$1d,$1b,$1a,$18,$17
 .byte $15,$14,$12,$11,$10,$0f,$0e,$0d,$0c,$0b,$0a,$09,$08,$07,$06,$06
 .byte $05,$04,$04,$03,$03,$02,$02,$02,$01,$01,$01,$00,$00,$00,$00,$00
direction_3:
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
 .byte $02,$02,$02,$02,$02,$03,$03,$03,$03,$03,$03,$03,$04,$04,$04,$04
 .byte $05,$05,$05,$06,$06,$07,$08,$09,$0a,$0b,$0d,$10,$14,$1b,$28,$51
 .byte $ff,$51,$28,$1b,$14,$10,$0d,$0b,$0a,$09,$08,$07,$06,$06,$05,$05
 .byte $05,$04,$04,$04,$04,$03,$03,$03,$03,$03,$03,$03,$02,$02,$02,$02
 .byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
 .byte $02,$02,$02,$02,$02,$03,$03,$03,$03,$03,$03,$03,$04,$04,$04,$04
 .byte $05,$05,$05,$06,$06,$07,$08,$09,$0a,$0b,$0d,$10,$14,$1b,$28,$51
 .byte $ff,$51,$28,$1b,$14,$10,$0d,$0b,$0a,$09,$08,$07,$06,$06,$05,$05
 .byte $05,$04,$04,$04,$04,$03,$03,$03,$03,$03,$03,$03,$02,$02,$02,$02
 .byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
direction_4:
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
 .byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
 .byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
 .byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
 .byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
 .byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
 .byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
 .byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
 .byte $02,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
 .byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
 .byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
 .byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
 .byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
 .byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
 .byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
 .byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
 .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
directions_end:
 .cerror * > $7c00, "Directions collide with projection"
*=$7c00
height_table:
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b
 .byte $0b,$0c,$0d,$0e,$0e,$0f,$0f,$10,$11,$11,$12,$12,$13,$13,$14,$14
 .byte $15,$15,$15,$16,$16,$16,$17,$17,$18,$18,$18,$19,$19,$19,$19,$1a
 .byte $1a,$1a,$1b,$1b,$1b,$1b,$1b,$1c,$1c,$1c,$1c,$1d,$1d,$1d,$1d,$1d
 .byte $1e,$1e,$1e,$1e,$1e,$1f,$1f,$1f,$1f,$1f,$1f,$20,$20,$20,$20,$20
 .byte $20,$20,$21,$21,$21,$21,$21,$21,$21,$21,$22,$22,$22,$22,$22,$22
 .byte $22,$22,$22,$23,$23,$23,$23,$23,$23,$23,$23,$23,$23,$23,$24,$24
 .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$25,$25,$25,$25,$25,$25
 .byte $25,$25,$25,$25,$25,$25,$25,$25,$25,$26,$26,$26,$26,$26,$26,$26
 .byte $26,$26,$26,$26,$26,$26,$26,$26,$26,$26,$26,$27,$27,$27,$27,$27
 .byte $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27
 .byte $27,$28,$28,$28,$28,$28,$28,$28,$28,$28,$28,$28,$28,$28,$28,$28
 .byte $28,$28,$28,$28,$28,$28,$28,$28,$28,$28,$28,$28,$29,$29,$29,$29
 .byte $29,$29,$29,$29,$29,$29,$29,$29,$29,$29,$29,$29,$29,$29,$29,$29
 .byte $29,$29,$29,$29,$29,$29,$29,$29,$29,$29,$29,$29,$29,$29,$29,$29
 .byte $29,$2a,$2a,$2a,$2a,$2a,$2a,$2a,$2a,$2a,$2a,$2a,$2a,$2a,$2a,$2a
 .byte $2a,$2a,$2a,$2a,$2a,$2a,$2a,$2a,$2a,$2a,$2a,$2a,$2a,$2a,$2a,$2a
 .byte $2a,$2a,$2a,$2a,$2a,$2a,$2a,$2a,$2a,$2a,$2a,$2a,$2a,$2a,$2a,$2a
 .byte $2a,$2a,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b
 .byte $2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b
 .byte $2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b
 .byte $2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b
 .byte $2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2b,$2c,$2c,$2c,$2c,$2c,$2c
 .byte $2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c
 .byte $2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c
 .byte $2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c
 .byte $2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c
 .byte $2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c
 .byte $2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c
 .byte $2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$2d,$2d,$2d,$2d,$2d
 .byte $2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d
 .byte $2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d
 .byte $2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d
 .byte $2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d
 .byte $2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d
 .byte $2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d
 .byte $2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d
 .byte $2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d
 .byte $2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d
 .byte $2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d
 .byte $2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d
 .byte $2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d
 .byte $2d,$2d,$2d,$2d,$2d,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
 .byte $2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
 .byte $2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
 .byte $2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
 .byte $2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
 .byte $2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
 .byte $2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
 .byte $2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
 .byte $2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
 .byte $2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
 .byte $2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
 .byte $2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
 .byte $2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
 .byte $2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
 .byte $2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
 .byte $2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
 .byte $2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
 .byte $2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
 .byte $2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
 .byte $2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
data_end:
