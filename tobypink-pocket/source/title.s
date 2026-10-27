; Standalone, hand-written 6510 bitmap title and disk loader.
; D64's first file is this title; FIRE loads TOBY PINK and starts the game.
.setcpu "6502"
.segment "LOADADDR"
    .word $0801
.segment "CODE"
    .word $080b,2026
    .byte $9e,"2061",0
    .word 0
.export title_entry, title_wait, loader_stub, title_irq, title_phase, title_ticks, title_start
title_entry:
    sei
    lda #$37
    sta $01
    lda #0
    sta $d011
    sta $d015
    sta $d020
    sta $d021
    lda $dd02
    ora #3
    sta $dd02
    lda $dd00
    and #$fc
    sta $dd00
    ; Decompress the hardware bitmap under KERNAL ROM.
    lda #<bitmap_data
    ldx #>bitmap_data
    sta $fb
    stx $fc
    lda #<$e000
    ldx #>$e000
    sta $fd
    stx $fe
    lda #<8000
    ldx #>8000
    jsr unpack
    lda #<screen_data
    ldx #>screen_data
    sta $fb
    stx $fc
    lda #<$cc00
    ldx #>$cc00
    sta $fd
    stx $fe
    lda #<1000
    ldx #>1000
    jsr unpack
    lda #<color_data
    ldx #>color_data
    sta $fb
    stx $fc
    lda #<$d800
    ldx #>$d800
    sta $fd
    stx $fe
    lda #<1000
    ldx #>1000
    jsr unpack
    lda #$38
    sta $d018
    lda #$18
    sta $d016
    lda #$3b
    sta $d011
    jsr title_music_setup
title_wait:
    lda #0
    sta $dc02
    lda $dc00
    and #16
    beq title_start
    lda #$ff
    sta $dc02
    lda #$7f
    sta $dc00
    lda $dc01
    and #16
    bne title_wait
title_start:
    sei
    lda #0
    sta $d01a
    sta $d015
    lda #1
    sta $d019
    lda #0
    sta $d404
    sta $d40b
    sta $d412
    sta $d424
    sta $d42b
    sta $d432
    lda #$3b
    sta $d011
    lda #$38
    sta $d018
    lda #$18
    sta $d016
    lda #$81
    sta $dc0d
    ; Restore CIA directions for KERNAL disk loading. The portrait remains
    ; visible throughout loading; the game installs its own video state.
    lda #$ff
    sta $dc00
    sta $dc02
    lda #$37
    sta $01
    ldx #loader_end-loader_stub-1
copy_loader:
    lda loader_stub,x
    sta $c000,x
    dex
    bpl copy_loader
    cli
    jmp $c000

; A/X = uncompressed length; $fb source, $fd destination.
unpack:
    sta remaining
    stx remaining+1
next_packet:
    jsr getbyte
    pha
    and #127
    clc
    adc #1
    sta packet_count
    pla
    bmi repeat_packet
literal_packet:
    jsr getbyte
    jsr putbyte
    dec packet_count
    bne literal_packet
    jmp packet_done
repeat_packet:
    jsr getbyte
    sta repeated_byte
repeat_loop:
    lda repeated_byte
    jsr putbyte
    dec packet_count
    bne repeat_loop
packet_done:
    lda remaining
    ora remaining+1
    bne next_packet
    rts
getbyte:
    ldy #0
    lda ($fb),y
    inc $fb
    bne :+
    inc $fc
:
    rts
putbyte:
    ldy #0
    sta ($fd),y
    inc $fd
    bne :+
    inc $fe
:
    lda remaining
    bne :+
    dec remaining+1
:
    dec remaining
    rts
remaining: .word 0
packet_count: .byte 0
repeated_byte: .byte 0


; Authentic Jupiter Fracture title tune (Tufan Uysal / SoNiC).
; Unpack the portrait first; this copy may overwrite the packed art.
title_music_setup:
    lda #<music_data
    sta $fb
    lda #>music_data
    sta $fc
    lda #0
    sta $fd
    lda #$10
    sta $fe
    ldx #44
    ldy #0
@copy:
    lda ($fb),y
    sta ($fd),y
    iny
    bne @copy
    inc $fc
    inc $fe
    dex
    bne @copy
    ; Only 64 ROM characters, so the font cannot overlap screen $cc00.
    lda #$31
    sta $01
    ldx #0
@font:
    lda title_ui_font,x
    sta $c800,x
    lda title_ui_font+256,x
    sta $c900,x
    inx
    bne @font
    lda #$35
    sta $01
    lda #$7f
    sta $dc0d
    sta $dd0d
    lda $dc0d
    lda $dd0d
    lda #$34
    sta $01
    ldx #0
    lda #0
@sprites:
    sta $d000,x
    sta $d100,x
    inx
    bne @sprites
    ldx #0
@detail_copy:
    lda title_detail_data,x
    sta $c400,x
    inx
    bne @detail_copy
    lda #$35
    sta $01
    lda #0
    sta $d01c
    sta $d017
    sta $d01d
    sta $d01b
    lda #$80
    sta $d010
    jsr title_footer_sprites
    lda #0
    sta title_ticks
    sta title_ticks+1
    sta title_split
    sta title_phase
    sta title_text_pos
    jsr $1000
    lda #<title_irq
    sta $fffe
    lda #>title_irq
    sta $ffff
    lda #254
    sta $d012
    lda #1
    sta $d019
    sta $d01a
    cli
    rts
