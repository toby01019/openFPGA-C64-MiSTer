.macpack longbranch
.export _preview_draw,_preview_erase,_preview_install
.import _world_x,_stage,_landing_state,_draw_page,_spr_enabled,_spr_multi,_spr_high,_spr_x,_spr_y,_spr_color,_spr_image
.importzp ptr1,ptr2
.segment "CODE"
_preview_install:
 lda _destination
 cmp #4
 lda #0
 rol
 sta cave_palette
 tax
 lda cave_pack_lo,x
 sta ptr1
 lda cave_pack_hi,x
 sta ptr1+1
 lda #0
 sta ptr2
 lda #$f8
 sta ptr2+1
 jmp _unpack_assets
_preview_erase:
 rts
_preview_draw:
 ldx _draw_page
 lda _spr_enabled,x
 and #223
 sta _spr_enabled,x
 lda _stage
 cmp #1
 beq @stage_ok
 cmp #3
 jne cave_done
@stage_ok:
 lda _destination
 cmp #4
 lda #0
 rol
 cmp cave_palette
 beq :+
 jsr _preview_install
:
 lda _world_x+1
 and #1
 sta cave_half
 bne @left
 lda _world_x
 cmp #64
 jcc cave_done
 jmp @visible
@left:
 lda _world_x
 cmp #172
 jcs cave_done
@visible:
 jsr crop_cave

 ldx _draw_page
 lda _spr_enabled,x
 ora #32
 sta _spr_enabled,x
 lda _spr_multi,x
 ora #32
 sta _spr_multi,x
 lda _spr_high,x
 and #223
 sta _spr_high,x
 lda #148
 sec
 sbc _world_x
 sta cave_x
 lda #1
 sbc cave_half
 beq :+
 bmi :+
 lda _spr_high,x
 ora #32
 sta _spr_high,x
:

 lda cave_half
 beq :+
 lda _world_x
 cmp #124
 bcc :+
 and #3
 eor #255
 clc
 adc #25
 sta cave_x
:
 txa
 asl
 asl
 asl
 tax
 lda cave_x
 sta _spr_x+5,x
 lda #144
 sta _spr_y+5,x
 lda cave_clip
 clc
 adc #224
 pha
 lda _stage
 cmp #3
 bne @flight_image
 pla
 lda #207
 bne @image_ready
@flight_image:
 pla
@image_ready:
 sta _spr_image+5,x
 lda #0
 sta _spr_color+5,x
cave_done:
 rts
.segment "RODATA"
cave_sprite: .incbin "cave-clips.bin",0,64
.export cave_sprite
pink_cave_sprite: .incbin "pink-cave-clips.bin",0,64
.export pink_cave_sprite

.export _flight_reserve
_flight_reserve:
 lda _stage
 beq @copy
 cmp #5
 bne @done
@copy:
 ldx #127
:
 lda $f000,x
 sta $ee80,x
 dex
 bpl :-
@done:
 rts

.segment "BSS"
cave_x: .res 1
cave_half: .res 1
crop_bits: .res 1
crop_byte: .res 1
crop_last: .res 2
crop_start: .res 1
crop_end: .res 1

.import _portal_phase

.segment "CODE"
crop_cave:
 lda #0
 sta cave_clip
 lda cave_half
 beq @done
 lda _world_x
 cmp #124
 bcc @done
 sec
 sbc #124
 lsr
 lsr
 sta cave_clip
@done:
 rts
.segment "BSS"
cave_clip: .res 1
.segment "RODATA"
cave_clips: .incbin "cave-clips.pak"
pink_cave_clips: .incbin "pink-cave-clips.pak"
cave_pack_lo: .byte <cave_clips,<pink_cave_clips
cave_pack_hi: .byte >cave_clips,>pink_cave_clips
.segment "BSS"
cave_palette: .res 1
.import _unpack_assets


.import _destination
