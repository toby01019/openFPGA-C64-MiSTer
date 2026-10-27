.macpack longbranch
; Fast native screen cell writer, with the flight's own sand and surf tiles.
.export _cell
.import _stage,incsp3
.importzp c_sp,ptr1,ptr2
.segment "BSS"
cell_ch: .res 1
cell_color: .res 1
cell_at: .res 2
.segment "CODE"
_cell:
    sta cell_color
    ldy #0
    lda (c_sp),y
    sta cell_ch
    iny
    lda (c_sp),y
    sta cell_at
    iny
    lda (c_sp),y
    sta cell_at+1
    lda _stage
    cmp #1
    jne store
    lda cell_ch
    cmp #144
    bne :+
    lda #4
    sta cell_color
:
    ; Leave the title, HUD, forest and pink pumpkins untouched.
    lda cell_ch
    cmp #$8c
    bcs check_range
    lda cell_color
    cmp #10
    jeq store
check_range:
    lda cell_at
    cmp #<640
    lda cell_at+1
    sbc #>640
    jcc store
    lda cell_at
    cmp #<960
    lda cell_at+1
    sbc #>960
    jcs store
    ; Native full-width art rather than a repeated four-character pattern.
    ; Called only at scene setup; scrolling keeps its existing fast copies.
    lda cell_at
    clc
    adc #<(coast_cells-640)
    sta ptr1
    lda cell_at+1
    adc #>(coast_cells-640)
    sta ptr1+1
    ldy #0
    lda (ptr1),y
    sta cell_ch
    clc
    lda ptr1
    adc #<320
    sta ptr1
    lda ptr1+1
    adc #>320
    sta ptr1+1
    lda (ptr1),y
    sta cell_color
store:
    lda cell_at
    sta ptr1
    sta ptr2
    lda cell_at+1
    clc
    adc #$cc
    sta ptr1+1
    clc
    adc #12
    sta ptr2+1
    ldy #0
    lda cell_ch
    sta (ptr1),y
    lda cell_color
    sta (ptr2),y
    jmp incsp3
.segment "RODATA"
coast_cells: .incbin "coast-map.bin"
