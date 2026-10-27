; Hand-written, constant-time 6510 sprite staging. Maintains the existing
; cc65 calling convention for the older assembler mechanics.
.export _sprite, _hide, _sprite_mode, _publish_sprites
.import _draw_page, _pending_page, _sprite_ready
.import _spr_x, _spr_y, _spr_image, _spr_color
.import _spr_high, _spr_enabled, _spr_multi
.import pusha, addysp, incsp2
.importzp c_sp, tmp1, tmp2, tmp3, tmp4
.segment "RODATA"
bits: .byte 1,2,4,8,16,32,64,128
clearbits: .byte 254,253,251,247,239,223,191,127
.segment "CODE"
_sprite:
    ; On entry colour=A; stack: image, y(lo/hi), x(lo/hi), sprite number.
    jsr pusha
    ldy #6
    lda (c_sp),y
    tax
    lda bits,x
    sta tmp1
    lda clearbits,x
    sta tmp2
    txa
    sta tmp3
    lda _draw_page
    asl
    asl
    asl
    clc
    adc tmp3
    tax
    ldy #4
    lda (c_sp),y
    clc
    adc #24
    sta _spr_x,x
    iny
    lda (c_sp),y
    adc #0
    sta tmp4
    ldy #2
    lda (c_sp),y
    clc
    adc #50
    sta _spr_y,x
    ldy #1
    lda (c_sp),y
    clc
    adc #128
    sta _spr_image,x
    dey
    lda (c_sp),y
    sta _spr_color,x
    ldx _draw_page
    lda tmp4
    beq @low
    lda _spr_high,x
    ora tmp1
    bne @highdone
@low:
    lda _spr_high,x
    and tmp2
@highdone:
    sta _spr_high,x
    lda _spr_enabled,x
    ora tmp1
    sta _spr_enabled,x
    ldy #7
    jmp addysp

_hide:
    tax
    lda clearbits,x
    ldx _draw_page
    and _spr_enabled,x
    sta _spr_enabled,x
    rts

_sprite_mode:
    jsr pusha
    ldy #1
    lda (c_sp),y
    tax
    lda bits,x
    sta tmp1
    lda clearbits,x
    sta tmp2
    ldx _draw_page
    dey
    lda (c_sp),y
    beq @hires
    lda _spr_multi,x
    ora tmp1
    bne @done
@hires:
    lda _spr_multi,x
    and tmp2
@done:
    sta _spr_multi,x
    jmp incsp2

_publish_sprites:
    ; The other page is complete here. Replace an unconsumed pending page
    ; with the newest camera frame instead of retaining an older cave x.
    ; IRQ reads only the page selected by _pending_page, never this copy's
    ; destination. Both pages remain valid at every publication boundary.
    lda _draw_page
    sta _pending_page
    asl
    asl
    asl
    tay
    lda #1
    sta _sprite_ready
    lda _draw_page
    eor #1
    sta _draw_page
    asl
    asl
    asl
    tax
    .repeat 8,I
    lda _spr_x+I,y
    sta _spr_x+I,x
    lda _spr_y+I,y
    sta _spr_y+I,x
    lda _spr_image+I,y
    sta _spr_image+I,x
    lda _spr_color+I,y
    sta _spr_color+I,x
    .endrepeat
    ldy _pending_page
    ldx _draw_page
    lda _spr_high,y
    sta _spr_high,x
    lda _spr_enabled,y
    sta _spr_enabled,x
    lda _spr_multi,y
    sta _spr_multi,x
@return:
    rts
