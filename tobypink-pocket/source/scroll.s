.macpack longbranch
; PAL scroll: direct row copies, with separated character-boundary phases.
.export _flight_scroll,_flight_phase
.export _flight_shared_font
.import _frame,_scroll_jungle,_scroll_beach,_scroll_water,_raster_scroll
.import _flight_offset,_flight_map,_flight_colors,_halloween_tiles,_sample_left
.import _flight_dir
.importzp ptr1,ptr2
.segment "CODE"
; Called with I/O hidden during flight setup. Preserve the coast/HUD glyphs.
_flight_shared_font:
 rts

 .export _flight_speed
.segment "BSS"
_flight_speed: .res 1
.segment "CODE"
_flight_phase:
    lda #0
    sta shift_mask
    lda #1
    sta _flight_speed
    lda _landing_state
    bne @phases
    lda _input
    and #2
    bne :+
    lda #4
    sta _flight_speed
:
    lda _input
    and #16
    bne @phases
    lda _input
    and #4
    beq :+
    lda #255
    sta _flight_dir
:
    lda _input
    and #8
    beq @phases
    lda #1
    sta _flight_dir
@phases:

    lda _flight_dir
    bmi phase_jungle_back
    lda _scroll_jungle
    sec
    sbc _flight_speed
    bcs phase_jungle_done
    jmp phase_jungle_shift
phase_jungle_back:
    lda _scroll_jungle
    clc
    adc _flight_speed
    cmp #8
    bcc phase_jungle_done
phase_jungle_shift:
    pha
    lda shift_mask
    ora #1
    sta shift_mask
    pla
phase_jungle_done:
    and #7
    sta _scroll_jungle

    lda _flight_dir
    bmi phase_beach_back
    lda _scroll_beach
    sec
    sbc _flight_speed
    bcs phase_beach_done
    jmp phase_beach_shift
phase_beach_back:
    lda _scroll_beach
    clc
    adc _flight_speed
    cmp #8
    bcc phase_beach_done
phase_beach_shift:
    pha
    lda shift_mask
    ora #2
    sta shift_mask
    pla
phase_beach_done:
    and #7
    sta _scroll_beach

    lda _flight_dir
    bmi phase_water_back
    lda _scroll_water
    sec
    sbc _flight_speed
    bcs phase_water_done
    jmp phase_water_shift
phase_water_back:
    lda _scroll_water
    clc
    adc _flight_speed
    cmp #8
    bcc phase_water_done
phase_water_shift:
    pha
    lda shift_mask
    ora #4
    sta shift_mask
    pla
phase_water_done:
    and #7
    sta _scroll_water
phase_offsets:
    lda _scroll_jungle
    sta _raster_scroll
    sta _raster_scroll+1
    sta _raster_scroll+2
    sta _raster_scroll+3
    lda _scroll_beach
    sta _raster_scroll+4
    lda _scroll_water
    sta _raster_scroll+5
    ; Publish every band before the visible display, including on wraps.
    rts
_flight_scroll:
    lda shift_mask
    and #1
    beq :+
    jsr shift_jungle
:
    lda shift_mask
    and #2
    beq :+
    jsr shift_beach
:
    lda shift_mask
    and #4
    beq :+
    jsr shift_water
:
    lda _sample_left
    ora _sample_left+1
    bne @return
    lda _frame
    and #7
    bne @return
    php
    sei
    lda $01
    pha
    lda #$34
    sta $01
    ldx #7
    lda _frame
    and #8
    beq @closed
@open:
    lda _halloween_tiles+64,x
    sta $c480,x
    dex
    bpl @open
    bmi @done
@closed:
    lda _halloween_tiles+80,x
    sta $c480,x
    dex
    bpl @closed
@done:
    pla
    sta $01
    plp
@return:
    rts

shift_jungle:
    lda _flight_dir
    bpl :+
    jmp reverse_jungle
:
    ldx #0
:
    .repeat 13, I
        lda $cc79+I,x
        sta $cc78+I,x
    .endrepeat
    txa
    clc
    adc #13
    tax
    cpx #39
    beq :+
    jmp :-
:
    ldx _flight_offset+0
    lda _flight_map+0,x
    sta $cc9f
    lda _flight_colors+0,x
    sta $d89f
    inc _flight_offset+0
    lda _flight_offset+0
    cmp #80
    bcc :+
    lda #0
    sta _flight_offset+0
