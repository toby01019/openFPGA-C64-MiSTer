; Fast signed distance and collectible collision checks, with the existing ABI.
.macpack longbranch
.export _distance, _collect
.import _px, _py, _drops, _pink, _ammo, _show_drop, _sound, _hud
.import pushax, incsp2
.importzp c_sp, tmp1, tmp2, tmp3
.segment "BSS"
collect_index: .res 1
collect_offset: .res 1
.segment "CODE"
_distance:
    sta tmp1
    stx tmp2
    ldy #0
    lda (c_sp),y
    sec
    sbc tmp1
    sta tmp3
    iny
    lda (c_sp),y
    sbc tmp2
    sta tmp2
    bvc :+
    eor #$80
:
    bpl @positive
    lda #0
    sec
    sbc tmp3
    sta tmp3
    lda #0
    sbc tmp2
    sta tmp2
@positive:
    lda tmp3
    ldx tmp2
    jmp incsp2

_collect:
    lda #0
    sta collect_index
    sta collect_offset
@each:
    ldy collect_offset
    lda _drops+2,y
    cmp #3
    jeq @next
    cmp #1
    jeq @next
    lda _px
    ldx _px+1
    clc
    adc #10
    bcc :+
    inx
:
    jsr pushax
    ldy collect_offset
    lda _drops,y
    ldx #0
    asl
    asl
    asl
    bcc :+
    inx
:
    clc
    adc #4
    bcc :+
    inx
:
    jsr _distance
    cpx #0
    bne @next
    cmp #15
    bcs @next
    lda _py
    ldx _py+1
    clc
    adc #12
    bcc :+
    inx
:
    jsr pushax
    ldy collect_offset
    lda _drops+1,y
    asl
    asl
    asl
    clc
    adc #4
    ldx #0
    jsr _distance
    cpx #0
    bne @next
    cmp #19
    bcs @next
    ldy collect_offset
    lda #3
    sta _drops+2,y
    inc _pink
    jsr _campaign_save
    lda _ammo
    cmp #48
    bcs :+
    clc
    adc #2
    sta _ammo
:
    lda collect_index
    jsr _show_drop
    lda #1
    jsr _sound
    jsr _hud
@next:
    lda collect_offset
    clc
    adc #3
    sta collect_offset
    inc collect_index
    lda collect_index
    cmp #6
    bcs :+
    jmp @each
:
    rts


.import _campaign_save
