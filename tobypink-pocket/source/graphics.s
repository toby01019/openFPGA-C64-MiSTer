; Hand-written 6510 graphics and joystick routines.
; World: original single-pixel Halloween room font. HUD: separate ROM font.
; Speech: 3x5 pixel lettering packed into tiny pre-rendered character tiles.
.export _controls, _load_world_font, _restore_ui_font
.export _bubble_show, _bubble_hide, _bubble_begin, _bubble_finish
.export _install_flight_bubbles
.import _weapon_key
.import _debug_input, _frame, _bubble_x, _bubble_y, _bubble_kind
.import _bubble_drawn, _bubble_at, _bubble_width, _bubble_height
.import _bubble_screen, _bubble_color
.importzp ptr1, ptr2, ptr3, tmp1, tmp2, tmp3, tmp4
.segment "BSS"
joy_bits: .res 1
bubble_age: .res 1
bubble_last_kind: .res 1
bubble_last_frame: .res 2
bubble_row: .res 1
bubble_col: .res 1
bubble_index: .res 1
bubble_reveal: .res 1
bubble_requested: .res 1
bubble_old: .res 4
bubble_previous_reveal: .res 1
bubble_save: .res 1
bubble_pages: .res 12
speech_x: .res 2
speech_y: .res 1
speech_kind: .res 1
.segment "RODATA"
_world_font = $c000
world_font = $c000
.export _world_font
packed_world_font: .incbin "world-font.pak"
bubble_maps: .incbin "bubble-maps.bin"
.include "bubble-tables.inc"
.segment "CODE"
_controls:
    lda #$fe
    sta $dc00
    lda #$ff
    sta $dc02
    lda $dc01
    eor #$ff
    and #16
    sta _weapon_key
    lda #0
    sta $dc02
    sta $dc03
    lda #$ff
    sta $dc00
    lda $dc00
    eor #$ff
    and #31
    sta joy_bits
    lda #$ff
    sta $dc02
    lda #$fd
    sta $dc00
    lda $dc01
    eor #$ff
    tax
    and #2
    beq :+
    lda joy_bits
    ora #1
    sta joy_bits
:
    txa
    and #4
    beq :+
    lda joy_bits
    ora #4
    sta joy_bits
:
    txa
    and #32
    beq :+
    lda joy_bits
    ora #2
    sta joy_bits
:
    lda #$fb
    sta $dc00
    lda $dc01
    eor #$ff
    tax
    and #4
    beq :+
    lda joy_bits
    ora #8
    sta joy_bits
:
    txa
    and #32
    beq :+
    lda joy_bits
    ora #16
    sta joy_bits
:
    txa
    and #2
    beq :+
    lda joy_bits
    ora #128
    sta joy_bits
:
    lda #$7f
    sta $dc00
    lda $dc01
    and #16
    bne :+
    lda joy_bits
    ora #16
    sta joy_bits
:
    lda #$ef
    sta $dc00
    lda $dc01
    eor #$ff
    tax
    and #4
    beq :+
    lda joy_bits
    ora #32
    sta joy_bits
:
    txa
    and #32
    beq :+
    lda joy_bits
    ora #64
    sta joy_bits
:
    lda #$ff
    sta $dc00
    lda #0
    sta $dc02
    lda joy_bits
    ora _debug_input
    ldx #0
    rts

_restore_ui_font:
    php
    sei
    lda $01
    pha
    lda #$31
    sta $01
    ldx #0
:
    ; Character ROM reads; writes underneath it to the same RAM address.
    lda _ui_font,x
    sta $d000,x
    lda _ui_font+256,x
    sta $d100,x
    inx
    bne :-
    pla
    sta $01
    plp
    rts

_load_world_font:
 lda #<packed_world_font
 sta ptr1
 lda #>packed_world_font
 sta ptr1+1
 lda #0
 sta ptr2
 lda #$c0
 sta ptr2+1
 jmp _unpack_font
.import _unpack_font

; Called with I/O hidden, after the four flight fonts have been installed.
; Slots 203..249 are reserved for the miniature speech glyphs in every band.
_install_flight_bubbles:
 rts