:
    ldx #0
:
    .repeat 13, I
        lda $cca1+I,x
        sta $cca0+I,x
    .endrepeat
    txa
    clc
    adc #13
    tax
    cpx #39
    beq :+
    jmp :-
:
    ldx _flight_offset+1
    lda _flight_map+80,x
    sta $ccc7
    lda _flight_colors+80,x
    sta $d8c7
    inc _flight_offset+1
    lda _flight_offset+1
    cmp #80
    bcc :+
    lda #0
    sta _flight_offset+1
:
    ldx #0
:
    .repeat 13, I
        lda $ccc9+I,x
        sta $ccc8+I,x
    .endrepeat
    txa
    clc
    adc #13
    tax
    cpx #39
    beq :+
    jmp :-
:
    ldx _flight_offset+2
    lda _flight_map+160,x
    sta $ccef
    lda _flight_colors+160,x
    sta $d8ef
    inc _flight_offset+2
    lda _flight_offset+2
    cmp #80
    bcc :+
    lda #0
    sta _flight_offset+2
:
    ldx #0
:
    .repeat 13, I
        lda $ccf1+I,x
        sta $ccf0+I,x
    .endrepeat
    txa
    clc
    adc #13
    tax
    cpx #39
    beq :+
    jmp :-
:
    ldx _flight_offset+3
    lda _flight_map+240,x
    sta $cd17
    lda _flight_colors+240,x
    sta $d917
    inc _flight_offset+3
    lda _flight_offset+3
    cmp #80
    bcc :+
    lda #0
    sta _flight_offset+3
:
    ldx #0
:
    .repeat 13, I
        lda $cd19+I,x
        sta $cd18+I,x
    .endrepeat
    txa
    clc
    adc #13
    tax
    cpx #39
    beq :+
    jmp :-
:
    ldx _flight_offset+4
    lda _flight_map+320,x
    sta $cd3f
    lda _flight_colors+320,x
    sta $d93f
    inc _flight_offset+4
    lda _flight_offset+4
    cmp #80
    bcc :+
    lda #0
    sta _flight_offset+4
:
    ldx #0
:
    .repeat 13, I
        lda $cd41+I,x
        sta $cd40+I,x
    .endrepeat
    txa
    clc
    adc #13
    tax
    cpx #39
    beq :+
    jmp :-
:
    ldx _flight_offset+5
    lda _flight_map+400,x
    sta $cd67
    lda _flight_colors+400,x
    sta $d967
    inc _flight_offset+5
    lda _flight_offset+5
    cmp #80
    bcc :+
    lda #0
    sta _flight_offset+5
:
    ldx #0
:
    .repeat 13, I
        lda $cd69+I,x
        sta $cd68+I,x
        lda $d969+I,x
        sta $d968+I,x
    .endrepeat
    txa
    clc
    adc #13
    tax
    cpx #39
    beq :+
    jmp :-
:
    ldx _flight_offset+6
    lda _flight_map+480,x
    sta $cd8f
    lda _flight_colors+480,x
    sta $d98f
    inc _flight_offset+6
    lda _flight_offset+6
    cmp #80
    bcc :+
    lda #0
    sta _flight_offset+6
:
    ldx #0
:
    .repeat 13, I
        lda $cd91+I,x
        sta $cd90+I,x
        lda $d991+I,x
        sta $d990+I,x
    .endrepeat
    txa
    clc
    adc #13
    tax
    cpx #39
    beq :+
    jmp :-
:
    ldx _flight_offset+7
    lda _flight_map+560,x
    sta $cdb7
    lda _flight_colors+560,x
    sta $d9b7
    inc _flight_offset+7
    lda _flight_offset+7
    cmp #80
    bcc :+
    lda #0
    sta _flight_offset+7
:
    ldx #0
:
    .repeat 13, I
        lda $cdb9+I,x
        sta $cdb8+I,x
        lda $d9b9+I,x
        sta $d9b8+I,x
    .endrepeat
    txa
    clc
    adc #13
    tax
    cpx #39
    beq :+
    jmp :-
:
    ldx _flight_offset+8
    lda _flight_map+640,x
    sta $cddf
    lda _flight_colors+640,x
    sta $d9df
    inc _flight_offset+8
    lda _flight_offset+8
    cmp #80
    bcc :+
    lda #0
    sta _flight_offset+8
:
    ldx #0
