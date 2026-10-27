; Approved 30-pixel character. Upper body uses an MC plane plus a hires
; detail plane; sprite 4 supplies the legs. Bullets retain their own tiles.
.export _toby_lower,_toby_death_y
.import _stage,_death_age,_py,_draw_page
.import _spr_image,_spr_y,_spr_x,_spr_color,_spr_high,_spr_multi,_spr_enabled
.import _climbing,_pose
.segment "CODE"
_toby_lower:
 lda _stage
 beq draw
 cmp #3
 beq draw
 cmp #2
 bne done
 lda _death_age
 cmp #12
 bcc draw
 ldx _draw_page
 lda _spr_enabled,x
 and #239
 sta _spr_enabled,x
done:
 rts
draw:
 ldx _draw_page
 lda _spr_enabled,x
 ora #16
 sta _spr_enabled,x
 lda _spr_multi,x
 ora #18
 and #254
 sta _spr_multi,x
 lda _spr_high,x
 and #239
 lsr
 bcc :+
 ora #8
:
 rol
 sta _spr_high,x
 txa
 asl
 asl
 asl
 tax
 lda _spr_x,x
 sta _spr_x+4,x
 lda _spr_y,x
 clc
 adc #21
 sta _spr_y+4,x
 lda #4
 sta _spr_color+4,x
 ; Position, not the global clock, drives climbing. Releasing the stick
 ; freezes the pose; descending retraces the hand/foot cycle in reverse.
 lda _stage
 bne regular
 lda _climbing
 beq regular
 lda _pose
 cmp #4
 bcs regular
 lda _py
 lsr
 lsr
 and #3
 tay
 clc
 adc #250
 sta _spr_image+1,x
 lda #254
 sta _spr_image,x
 lda climb_lower,y
 sta _spr_image+4,x
 rts
regular:
 lda _spr_image+1,x
 cmp #208
 bcs walk
 cmp #144
 lda #248
 bcc :+
 lda #249
:
 sta _spr_image+4,x
 rts
walk:
 sec
 sbc #208
 lsr
 cmp #8
 bcs left
 clc
 adc #240
 sta _spr_image+4,x
 rts
left:
 and #7
 tay
 lda lower_left,y
 sta _spr_image+4,x
 rts
_toby_death_y:
 lda _death_age
 cmp #12
 lda _py
 bcs :+
 sec
 sbc #9
:
 ldx #0
 rts
.segment "RODATA"
.include "toby-lower.inc"
climb_lower: .byte 134,135,150,151
