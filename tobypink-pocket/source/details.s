.export _flight_details,_toby_flight_head
.import _flight_dir,_draw_page,_spr_image,_spr_x,_spr_high,_spr_y,_spr_color,_spr_enabled,_spr_multi
.import _px,_py,_frame,_sprite,_stage
.import pusha,pushax
.segment "CODE"
_flight_details:
    jsr _preview_install
    jsr _campaign_hud
    sei
    lda #$34
    sta $01
    ldx #15
:
    lda $c430,x
    sta $d430,x
    sta $dc30,x
    sta $f430,x
    sta $fc30,x
    dex
    bpl :-
    lda #$35
    sta $01
    cli
    ; Native bones are part of the beach ring, so they scroll with the sand.
    lda #140
    sta $ced9
    sta $cee9
    lda #141
    sta $ceda
    sta $ceea
    lda #1
    sta $dad9
    sta $dada
    sta $dae9
    sta $daea
    rts
_toby_flight_head:
 ldx _draw_page
 lda _spr_enabled,x
 ora #67
 sta _spr_enabled,x
 lda _spr_multi,x
 and #254
 ora #66
 sta _spr_multi,x
 lda _spr_high,x
 and #188
 sta _spr_high,x
 txa
 asl
 asl
 asl
 tax
 lda #181
 ldy _flight_dir
 bpl :+
 lda #191
:
 sta _spr_image+6,x
 lda #185
 ldy _flight_dir
 bpl :+
 lda #187
:
 sta _spr_image,x
 lda #182
 ldy _flight_dir
 bpl :+
 lda #186
:
 sta _spr_image+1,x
 lda #11
 sta _spr_color+6,x
 sta _spr_color+1,x
 lda #1
 sta _spr_color,x
 lda _frame
 lsr
 lsr
 lsr
 and #1
 clc
 adc _py
 clc
 adc #41
 sta _spr_y,x
 sta _spr_y+6,x
 clc
 adc #9
 sta _spr_y+1,x
 lda _px
 clc
 adc #24
 sta _spr_x,x
 sta _spr_x+6,x
 lda _px+1
 adc #0
 beq :+
 ldy _draw_page
 lda _spr_high,y
 ora #65
 sta _spr_high,y
:
 lda _px
 clc
 adc #16
 sta _spr_x+1,x
 lda _px+1
 adc #0
 beq :+
 ldy _draw_page
 lda _spr_high,y
 ora #2
 sta _spr_high,y
:
 rts

.export _flight_splatter
.import _gore_x
.importzp ptr1,tmp1
_flight_splatter:
 lda _gore_x
 sta tmp1
 ldy #1
 lda (ptr1),y
 lsr
 ror tmp1
 lsr tmp1
 lsr tmp1
 ldx tmp1
 lda #134
 sta $ced0,x
 lda #135
 sta $ced1,x
 lda #134
 sta $ced2,x
 lda #2
 sta $dad0,x
 sta $dad1,x
 sta $dad2,x
 rts

.segment "BSS"
head_bob: .res 1

.import _preview_install

.import _campaign_hud