; Bubble row pointers. Screen-relative offset also remains in _bubble_at.
bubble_pointers:
    clc
    lda _bubble_at
    adc #<$cc00
    sta ptr1
    lda _bubble_at+1
    adc #>$cc00
    sta ptr1+1
    clc
    lda _bubble_at
    adc #<$d800
    sta ptr3
    lda _bubble_at+1
    adc #>$d800
    sta ptr3+1
    lda #0
    sta bubble_row
    sta bubble_index
    rts
bubble_next_row:
    clc
    lda ptr1
    adc #40
    sta ptr1
    bcc :+
    inc ptr1+1
:
    clc
    lda ptr3
    adc #40
    sta ptr3
    bcc :+
    inc ptr3+1
:
    inc bubble_row
    lda bubble_row
    cmp _bubble_height
    rts
_bubble_hide:
    lda _bubble_drawn
    beq hidden
    jsr bubble_pointers
    ldx #0
restore_row:
    ldy #0
restore_cell:
    lda _bubble_screen,x
    sta (ptr1),y
    lda _bubble_color,x
    sta (ptr3),y
    inx
    iny
    cpy _bubble_width
    bne restore_cell
    jsr bubble_next_row
    bne restore_row
    lda #0
    sta _bubble_drawn
hidden:
    rts

_bubble_begin:
    lda #0
    sta bubble_requested
    rts
_bubble_finish:
    lda _draw_page
    asl
    sta bubble_index
    asl
    clc
    adc bubble_index
    tax
    lda bubble_requested
    sta bubble_pages,x
    lda _bubble_x
    sta bubble_pages+1,x
    lda _bubble_x+1
    sta bubble_pages+2,x
    lda _bubble_y
    sta bubble_pages+3,x
    lda _bubble_kind
    sta bubble_pages+4,x
    rts
_bubble_show:
    ; Main loop submits the speaker; the actual text writes happen in VBlank.
    lda #1
    sta bubble_requested
    rts
bubble_paint:
    lda _bubble_at
    sta bubble_old
    lda _bubble_at+1
    sta bubble_old+1
    lda _bubble_width
    sta bubble_old+2
    lda _bubble_height
    sta bubble_old+3
    lda bubble_reveal
    sta bubble_previous_reveal
    ldx speech_kind
    cpx #BUBBLE_KIND_COUNT
    bcc :+
    ldx #0
:
    stx tmp4
    lda bubble_widths,x
    sta _bubble_width
    lda bubble_heights,x
    sta _bubble_height
    ; Reset opening animation after a gap or change of speaker phrase.
    lda _bubble_drawn
    beq reset_age
    txa
    cmp bubble_last_kind
    bne reset_age
    lda bubble_age
    cmp #32
    bcs age_ready
    inc bubble_age
    jmp age_ready
reset_age:
    lda #255
    sta bubble_previous_reveal
    lda #0
    sta bubble_age
age_ready:
    lda _frame
    sta bubble_last_frame
    lda _frame+1
    sta bubble_last_frame+1
    stx bubble_last_kind
    lda bubble_age
    and #$fe
    clc
    adc #3
    cmp _bubble_width
    bcc :+
    lda _bubble_width
:
    sta bubble_reveal
    ; Bubble left edge: center on speaker, clamp to visible playfield.
    lda speech_x
    sta tmp1
    lda speech_x+1
    bmi negative_x
    sta tmp2
    .repeat 3
        lsr tmp2
        ror tmp1
    .endrepeat
    lda _bubble_width
    lsr
    sta tmp2
    lda tmp1
    clc
    adc #1
    sec
    sbc tmp2
    bcs clamp_right
negative_x:
    lda #0
clamp_right:
    sta tmp1
    lda #40
    sec
    sbc _bubble_width
    cmp tmp1
    bcs :+
    sta tmp1
:
    lda speech_y
    lsr
    lsr
    lsr
    sec
    sbc _bubble_height
    bcc bubble_top
    sec
    sbc #1
    bcc bubble_top
    cmp #3
    bcs :+
bubble_top:
    lda #3
:
    sta tmp2
    ; at = row*40 + x, small enough for an eight-bit row counter.
    lda #0
    sta _bubble_at
    sta _bubble_at+1
    ldx tmp2
