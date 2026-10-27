; Full-height approved enemies, with double-buffered planes. Each enemy
; reuses its own hardware sprite vertically, leaving all effect slots free.
.macpack longbranch
.export _foes_prepare,_foes_commit,_foes_schedule,_foes_irq,_scene_irq_line,_foes_reset
.import _stage,_draw_page,_pending_page,_frame,_enemies,_enemy_old_x
.import _spr_y,_spr_image,_spr_color,_spr_enabled,_spr_multi,_raster_irq,_raster_exit
.importzp ptr1,ptr2,ptr3,tmp1,tmp2
.segment "BSS"
slot: .res 1
offset: .res 1
image_base: .res 1
body_index: .res 1
row_number: .res 1
out_at: .res 1
cache_keys: .res 4
cache_heads: .res 4
head_index: .res 1
cache_slot: .res 1
front_page: .res 1
_scene_irq_line: .res 1
mux_time: .res 2
mux_top: .res 2
mux_phase: .res 2
mux_slot: .res 1
mux_best: .res 1
mux_pair: .res 1
.segment "CODE"
_foes_reset:
 lda #255
 sta front_page
 lda #0
 ldx #3
:
 sta cache_keys,x
 sta cache_heads,x
 dex
 bpl :-
 rts
_foes_prepare:
 lda _stage
 cmp #2
 bcc :+
 rts
:
 lda #0
 sta slot
@actor:
 lda slot
 asl
 asl
 clc
 adc slot
 asl
 sta offset
 tax
 lda _enemies+7,x
 jne @next
 lda _draw_page
 asl
 asl
 asl
 clc
 adc slot
 adc #2
 tay
 lda _stage
 beq :+
 ; Beach feet sit four pixels deeper in the sand. The multiplex event
 ; then follows the sand split instead of competing with its deadline.
 lda _spr_y,y
 clc
 adc #4
 sta _spr_y,y
:
 lda _spr_y,y
 sec
 sbc #9
 sta _spr_y,y
 lda #8
 ldx slot
 beq :+
 lda #5
:
 sta _spr_color,y
 lda _draw_page
 asl
 sta tmp1
 asl
 clc
 adc tmp1
 sta image_base
 lda slot
 asl
 clc
 adc slot
 adc image_base
 adc #160
 sta image_base
 sta _spr_image,y
 ldx _draw_page
 lda _spr_multi,x
 ora #12
 sta _spr_multi,x
 ; Resolve a stationary or moving pose, with exact mirrored source rows.
 lda #0
 sta body_index
 ldx offset
 lda _stage
 bne @moving
 lda slot
 asl
 tay
 lda _enemies,x
 cmp _enemy_old_x,y
 bne @moving
 lda _enemies+1,x
 cmp _enemy_old_x+1,y
 beq @facing
@moving:
 ; Offset the two walkers so their changed poses are rebuilt on
 ; separate frames instead of producing a simultaneous raster spike.
 lda slot
 asl
 clc
 adc _frame
 lsr
 lsr
 and #7
 clc
 adc #1
 sta body_index
@facing:
 lda slot
 asl
 tay
 lda _stage
 beq @groundface
 ; Beach walkers travel left in world coordinates; reversing the camera
 ; must not make them walk backwards relative to their own pose.
 lda #255
 bne @side
@groundface:
 lda _enemies+4,x
@side:
 bpl :+
 iny
 lda body_index
 clc
 adc #9
 sta body_index
:
 lda foe_head_lo,y
 sta ptr1
 lda foe_head_hi,y
 sta ptr1+1
 sty head_index
 ; Rebuild only when this page's pose changes. Idle actors no longer burn
 ; thousands of cycles clearing and rebuilding identical pixels each frame.
 tya
 asl
 asl
 asl
 asl
 sta tmp1
 tya
 asl
 clc
 adc tmp1
 adc body_index
 adc #1
 pha
 lda _draw_page
 asl
 clc
 adc slot
 tax
 stx cache_slot
 pla
 cmp cache_keys,x
 jeq @next
 sta cache_keys,x
 ; Only a changed bitmap needs ownership of the back page. A busy frame
 ; may reach here before its predecessor was displayed; let that commit
 ; finish before writing the old front page, without halving all updates.
 lda $d015
 and #12
 beq @bufferfree
@awaitfront:
 lda _draw_page
 cmp front_page
 beq @awaitfront
@bufferfree:
 lda image_base
 lsr
 lsr
 ora #$c0
 sta ptr2+1
 lda image_base
 asl
 asl
 asl
 asl
 asl
 asl
 sta ptr2
 ; All twelve buffers start zeroed in the sprite bank. Every live row is
 ; rewritten, so clearing the whole 192-byte buffer on every pose wastes
 ; the flight's scroll budget. Unused lower rows and padding stay zero.
 ; Decode each body row directly into both planes. This avoids copying
 ; two overlapping tails after every animation update.
 lda ptr2
 clc
 adc #64
 sta ptr3
 lda ptr2+1
 adc #0
 sta ptr3+1
 ldx cache_slot
 lda head_index
 clc
 adc #1
 cmp cache_heads,x
 beq @samehead
 sta cache_heads,x
 lda #0
 sta row_number
 sta out_at
 lda #14
 sta row_limit
 jsr decode_foe_rows
