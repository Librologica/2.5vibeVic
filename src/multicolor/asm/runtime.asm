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