:
    .repeat 13, I
        lda $cde1+I,x
        sta $cde0+I,x
        lda $d9e1+I,x
        sta $d9e0+I,x
    .endrepeat
    txa
    clc
    adc #13
    tax
    cpx #39
    beq :+
    jmp :-
:
    ldx _flight_offset+9
    lda _flight_map+720,x
    sta $ce07
    lda _flight_colors+720,x
    sta $da07
    inc _flight_offset+9
    lda _flight_offset+9
    cmp #80
    bcc :+
    lda #0
    sta _flight_offset+9
:
    ldx #0
:
    .repeat 13, I
        lda $ce09+I,x
        sta $ce08+I,x
        lda $da09+I,x
        sta $da08+I,x
    .endrepeat
    txa
    clc
    adc #13
    tax
    cpx #39
    beq :+
    jmp :-
:
    ldx _flight_offset+10
    lda _flight_map+800,x
    sta $ce2f
    lda _flight_colors+800,x
    sta $da2f
    inc _flight_offset+10
    lda _flight_offset+10
    cmp #80
    bcc :+
    lda #0
    sta _flight_offset+10
:
    ldx #0
:
    .repeat 13, I
        lda $ce31+I,x
        sta $ce30+I,x
        lda $da31+I,x
        sta $da30+I,x
    .endrepeat
    txa
    clc
    adc #13
    tax
    cpx #39
    beq :+
    jmp :-
:
    ldx _flight_offset+11
    lda _flight_map+880,x
    sta $ce57
    lda _flight_colors+880,x
    sta $da57
    inc _flight_offset+11
    lda _flight_offset+11
    cmp #80
    bcc :+
    lda #0
    sta _flight_offset+11
:
    ldx #0
:
    .repeat 13, I
        lda $ce59+I,x
        sta $ce58+I,x
        lda $da59+I,x
        sta $da58+I,x
    .endrepeat
    txa
    clc
    adc #13
    tax
    cpx #39
    beq :+
    jmp :-
:
    ldx _flight_offset+12
    lda _flight_map+960,x
    sta $ce7f
    lda _flight_colors+960,x
    sta $da7f
    inc _flight_offset+12
    lda _flight_offset+12
    cmp #80
    bcc :+
    lda #0
    sta _flight_offset+12
:
    rts

shift_beach:
    lda _flight_dir
    bpl :+
    jmp reverse_beach
:
    lda $ce80
    sta edge_char
    lda $da80
    sta edge_color
    ldx #0
:
    .repeat 13, I
        lda $ce81+I,x
        sta $ce80+I,x
        lda $da81+I,x
        sta $da80+I,x
    .endrepeat
    txa
    clc
    adc #13
    tax
    cpx #39
    beq :+
    jmp :-
:
    lda edge_char
    sta $cea7
    lda edge_color
    sta $daa7
    lda $cea8
    sta edge_char
    lda $daa8
    sta edge_color
    ldx #0
:
    .repeat 13, I
        lda $cea9+I,x
        sta $cea8+I,x
        lda $daa9+I,x
        sta $daa8+I,x
    .endrepeat
    txa
    clc
    adc #13
    tax
    cpx #39
    beq :+
    jmp :-
:
    lda edge_char
    sta $cecf
    lda edge_color
    sta $dacf
    lda $ced0
    sta edge_char
    lda $dad0
    sta edge_color
    ldx #0
:
    .repeat 13, I
        lda $ced1+I,x
        sta $ced0+I,x
        lda $dad1+I,x
        sta $dad0+I,x
    .endrepeat
    txa
    clc
    adc #13
    tax
    cpx #39
    beq :+
    jmp :-
:
    lda edge_char
    sta $cef7
    lda edge_color
    sta $daf7
    rts

shift_water:
    lda _flight_dir
    bpl :+
    jmp reverse_water
:
    lda $cef8
    sta edge_char
    lda $daf8
    sta edge_color
    ldx #0
:
    .repeat 13, I
        lda $cef9+I,x
        sta $cef8+I,x
    .endrepeat
    txa
    clc
    adc #13
    tax
    cpx #39
    beq :+
    jmp :-
:
    lda edge_char
    sta $cf1f
    lda edge_color
    sta $db1f
    lda $cf20
    sta edge_char
    lda $db20
    sta edge_color
    ldx #0
