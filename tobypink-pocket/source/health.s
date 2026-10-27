.macpack longbranch
.export _bar_erase,_bar_draw,_bar_active
.import _enemies,_stage
.importzp ptr1,ptr2,tmp1,tmp2
.segment "BSS"
_bar_active: .res 2
bar_lo: .res 2
bar_hi: .res 2
bar_ch: .res 2
bar_col: .res 2
bar_slot: .res 1
bar_hp: .res 1
.segment "CODE"
pointer:
    lda bar_lo,x
    sta ptr1
    sta ptr2
    lda bar_hi,x
    sta ptr1+1
    clc
    adc #12
    sta ptr2+1
    ldy #0
    rts
_bar_erase:
    lda _stage
    bne @done
    ldx #0
@each:
    lda _bar_active,x
    beq @next
    jsr pointer
    lda bar_ch,x
    sta (ptr1),y
    lda bar_col,x
    sta (ptr2),y
    lda #0
    sta _bar_active,x
@next:
    inx
    cpx #2
    bne @each
@done:
    rts
erase_slot:
    lda _bar_active,x
    beq :+
    jsr pointer
    lda bar_ch,x
    sta (ptr1),y
    lda bar_col,x
    sta (ptr2),y
    lda #0
    sta _bar_active,x
:
    rts
_bar_draw:
    lda _stage
    jne @done
    lda #1
    sta bar_slot
@each:
    ldy #0
    lda bar_slot
    beq :+
    ldy #10
:
    lda _enemies+7,y
    jne @remove
    lda _enemies+5,y
    jeq @remove
    cmp #7
    jcs @remove
    sta bar_hp
    lda _enemies,y
    clc
    adc #8
    sta tmp1
    lda _enemies+1,y
    adc #0
    lsr
    ror tmp1
    lsr tmp1
    lsr tmp1
    lda _enemies+2,y
    sec
    sbc #17
    lsr
    lsr
    lsr
    cmp #3
    jcc @remove
    cmp #23
    jcs @remove
    tay
    lda #0
    sta ptr1
    lda #$cc
    sta ptr1+1
@row:
    clc
    lda ptr1
    adc #40
    sta ptr1
    bcc :+
    inc ptr1+1
:
    dey
    bne @row
    clc
    lda ptr1
    adc tmp1
    ldx bar_slot
    sta tmp1
    lda ptr1+1
    adc #0
    sta tmp2
    jsr bar_covered
    jcs @remove
    lda _bar_active,x
    beq @save
    lda bar_lo,x
    cmp tmp1
    bne @move
    lda bar_hi,x
    cmp tmp2
    beq @update
@move:
    jsr erase_slot
@save:
    lda tmp1
    sta bar_lo,x
    lda tmp2
    sta bar_hi,x
    jsr pointer
    lda (ptr1),y
    sta bar_ch,x
    lda (ptr2),y
    sta bar_col,x
@update:
    jsr pointer
    lda bar_hp
    clc
    adc #194
    sta (ptr1),y
    lda #5
    ldx bar_hp
    cpx #4
    bcs :+
    lda #7
    cpx #2
    bcs :+
    lda #2
:
    sta (ptr2),y
    ldx bar_slot
    lda #1
    sta _bar_active,x
    jmp @next
@remove:
    ldx bar_slot
    jsr erase_slot
@next:
    dec bar_slot
    jpl @each
@done:
    rts


.import _bubble_drawn,_bubble_at,_bubble_width,_bubble_height
bar_covered:
    lda _bubble_drawn
    beq @no
    sec
    lda tmp1
    sbc _bubble_at
    sta ptr2
    lda tmp2
    sbc #$cc
    sec
    sbc _bubble_at+1
    sta ptr2+1
    bmi @no
    ldy #0
@row:
    lda ptr2+1
    bne @subtract
    lda ptr2
    cmp #40
    bcc @column
@subtract:
    sec
    lda ptr2
    sbc #40
    sta ptr2
    bcs :+
    dec ptr2+1
:
    iny
    cpy _bubble_height
    bcc @row
@no:
    clc
    rts
@column:
    cmp _bubble_width
    bcs @no
    sec
    rts
