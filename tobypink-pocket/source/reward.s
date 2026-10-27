.importzp ptr1,ptr2
.import _unpack_assets
.export _reward_room,_reward_tick
.import _load_world_font,_cave_background,_draw_page,_spr_enabled,_spr_multi,_spr_high,_spr_x,_spr_y,_spr_color,_spr_image,_frame
.segment "CODE"
_reward_room:
 sei
 lda #0
 sta _bubble_drawn
 sta _sprite_ready
 sta reward_age
 sta reward_music_ready
 sta _reward_scene_ready
 sta $d015
 sta $d01a
 sta $dd0e
 sta $dd0f
 lda #$7f
 sta $dc0d
 sta $dd0d
 lda $dc0d
 lda $dd0d
 lda $d011
 and #$6f
 sta $d011
 lda #$37
 sta $01
 lda #11
 ldx #<scene_filename
 ldy #>scene_filename
 jsr $ffbd
 lda #1
 ldx #8
 ldy #1
 jsr $ffba
 lda #0
 jsr $ffd5
 php
 lda #$35
 sta $01
 plp
 bcs @fallback
 ; Decompress the matrix to RAM beneath I/O, then the bitmap to E000.
 ; The packed disk file stays entirely below D000 and cannot write I/O.
 lda #$34
 sta $01
 lda #0
 sta ptr1
 sta ptr2
 lda #$c0
 sta ptr1+1
 lda #$d0
 sta ptr2+1
 jsr _unpack_assets
 lda #0
 sta ptr2
 lda #$e0
 sta ptr2+1
 jsr _unpack_assets
 ldx #0
@matrix:
 lda $d000,x
 sta $cc00,x
 lda $d100,x
 sta $cd00,x
 lda $d200,x
 sta $ce00,x
 lda $d2e8,x
 sta $cee8,x
 inx
 bne @matrix
 lda #$35
 sta $01
 lda #1
 sta _reward_scene_ready
 jmp @ready
@fallback:
 jsr _load_world_font
 jsr _cave_background
@ready:
 lda #<_raster_irq
 sta $fffe
 lda #>_raster_irq
 sta $ffff
 ldx #127
@bats:
 lda reward_bats,x
 ldy _reward_scene_ready
 beq @fallbackbat
 sta $c000,x
 jmp @batcopied
@fallbackbat:
 sta $e800,x
@batcopied:
 dex
 bpl @bats
 lda #7
 sta _raster_band
 lda #254
 sta $d012
 lda #1
 sta $d019
 sta $d01a
 jsr reward_mode
 sta $d018
 lda #8
 sta $d016
 lda #0
 sta $d021
 lda $d011
 and #$5f
 ora #16
 ldx _reward_scene_ready
 beq :+
 ora #32
:
 sta $d011
 cli
 rts
scene_filename: .byte $d4,$cf,$c2,$d9,32,$d2,$c5,$d7,$c1,$d2,$c4
_reward_tick:
 lda reward_age
 cmp #60
 bcc :+
 jmp reward_music_start
:
 inc reward_age
reward_bat_tick:
 ldx _draw_page
 lda #$c0
 sta _spr_enabled,x
 lda #0
 sta _spr_multi,x
 sta _spr_high,x
 txa
 asl
 asl
 asl
 tax
 lda _frame
 and #127
 cmp #64
 bcc :+
 eor #127
:
 asl
 clc
 adc #40
 sta _spr_x+6,x
 lda #24
 sec
 sbc _spr_x+6,x
 sta _spr_x+7,x
 lda _frame
 lsr
 and #15
 tay
 lda reward_wave,y
 sta _spr_y+6,x
 clc
 adc #7
 sta _spr_y+7,x
 lda _frame
 lsr
 lsr
 and #1
 clc
 ldy _reward_scene_ready
 bne :+
 clc
 adc #160
:
 sta _spr_image+6,x
 eor #1
 sta _spr_image+7,x
 lda #15
 sta _spr_color+6,x
 lda #10
 sta _spr_color+7,x
 rts
.segment "CODE"
reward_wave: .byte 101,103,105,107,108,107,105,103,101,99,97,95,94,95,97,99
reward_bats: .incbin "reward-bats.bin"

reward_lo: .byte 69,118,88,177,232,26,253,83,146,35,205,55
reward_hi: .byte 205,205,205,205,205,206,205,206,205,205,205,205