:
    .repeat 13, I
        lda $cf21+I,x
        sta $cf20+I,x
    .endrepeat
    txa
    clc
    adc #13
    tax
    cpx #39
    beq :+
    jmp :-
:
    lda edge_char
    sta $cf47
    lda edge_color
    sta $db47
    lda $cf48
    sta edge_char
    lda $db48
    sta edge_color
    ldx #0
:
    .repeat 13, I
        lda $cf49+I,x
        sta $cf48+I,x
    .endrepeat
    txa
    clc
    adc #13
    tax
    cpx #39
    beq :+
    jmp :-
:
    lda edge_char
    sta $cf6f
    lda edge_color
    sta $db6f
    lda $cf70
    sta edge_char
    lda $db70
    sta edge_color
    ldx #0
:
    .repeat 13, I
        lda $cf71+I,x
        sta $cf70+I,x
    .endrepeat
    txa
    clc
    adc #13
    tax
    cpx #39
    beq :+
    jmp :-
:
    lda edge_char
    sta $cf97
    lda edge_color
    sta $db97
    lda $cf98
    sta edge_char
    lda $db98
    sta edge_color
    ldx #0
:
    .repeat 13, I
        lda $cf99+I,x
        sta $cf98+I,x
    .endrepeat
    txa
    clc
    adc #13
    tax
    cpx #39
    beq :+
    jmp :-
:
    lda edge_char
    sta $cfbf
    lda edge_color
    sta $dbbf
    rts


.segment "RODATA"
; Flight-only copies may be replaced by the victory music after landing.
reverse_jungle:
.repeat 13,I
 jsr .ident(.sprintf("fast_row_%d",I+3))
 ldx _flight_offset+I
 dex
 bpl :+
 ldx #79
:
 stx _flight_offset+I
 txa
 sec
 sbc #40
 bcs :+
 adc #80
:
 tax
 lda _flight_map+I*80,x
 sta $cc78+I*40
 lda _flight_colors+I*80,x
 sta $d878+I*40
.endrepeat
 rts
reverse_beach:
 lda #16
 sta reverse_row
 lda #19
 bne reverse_ring
reverse_water:
 lda #19
 sta reverse_row
 lda #24
reverse_ring:
 sta reverse_end
@each:
 jsr reverse_copy
 jsr reverse_edge
 inc reverse_row
 lda reverse_row
 cmp reverse_end
 bcc @each
 rts
reverse_copy:
 ldx reverse_row
 lda row_lo,x
 sta rload+1
 sta rstore+1
 sta cload+1
 sta cstore+1
 sta redge+1
 sta cedge+1
 inc rstore+1
 inc cstore+1
 lda row_hi,x
 sta rload+2
 sta rstore+2
 sta redge+2
 clc
 adc #12
 sta cload+2
 sta cstore+2
 sta cedge+2
reverse_coloured:
 ldx #39
 jsr rread
 sta edge_char
 jsr cread
 sta edge_color
 lda reverse_row
 cmp #19
 bcs reverse_plain
 ldx #38
reverse_loop:
rload: lda $ffff,x
rstore: sta $ffff,x
cload: lda $ffff,x
cstore: sta $ffff,x
 dex
 bpl reverse_loop
 rts
reverse_plain:
 ; Sea rows share one colour. Only the glyph phase moves each frame.
 lda rload+1
 sta plain_load+1
 lda rload+2
 sta plain_load+2
 lda rstore+1
 sta plain_store+1
 lda rstore+2
 sta plain_store+2
 ldx #38
reverse_plain_loop:
plain_load: lda $ffff,x
plain_store: sta $ffff,x
 dex
 bpl reverse_plain_loop
 rts
rread:
 lda rload+1
 sta rfetch+1
 lda rload+2
 sta rfetch+2
rfetch: lda $ffff,x
 rts
cread:
 lda cload+1
 sta cfetch+1
 lda cload+2
 sta cfetch+2
cfetch: lda $ffff,x
 rts
reverse_edge:
 lda edge_char
redge: sta $ffff
 lda edge_color
cedge: sta $ffff
 rts
.segment "RODATA"
forest_source_lo: .repeat 13,I
 .byte <(_flight_map+I*80)
.endrepeat
forest_source_hi: .repeat 13,I
 .byte >(_flight_map+I*80)
.endrepeat
forest_color_lo: .repeat 13,I
 .byte <(_flight_colors+I*80)
.endrepeat
forest_color_hi: .repeat 13,I
 .byte >(_flight_colors+I*80)