@samehead:
 ldy body_index
 lda foe_body_lo,y
 sta ptr1
 lda foe_body_hi,y
 sta ptr1+1
 lda #0
 sta row_number
 lda #42
 sta out_at
 lda #7
 sta row_limit
 jsr decode_foe_rows
 lda ptr2
 clc
 adc #128
 sta ptr2
 bcc :+
 inc ptr2+1
:
 lda #0
 sta out_at
 lda #17
 sta row_limit
 jsr decode_foe_rows
@next:
 inc slot
 lda slot
 cmp #2
 jcc @actor
 rts

decode_foe_rows:
 ldy row_number
 lda (ptr1),y
 tax
 ldy out_at
 lda foe_row0,x
 sta (ptr2),y
 sta (ptr3),y
 iny
 lda foe_row1,x
 sta (ptr2),y
 sta (ptr3),y
 iny
 lda foe_row2,x
 sta (ptr2),y
 sta (ptr3),y
 iny
 sty out_at
 inc row_number
 lda row_number
 cmp row_limit
 bcc decode_foe_rows
 rts

_foes_commit:
 lda _pending_page
 sta front_page
 lda #255
 sta mux_time
 sta mux_time+1
 lda _stage
 cmp #2
 bcs @done
 ldx _pending_page
 lda _spr_enabled,x
 and #12
 sta mux_pair
 txa
 asl
 asl
 asl
 clc
 adc #2
 tay
 ldx #0
@each:
 lda mux_pair
 and bits,x
 beq @next
 lda _spr_y,y
 sta mux_top,x
 clc
 adc #10
 sta mux_time,x
 lda #0
 sta mux_phase,x
 ; Re-arm upper images even if a heavy game frame was not published yet.
 lda _spr_image,y
 sta $cffa,x
 lda _spr_color,y
 sta $d029,x
 tya
 pha
 txa
 asl
 tay
 lda mux_top,x
 sta $d005,y
 pla
 tay
@next:
 iny
 inx
 cpx #2
 bne @each
@done:
 rts

; Called at IRQ exit. Raster-band writes retain their original entry timing;
; only the next IRQ vector changes when an enemy event comes first.
_foes_schedule:
 lda _stage
 cmp #4
 beq @reward
 lda _scene_irq_line
 sta mux_best
 lda #255
 sta mux_slot
 lda _stage
 cmp #2
 bcs @normal
 ldx #1
@each:
 lda mux_time,x
 cmp mux_best
 bcs @next
 sta mux_best
 stx mux_slot
@next:
 dex
 bpl @each
 lda mux_slot
 bmi @normal
 lda #<_foes_irq
 sta $fffe
 lda #>_foes_irq
 sta $ffff
 ; An IRQ exit itself takes time. Consume very close enemy events here
 ; rather than arming an already-passed line and losing a whole frame.
 lda $d011
 bmi @line
 lda $d012
 clc
 adc #3
 cmp mux_best
 bcc @line
 pla
 pla
 jmp foes_irq_service
@normal:
 lda #<_raster_irq
 sta $fffe
 lda #>_raster_irq
 sta $ffff
 ; Do not arm a scene split that expires while the sprite IRQ returns.
 ; Its variable work can follow here, but the colour write stays on time.
 lda $d011
 bmi @line
 lda $d012
 clc
 adc #2
 cmp mux_best
 bcc @line
 ldy mux_best
@scenewait:
 cpy $d012
 beq @scene
 bcc @scene
 jmp @scenewait
@scene:
 pla
 pla
 jmp _raster_body
@line:
 lda mux_best
 sta $d012
 rts
@reward:
 lda _scene_irq_line
 sta $d012
 rts

_foes_irq:
 pha
 txa
 pha
 tya
 pha
 lda #1
 sta $d019
foes_irq_service:
 ldx mux_slot
 lda mux_phase,x
 bne foes_irq_colour
 ldy mux_time,x
@bridgewait:
 cpy $d012
 beq @bridge
 bcc @bridge
 jmp @bridgewait
@bridge:
 inc $cffa,x
 lda mux_top,x
 clc
 adc #21
 pha
 txa
 asl
 tay
 pla
 sta $d005,y
 lda #1
 sta mux_phase,x
 lda mux_top,x
 clc
 adc #24
 sta mux_time,x
 jmp foes_irq_next
foes_irq_colour:
 ; Both planes use one palette. Once the upper DMA is over, replace the
 ; bridge with a clean lower plane before its duplicated tail is reached.
 ; This has a wide nine-line window, no per-pixel colour race or busy wait.
 inc $cffa,x
 lda #255
 sta mux_time,x
foes_irq_next:
 ; Service a second event that became due while handling this one, instead
 ; of scheduling a past raster line and accidentally waiting a whole frame.
 ldx #1
foes_irq_due:
 lda mux_time,x
 cmp #255
 beq foes_irq_notdue
 cmp $d012
 bcc foes_irq_again
 beq foes_irq_again
foes_irq_notdue:
 dex
 bpl foes_irq_due
 jmp _raster_exit
foes_irq_again:
 stx mux_slot
 jmp foes_irq_service
.segment "RODATA"
bits: .byte 4,8
.include "foes-data.inc"

.import _raster_body

.segment "BSS"
row_limit: .res 1
