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
ray_t_lo=$3a00
ray_t_hi=$3a50
ray_u=$3aa0
ray_mat=$3af0
ray_side=$3b40
ray_steps=$3b90

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
 sta hit_u
 lda #$ff
 sta hit_t
 sta hit_t+1
 sta mul_r
 sta mul_r+1
 jmp ray_store
ray_hit:
 sta hit_mat
 lda hit_t
 sta mul_a
 lda hit_t+1
 sta mul_a+1
 lda hit_side
 bne hit_y_uv
 lda dir_y
 sta mul_b
 lda dir_y+1
 bne uv_axis
 jmp uv_multiply
hit_y_uv:
 lda dir_x
 sta mul_b
 lda dir_x+1
 bne uv_axis
uv_multiply:
 jsr mul16x8_shift8
 lda mul_r
 jmp uv_offset
uv_axis:
 lda hit_t
uv_offset:
 sta temp
 lda hit_side
 bne uv_y_hit
 lda dir_sign
 and #2
 bne uv_x_negative
 clc
 lda pose_y
 adc temp
 jmp uv_texel
uv_x_negative:
 sec
 lda pose_y
 sbc temp
 jmp uv_texel
uv_y_hit:
 lda dir_sign
 and #1
 bne uv_y_negative
 clc
 lda pose_x
 adc temp
 jmp uv_texel
uv_y_negative:
 sec
 lda pose_x
 sbc temp
uv_texel:
 lsr
 lsr
 lsr
 lsr
 lsr
 sta hit_u
 lda hit_side
 bne uv_flip_y
 lda dir_sign
 and #1
 bne uv_ready
 jmp uv_flip
uv_flip_y:
 lda dir_sign
 and #2
 beq uv_ready
uv_flip:
 lda hit_u
 eor #7
 sta hit_u
uv_ready:
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
 lda hit_t
 sta ray_t_lo,x
 lda hit_t+1
 sta ray_t_hi,x
 lda mul_r
 sta depth_lo,x
 lda mul_r+1
 sta depth_hi,x
 lda hit_u
 sta ray_u,x
 lda hit_mat
 sta ray_mat,x
 lda hit_side
 sta ray_side,x
 lda steps
 sta ray_steps,x
 inc ray_index
 lda ray_index
 cmp #80
 bne ray_next
raycast_done:
 rts

; Exact floor(unsigned16 * unsigned8 /256). Decimal mode is clear.
; Fixed 8 iterations; carry represents the 17th bit before right shift.
mul16x8_shift8:
 lda #0
 sta mul_r
 sta mul_r+1
 ldx #8
mul_loop:
 lsr mul_b
 bcc mul_no_add
 clc
 lda mul_r
 adc mul_a
 sta mul_r
 lda mul_r+1
 adc mul_a+1
 sta mul_r+1
mul_no_add:
 ror mul_r+1
 ror mul_r
 dex
 bne mul_loop
 rts

; DIRECTION_LOAD