.endrepeat
row_lo: .repeat 24,I
 .byte <($cc00+I*40)
.endrepeat
row_hi: .repeat 24,I
 .byte >($cc00+I*40)
.endrepeat
.segment "BSS"
reverse_row: .res 1
reverse_end: .res 1
reverse_index: .res 1
reverse_column: .res 1
.segment "CODE"
.segment "BSS"
edge_char: .res 1
edge_color: .res 1
shift_mask: .res 1



.export _wait_frame,_video_tick
.segment "BSS"
_video_tick: .res 1
wait_tick: .res 1
.segment "CODE"
_wait_frame:
    lda _stage
    cmp #1
    bne @tick
    lda $d011
    bmi @tick
    lda $d012
    cmp #16
    bcc @tick
    lda _video_tick
    sta wait_tick
@tick:
    lda _video_tick
    cmp wait_tick
    beq @tick
    sta wait_tick
    inc _frame
    bne :+
    inc _frame+1
:
    rts


.import _input,_can_land

.import _landing_state

.segment "CODE"
; The upper six forest rows have a uniform colour. Unroll their reverse
; character copies too, giving the final forest row time before its fetch
; even with two full-height multiplexed beach walkers.
.repeat 6, R
 .ident(.sprintf("fast_row_%d", R+3)):
 ldx #26
 .ident(.sprintf("fast_sky_loop_%d", R)):
 .repeat 13,I
  lda $cc00+(R+3)*40+12-I,x
  sta $cc00+(R+3)*40+13-I,x
 .endrepeat
 txa
 sec
 sbc #13
 tax
 jpl .ident(.sprintf("fast_sky_loop_%d", R))
 rts
.endrepeat
fast_row_9:
 ldx #26
@block:
 .repeat 13,I
  lda $cd74-I,x
  sta $cd75-I,x
  lda $d974-I,x
  sta $d975-I,x
 .endrepeat
 txa
 sec
 sbc #13
 tax
 jpl @block
 rts
fast_row_10:
 ldx #26
@block:
 .repeat 13,I
  lda $cd9c-I,x
  sta $cd9d-I,x
  lda $d99c-I,x
  sta $d99d-I,x
 .endrepeat
 txa
 sec
 sbc #13
 tax
 jpl @block
 rts
fast_row_11:
 ldx #26
@block:
 .repeat 13,I
  lda $cdc4-I,x
  sta $cdc5-I,x
  lda $d9c4-I,x
  sta $d9c5-I,x
 .endrepeat
 txa
 sec
 sbc #13
 tax
 jpl @block
 rts
fast_row_12:
 ldx #26
@block:
 .repeat 13,I
  lda $cdec-I,x
  sta $cded-I,x
  lda $d9ec-I,x
  sta $d9ed-I,x
 .endrepeat
 txa
 sec
 sbc #13
 tax
 jpl @block
 rts
fast_row_13:
 ldx #26
@block:
 .repeat 13,I
  lda $ce14-I,x
  sta $ce15-I,x
  lda $da14-I,x
  sta $da15-I,x
 .endrepeat
 txa
 sec
 sbc #13
 tax
 jpl @block
 rts
fast_row_14:
 ldx #26
@block:
 .repeat 13,I
  lda $ce3c-I,x
  sta $ce3d-I,x
  lda $da3c-I,x
  sta $da3d-I,x
 .endrepeat
 txa
 sec
 sbc #13
 tax
 jpl @block
 rts
fast_row_15:
 ldx #26
@block:
 .repeat 13,I
  lda $ce64-I,x
  sta $ce65-I,x
  lda $da64-I,x
  sta $da65-I,x
 .endrepeat
 txa
 sec
 sbc #13
 tax
 jpl @block
 rts

.segment "RODATA"
fast_lo: .byte <fast_row_3,<fast_row_4,<fast_row_5,<fast_row_6,<fast_row_7,<fast_row_8,<fast_row_9,<fast_row_10,<fast_row_11,<fast_row_12,<fast_row_13,<fast_row_14,<fast_row_15
fast_hi: .byte >fast_row_3,>fast_row_4,>fast_row_5,>fast_row_6,>fast_row_7,>fast_row_8,>fast_row_9,>fast_row_10,>fast_row_11,>fast_row_12,>fast_row_13,>fast_row_14,>fast_row_15

.import _stage
