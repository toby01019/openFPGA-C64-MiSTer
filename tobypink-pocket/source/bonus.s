.macpack longbranch
.export _bonus_spawn,_bonus_erase,_bonus_tick,_bonus_reset,_score_hud
.export _score_digits
.import _stage,_enemies,_px,_py,_frame,_sound
.import _bar_active
.importzp ptr1,ptr2,tmp1,tmp2,tmp3,tmp4
.segment "BSS"
_score_digits: .res 6
.segment "RODATA"
score_label: .byte 19,3,15,18,5,32
.segment "CODE"
_bonus_reset:
    lda #0
    sta _bar_active
    sta _bar_active+1
    sta _enemy_air
    sta _enemy_air+1
    rts
_bonus_spawn:
    lda _stage
    bne :+
    jmp add_score
:
    rts

_bonus_erase:
_bonus_tick:
    rts
add_score:
    ldx #2
@carry:
    inc _score_digits,x
    lda _score_digits,x
    cmp #10
    bcc _score_hud
    lda #0
    sta _score_digits,x
    inx
    cpx #6
    bne @carry
    ldx #5
    lda #9
:
    sta _score_digits,x
    dex
    bpl :-
_score_hud:
    ldx #5
@label:
    lda score_label,x
    sta $cc51,x
    lda #10
    sta $d851,x
    dex
    bpl @label
    ldx #0
    ldy #5
@digit:
    lda _score_digits,y
    clc
    adc #48
    sta $cc57,x
    lda #1
    sta $d857,x
    inx
    dey
    bpl @digit
    rts

.import _enemy_air