.export _reward_music_irq
.import _controls,_wait_frame,_publish_sprites,_raster_irq,_raster_nmi,_raster_body,_raster_exit,_raster_band,_sprite_ready
.segment "BSS"
reward_age: .res 1
reward_music_ready: .res 1
_reward_music_ticks: .res 2
replay_latch: .res 1
.segment "CODE"
reward_music_start:
 sei
 ; Keep the same complete room while disk I/O pauses the raster IRQ.
 jsr reward_mode
 sta $d018
 lda #8
 sta $d016
 lda #0
 sta $d01a
 sta $dd0e
 sta $dd0f
 lda #$7f
 sta $dc0d
 sta $dd0d
 lda $dc0d
 lda $dd0d
 lda #$ff
 sta $dc00
 sta $dc02
 lda #$37
 sta $01
 ; KERNAL loading messages share colour RAM with our custom screen. Silence
 ; them so SEARCHING/LOADING cannot recolour the visible reward room.
 lda #0
 jsr $ff90
 lda #10
 ldx #<reward_filename
 ldy #>reward_filename
 jsr $ffbd
 lda #1
 ldx #8
 ldy #1
 jsr $ffba
 lda #0
 jsr $ffd5
 bcs @failed
 lda #$35
 sta $01
 lda #0
 tax
 tay
 jsr $a9b7
 lda #1
 sta reward_music_ready
@failed:
 lda #$35
 sta $01
 lda #$7f
 sta $dc0d
 lda $dc0d
 lda #<reward_irq
 sta $fffe
 lda #>reward_irq
 sta $ffff
 lda #<_raster_nmi
 sta $fffa
 lda #>_raster_nmi
 sta $fffb
 lda #7
 sta _raster_band
 lda #254
 sta $d012
 lda #1
 sta $d019
 sta $d01a
 lda reward_music_ready
 beq :+
 lda #$81
 sta $dc0d
 lda #$11
 sta $dc0e
:
 cli
 lda #1
 sta replay_latch
reward_loop:
 jsr _wait_frame
 jsr _controls
 and #16
 beq @released
 lda replay_latch
 beq reward_replay
 bne @animate
@released:
 sta replay_latch
@animate:
 inc _frame
 bne :+
 inc _frame+1
:
 jsr reward_bat_tick
 jsr _publish_sprites
 jmp reward_loop
reward_irq:
 pha
 txa
 pha
 tya
 pha
 lda $d019
 and #1
 bne @video
 jsr _reward_music_irq
 jmp _raster_exit
@video:
 jmp _raster_body
_reward_music_irq:
 lda $dc0d
 lda reward_music_ready
 beq @nomusic
 inc _reward_music_ticks
 bne :+
 inc _reward_music_ticks+1
:
 jsr $a900
@nomusic:
 rts
reward_replay:
 sei
 lda #0
 sta $d01a
 sta $d015
 sta $dc0e
 sta $d404
 sta $d40b
 sta $d412
 lda #$7f
 sta $dc0d
 lda $dc0d
 lda #$ff
 sta $dc00
 sta $dc02
 lda #$37
 sta $01
 ldx #replay_end-replay_stub-1
@copy:
 lda replay_stub,x
 sta $c800,x
 dex
 bpl @copy
 jmp $c800
replay_stub:
 lda #9
 ldx #<replay_filename
 ldy #>replay_filename
 jsr $ffbd
 lda #1
 ldx #8
 ldy #1
 jsr $ffba
 lda #0
 jsr $ffd5
 bcs @error
 jmp $080d
@error:
 inc $d020
 bne @error
 beq @error
replay_end:
.segment "CODE"
reward_filename: .byte $d4,$cf,$c2,$d9,$20,$cd,$d5,$d3,$c9,$c3
replay_filename: .byte $d4,$cf,$c2,$d9,$20,$d0,$c9,$ce,$cb

.export _reward_loop,_reward_music_ready
_reward_loop = reward_loop
_reward_music_ready = reward_music_ready

.export _reward_music_ticks

.import _bubble_drawn

.import __ONCE_RUN__,__ONCE_SIZE__,__BSS_RUN__
.assert __ONCE_RUN__+__ONCE_SIZE__ <= __BSS_RUN__, lderror, "Program data overlaps reserved game state"

.export _reward_scene_ready
.segment "BSS"
_reward_scene_ready: .res 1
.segment "CODE"
reward_mode:
 lda _reward_scene_ready
 beq :+
 lda #$38
 rts
:
 lda #$30
 rts