title_irq:
    pha
    txa
    pha
    tya
    pha
    lda #1
    sta $d019
    inc title_ticks
    bne :+
    inc title_ticks+1
:
    ldx title_text_pos
    lda title_text,x
    asl
    asl
    asl
    sta ticker_glyph+1
    lda #$c8
    adc #0
    sta ticker_glyph+2
    ldx title_phase
    lda ticker_masks,x
    sta ticker_mask
    lda #$34
    sta $01
    ldy #0
    ldx #0
ticker_row:
ticker_glyph:
    lda $c800,y
    and ticker_mask
    cmp #1
    .repeat 8,S
        .repeat 3,B
            rol $d000+(7-S)*64+(2-B),x
        .endrepeat
    .endrepeat
    inx
    inx
    inx
    iny
    cpy #8
    beq :+
    jmp ticker_row
:
    lda #$35
    sta $01
    inc title_phase
    lda title_phase
    and #7
    sta title_phase
    bne ticker_music
    inc title_text_pos
    ldx title_text_pos
    lda title_text,x
    bne ticker_music
    lda #0
    sta title_text_pos
ticker_music:
    jsr $1003
    lda title_ticks
    and #32
    beq :+
    lda #$44
    bne :++
:
    lda #$aa
:
    ldx #39
ticker_prompt:
    sta $cf98,x
    dex
    bpl ticker_prompt
ticker_exit:
    lda #<title_detail_irq
    sta $fffe
    lda #>title_detail_irq
    sta $ffff
    lda #80
    sta $d012
    pla
    tay
    pla
    tax
    pla
    rti
ticker_x: .byte 88,112,136,160,184,208,232,0
ticker_masks: .byte 128,64,32,16,8,4,2,1
ticker_mask: .byte 0
.export title_text_pos,ticker_glyph,title_text
title_phase: .byte 0
title_split: .byte 0
title_ticks: .word 0
title_text_pos: .byte 0
title_text:
    .byte 32,32,32,32,32,20,15,2,25,32,20,18,25,32,20,15,32,19,1,22,5,32,20,8,5,32,16,9,14,11,32,46,46,46,32,19,1,22,5,32,1,12,12,32,53,32,3,18,25,19,20,1,12,19,32,1,14,4,32,23,9,14,32,25,15,21,18,32,16,9,14,11,32,1,13,9,7,1,32,52,48,48,48,33,32,46,46,46,32,13,21,19,9,3,58,32,20,21,6,1,14,32,21,25,19,1,12,32,47,32,19,15,14,9,3,32,46,46,46,32,16,18,5,19,19,32,6,9,18,5,32,20,15,32,19,20,1,18,20,32,46,46,46,32,32,32,32,32,0

; All internal branches are relative: this block runs safely from $c000
; while the following KERNAL LOAD replaces the program at $0801.
loader_stub:
    lda #9
    ldx #<game_filename
    ldy #>game_filename
    jsr $ffbd
    lda #1
    ldx #8
    ldy #1
    jsr $ffba
    lda #0
    ldx #0
    ldy #0
    jsr $ffd5
    bcs disk_error
    jmp $080d
disk_error:
    inc $d020
    bne disk_error
    beq disk_error
loader_end:
; c1541's uppercase directory names use shifted PETSCII, not ASCII.
game_filename: .byte $d4,$cf,$c2,$d9,$20,$d0,$c9,$ce,$cb
bitmap_data: .incbin "title-bitmap.rle"
screen_data: .incbin "title-screen.rle"
color_data: .incbin "title-color.rle"

music_data: .incbin "jupiter-title-music.bin"


title_footer_sprites:
    lda #$80
    sta $d010
    ldx #7
@setup:
    txa
    clc
    adc #64
    sta $cff8,x
    lda #10
    sta $d027,x
    txa
    asl
    tay
    lda ticker_x,x
    sta $d000,y
    lda #242
    sta $d001,y
    dex
    bpl @setup
    lda #255
    sta $d015
    rts
title_detail_irq:
    pha
    txa
    pha
    tya
    pha
    lda #1
    sta $d019
    lda #0
    sta $d010
    ldx #3
@detail:
    txa
    clc
    adc #16
    sta $cff8,x
    lda title_detail_colors,x
    sta $d027,x
    txa
    asl
    tay
    lda title_detail_x,x
    sta $d000,y
    lda title_detail_y,x
    sta $d001,y
    dex
    bpl @detail
    lda #15
    sta $d015
    lda #<title_footer_irq
    sta $fffe
    lda #>title_footer_irq
    sta $ffff
    lda #218
    sta $d012
    jmp title_detail_done
title_footer_irq:
    pha
    txa
    pha
    tya
    pha
    lda #1
    sta $d019
    jsr title_footer_sprites
    lda #<title_irq
    sta $fffe
    lda #>title_irq
    sta $ffff
    lda #254
    sta $d012
title_detail_done:
    pla
    tay
    pla
    tax
    pla
    rti
title_detail_x: .byte 160,184,164,188
title_detail_y: .byte 94,94,110,110
title_detail_colors: .byte 15,15,0,0
title_detail_data: .incbin "title-detail-sprites.bin"
.export title_detail_irq,title_footer_irq

title_ui_font: .incbin "ui-font.bin"
