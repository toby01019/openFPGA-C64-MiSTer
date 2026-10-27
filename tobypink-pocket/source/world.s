.export _cave_background
.import _forest_map
.importzp ptr1,ptr2,ptr3,tmp1
.segment "RODATA"
.include "world-dictionary.inc"
.segment "CODE"
_cave_background:
    lda #<_forest_map_data
    sta ptr1
    lda #>_forest_map_data
    sta ptr1+1
    lda #0
    sta ptr2
    lda #$c8
    sta ptr2+1
    jsr _unpack_assets
    lda #<(_forest_map+120)
    sta ptr1
    lda #>(_forest_map+120)
    sta ptr1+1
    lda #$78
    sta ptr2
    sta ptr3
    lda #$cc
    sta ptr2+1
    lda #$d8
    sta ptr3+1
    lda #3
    sta tmp1
    ldy #0
@page:
    jsr cell
    iny
    bne @page
    inc ptr1+1
    inc ptr2+1
    inc ptr3+1
    dec tmp1
    bne @page
@tail:
    jsr cell
    iny
    cpy #32
    bne @tail
    rts
cell:
    lda (ptr1),y
    pha
    and #31
    tax
    lda world_chars,x
    sta (ptr2),y
    pla
    lsr
    lsr
    lsr
    lsr
    lsr
    tax
    lda world_colors,x
    sta (ptr3),y
    rts

; Small entrance at the real bottom-left exit. Cached with the scenery,
; so janitor cleanup and temporary overlays restore the doorway as well.
.export _cave_exit_art
_cave_exit_art:
    ldx #0
@cell:
    lda exit_chars,x
    ldy exit_offsets,x
    sta $ced1,y
    lda exit_colors,x
    sta $dad1,y
    inx
    cpx #15
    bcc @cell
    rts
.segment "RODATA"
exit_chars: .byte 85,86,87,88,89,90,91,32,92,91,32,92,93,94,95
exit_offsets: .byte 0,1,2,40,41,42,80,81,82,120,121,122,160,161,162
exit_colors: .byte 10,10,10,12,15,12,12,0,12,12,0,12,12,10,12

.import _unpack_assets,_forest_map_data
