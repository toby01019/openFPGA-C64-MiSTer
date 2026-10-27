; Native bounded LZ decoder; output E000..FE7F stays below IRQ vectors.
.export _load_sprites,_load_walk
.import _sprite_data
.import _foes_reset
.importzp ptr1,ptr2,ptr3,tmp1,tmp2
.segment "CODE"
_load_sprites:
 jsr _foes_reset
 lda #<_sprite_data
 sta ptr1
 lda #>_sprite_data
 sta ptr1+1
 lda #0
 sta ptr2
 lda #$e0
 sta ptr2+1
.export _unpack_assets
_unpack_assets:
decode:
 ldy #0
@block:
 jsr fetch
 beq @done
 bmi @match
 sta tmp1
@literal:
 jsr fetch
 jsr write
 dec tmp1
 bne @literal
 beq @block
@match:
 and #127
 clc
 adc #3
 sta tmp1
 jsr fetch
 sta tmp2
 jsr fetch
 sta ptr3+1
 sec
 lda ptr2
 sbc tmp2
 sta ptr3
 lda ptr2+1
 sbc ptr3+1
 sta ptr3+1
@copy:
 lda (ptr3),y
 jsr write
 inc ptr3
 bne :+
 inc ptr3+1
:
 dec tmp1
 bne @copy
 beq @block
@done:
 rts
fetch:
 lda (ptr1),y
 inc ptr1
 bne :+
 inc ptr1+1
:
 ora #0
 rts
write:
 sta (ptr2),y
 inc ptr2
 bne :+
 inc ptr2+1
:
 rts

_load_walk:
 lda #<packed_walk
 sta ptr1
 lda #>packed_walk
 sta ptr1+1
 lda #0
 sta ptr2
 lda #$f4
 sta ptr2+1
 jsr decode
 ldy #15
 lda #0
:
 sta $fc30,y
 dey
 bpl :-
 rts
.segment "RODATA"
packed_walk: .incbin "walk-planes.pak"

.export _load_flight_background
.import _base_screen
.segment "CODE"
_load_flight_background:
 lda #<flight_background
 sta ptr1
 lda #>flight_background
 sta ptr1+1
 lda #<_base_screen
 sta ptr2
 lda #>_base_screen
 sta ptr2+1
 jmp decode
.segment "RODATA"
flight_background: .incbin "flight-background.pak"