row_offset:
    clc
    lda _bubble_at
    adc #40
    sta _bubble_at
    bcc :+
    inc _bubble_at+1
:
    dex
    bne row_offset
    clc
    lda _bubble_at
    adc tmp1
    sta _bubble_at
    bcc :+
    inc _bubble_at+1
:
    lda _bubble_drawn
    beq new_bubble
    lda _bubble_at
    cmp bubble_old
    bne relocate
    lda _bubble_at+1
    cmp bubble_old+1
    bne relocate
    lda _bubble_width
    cmp bubble_old+2
    bne relocate
    lda _bubble_height
    cmp bubble_old+3
    bne relocate
    lda bubble_reveal
    cmp bubble_previous_reveal
    bne repaint
    rts
relocate:
    lda _bubble_at
    pha
    lda _bubble_at+1
    pha
    lda _bubble_width
    pha
    lda _bubble_height
    pha
    lda bubble_old
    sta _bubble_at
    lda bubble_old+1
    sta _bubble_at+1
    lda bubble_old+2
    sta _bubble_width
    lda bubble_old+3
    sta _bubble_height
    jsr _bubble_hide
    pla
    sta _bubble_height
    pla
    sta _bubble_width
    pla
    sta _bubble_at+1
    pla
    sta _bubble_at
    jmp new_bubble
repaint:
    lda #0
    beq paint_map
new_bubble:
    lda #1
paint_map:
    sta bubble_save
    ldx tmp4
    clc
    lda #<bubble_maps
    adc bubble_offsets,x
    sta ptr2
    lda #>bubble_maps
    adc #0
    sta ptr2+1
    jsr bubble_pointers
    ldx #0
draw_row:
    ldy #0
    lda bubble_save
    beq paint_row
save_row:
    lda (ptr1),y
    sta _bubble_screen,x
    lda (ptr3),y
    and #15
    sta _bubble_color,x
    inx
    iny
    cpy _bubble_width
    bne save_row
    ldy #0
paint_row:
    lda (ptr2),y
    sta (ptr1),y
    lda #1
    sta (ptr3),y
    iny
    cpy bubble_reveal
    bne paint_row
    clc
    lda ptr2
    adc _bubble_width
    sta ptr2
    bcc :+
    inc ptr2+1
:
    jsr bubble_next_row
    bne draw_row
    lda #1
    sta _bubble_drawn
    rts

.import _bar_erase

.segment "BSS"
bubble_pending: .res 1
.segment "CODE"
.export _bubble_commit
.import _bar_draw, _stage
_bubble_commit:
    lda _stage
    beq :+
    lda _bubble_drawn
    bne :+
    rts
:
    ; Called only with a complete published sprite frame. All scratch registers
    ; are saved because raster IRQs may interrupt arbitrary game routines.
    .repeat 4,I
        lda tmp1+I
        pha
    .endrepeat
    .repeat 6,I
        lda ptr1+I
        pha
    .endrepeat
    jsr _bar_erase
    ; Classic-C64 sample NMIs consume the border drawing budget. Keep an
    ; existing phrase intact during that short voice, then follow its latest
    ; speaker position. Ultimate audio runs independently (_sample_left=0).
    lda _sample_left
    ora _sample_left+1
    bne @bars
    lda _stage
    bne @hide
    lda _pending_page
    asl
    sta bubble_index
    asl
    clc
    adc bubble_index
    tax
    lda bubble_pages,x
    beq @hide
    lda bubble_pages+1,x
    sta speech_x
    lda bubble_pages+2,x
    sta speech_x+1
    lda bubble_pages+3,x
    sta speech_y
    lda bubble_pages+4,x
    sta speech_kind
    jsr bubble_paint
    jmp @bars
@hide:
    jsr _bubble_hide
@bars:
    jsr _bar_draw
@done:
_overlay_done:
    .repeat 6,I
        pla
        sta ptr1+5-I
    .endrepeat
    .repeat 4,I
        pla
        sta tmp1+3-I
    .endrepeat
    rts

.export _overlay_done

.segment "RODATA"
.export _ui_font
_ui_font: .incbin "ui-font.bin"

.import _draw_page,_pending_page
.import _sample_left
