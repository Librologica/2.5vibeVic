; Sparse silhouette refinement. Main-thread-only state, IRQ uses $60-$6f.
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
 sta pixel_top+2,y
 sta pixel_top+3,y
 iny
 iny
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
 asl
 tax
 stx edge_pair_base
 clc
 lda edge_lerp_1,y
 adc edge_t
 sta pixel_top+2,x
 cmp edge_t
 beq edge_no_queue_1
 lda #2
 jsr edge_enqueue
edge_no_queue_1:
 ldy edge_delta
 clc
 lda edge_lerp_3,y
 adc edge_t
 sta pixel_top+3,x
 cmp edge_t
 beq edge_no_queue_3
 lda #3
 jsr edge_enqueue
edge_no_queue_3:
 ldy edge_delta
 clc
 lda edge_lerp_5,y
 adc edge_t
 sta pixel_top+4,x
 cmp edge_right
 beq edge_no_queue_5
 lda #4
 jsr edge_enqueue
edge_no_queue_5:
 ldy edge_delta
 clc
 lda edge_lerp_7,y
 adc edge_t
 sta pixel_top+5,x
 cmp edge_right
 beq edge_no_queue_7
 lda #5
 jsr edge_enqueue
edge_no_queue_7:
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
