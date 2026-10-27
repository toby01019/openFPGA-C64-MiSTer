; Native 6510 raster split: stable HUD, then jungle, beach, sea, stable footer.
; The game uses no KERNAL services after installing the direct RAM IRQ vector.
; This handler saves all registers and never touches the game software stack.
.export _raster_irq, _raster_nmi
.export _raster_exit,_video_commit
.import _video_tick
.import _sample_nmi
.import _destination
.import _reward_scene_ready
.import _stage, _raster_band, _raster_count
.import _scroll_jungle, _scroll_beach, _scroll_water
.import _raster_scroll
.import _sprite_ready, _pending_page, _spr_x, _spr_y, _spr_image, _spr_color
.import _spr_high, _spr_enabled, _spr_multi
.segment "CODE"

_raster_nmi:
    jmp _sample_nmi

_raster_irq:
    pha
    txa
    pha
    tya
    pha
_raster_body:
    ; On PAL, set font after the previous line's graphics fetch, then set
    ; scroll before the following badline. Both precede variable IRQ work.
    ldx _raster_band
    lda _stage
    cmp #1
    beq flightfast
    cmp #3
    beq coastfast
    cmp #4
    beq rewardfast
    jmp platformfast
flightfast:
    ; Fine scroll must precede the next badline's fetch. Publishing it
    ; after background/font writes could cross that fetch on PAL.
    lda _raster_scroll,x
    sta $d016
    jmp coastcolors
coastfast:
    lda _raster_scroll,x
    sta $d016
coastcolors:
    lda beach_background,x
    sta $d021
    lda #$30
    sta $d018
    jmp nofastsplit
rewardfast:
    lda #0
    sta $d021
    lda _reward_scene_ready
    beq :+
    lda #$38
    bne :++
:
    lda #$30
:
    sta $d018
    lda #8
    sta $d016
    jmp nofastsplit
platformfast:
    lda #0
    sta $d021
    .repeat 5
        nop
    .endrepeat
    cpx #0
    beq platformworld
    lda #$34
    sta $d018
    lda #8
    sta $d016
    jmp nofastsplit
platformworld:
    lda #$30
    sta $d018
    lda #8
    sta $d016
nofastsplit:
    lda #1
    sta $d019
    inc _raster_count
    bne :+
    inc _raster_count+1
:
    lda _raster_band
    cmp #7
    bne checkstage
    jmp commit
checkstage:
    lda _stage
    cmp #4
    bne :+
    lda #254
    sta _scene_irq_line
    lda #7
    sta _raster_band
    jmp done
:
    lda _stage
    cmp #3
    beq shore
    cmp #1
    beq flight
    lda _raster_band
    beq world_band
    lda #8
    sta $d016
    lda #$34
    sta $d018
    lda #254
    sta _scene_irq_line
    lda #7
    sta _raster_band
    jmp done
world_band:
    lda #8
    sta $d016
    lda #$30
    sta $d018
    lda #242
    sta _scene_irq_line
    lda #6
    sta _raster_band
    jmp done
shore:
flight:
    ldx _raster_band
    bne :+
    ; The whole forest uses one charset, background and fine-scroll phase.
    ; Three redundant forest IRQs consumed the final row's copy budget.
    lda #178
    sta _scene_irq_line
    lda #4
    sta _raster_band
    jmp done
:
    lda shorelines,x
    sta _scene_irq_line
    inc _raster_band
    jmp done
done:
_raster_exit = done
    jsr _foes_schedule
    pla
    tay
    pla
    tax
    pla
    rti

commit:
_video_commit = commit
    lda #15
    sta $d025
    lda #0
    sta $d021
    inc _video_tick
    lda #8
    sta $d016
    lda _stage
    cmp #4
    bne @notreward
    lda _reward_scene_ready
    beq @rewardfallback
    lda #$38
    bne @mode_ready
@rewardfallback:
    lda #$30
    bne @mode_ready
@notreward:
    cmp #3
    beq :+
    cmp #1
    beq :+
    lda #$34
    bne :++
:
    lda #$30
:
@mode_ready:
    sta $d018
    lda #74
    sta _scene_irq_line
    lda #0
    sta _raster_band
    jsr _foes_commit
    lda _sprite_ready
    bne copyframe
    jmp done
copyframe:
    ldx _pending_page
    lda _spr_high,x
    sta $d010
    lda _spr_multi,x
    sta $d01c
    lda _spr_enabled,x
    sta $d015
    lda #0
    sta $d017
    ldy _stage
    cpy #1
    bne @notflight
    lda #18
    bne @expansion
@notflight:
    cpy #3
    bne @expansion
    lda #4
@expansion:
    sta $d01d
    cpy #1
    beq @cave
    cpy #3
    bne :+
@cave:
    lda _spr_enabled,x
    and #32
    beq :+
    lda $d01d
    ora #32
    sta $d01d
    lda #32
    sta $d017
:

    txa
    asl
    asl
    asl
    tax
    .repeat 8,I
    lda _spr_x+I,x
    sta $d000+I*2
    lda _spr_y+I,x
    sta $d001+I*2
    lda _spr_image+I,x
    sta $cff8+I
    lda _spr_color+I,x
    sta $d027+I
    .endrepeat
    jsr _bubble_commit
    lda #0
    sta _sprite_ready
    jmp done


shorelines: .byte 88,136,152,178,202,242,254





.segment "RODATA"
beach_background: .byte 0,0,0,0,7,6,0,0

.import _bubble_commit

.export _raster_body

.import _foes_schedule,_foes_commit,_scene_irq_line
