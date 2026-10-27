.macpack longbranch
.export _departure,_transit_tick,_launch_phase,_lift_sound
.import _stage,_frame,_input,_last_input,_px,_py,_begin_flight,_flight,_landing_walk,_launch_ground
.import _landing_reset,_weapon_reset,_campaign_save,_draw_page,_spr_enabled
.import _sample_left,_scream_time
.import _restore_ui_font,_flash_time,_shot
.segment "BSS"
_launch_phase: .res 1
launch_timer: .res 1
text_index: .res 1
.segment "RODATA"
intro1: .byte 20,15,2,25,44,32,6,12,25,9,14,7,32,15,14,32,8,9,19,0
intro2: .byte 19,16,5,5,4,5,18,32,2,9,11,5,32,20,15,32,20,8,5,32,14,5,24,20,32,3,1,22,5,46,0
fire_text: .byte 16,18,5,19,19,32,6,9,18,5,0
.segment "CODE"
_departure:
 jsr _campaign_save
 jsr _landing_reset
 jsr _weapon_reset
 lda #5
 sta _stage
 lda #0
 sta _launch_phase
 sta text_index
 sta _flash_time
 sta _shot
 sta $d404
 sta $d40b
 sta $d412
 sta $d021
 sta $d020
 sei
 lda #$31
 sta $01
 ldx #0
@font:
 lda _ui_font,x
 sta $c000,x
 lda _ui_font+256,x
 sta $c100,x
 inx
 bne @font
 lda #$35
 sta $01
 cli
 lda #0
 ldx _draw_page
 sta _spr_enabled,x
 ldx #0
 lda #32
@clear:
 sta $cc00,x
 sta $cd00,x
 sta $ce00,x
 sta $cee8,x
 inx
 bne @clear
 rts
_transit_tick:
 lda _stage
 cmp #5
 beq intro
 lda _launch_phase
 cmp #1
 jeq boarding
 cmp #2
 jeq lift
 rts
intro:
 lda _frame
 and #1
 bne @keys
 ldx text_index
 cpx #30
 bcs @keys
 lda intro2,x
 sta $ce0d,x
 lda #10
 sta $da0d,x
 cpx #19
 bcs :+
 lda intro1,x
 sta $cdc2,x
 lda #10
 sta $d9c2,x
:
 inc text_index
@keys:
 ldx #9
:
 lda fire_text,x
 sta $ceb7,x
 lda _frame
 and #16
 beq :+
 lda #10
 bne :++
:
 lda #4
:
 sta $dab7,x
 dex
 bpl :---
 lda _input
 and #16
 beq @done
 lda _last_input
 and #16
 bne @done
 jsr _begin_flight
 lda #60
 sta _px
 lda #123
 sta _py
 jsr _launch_ground
 lda #1
 sta _launch_phase
 lda #20
 sta launch_timer
@done:
 rts
boarding:
 lda #8
 sta _input
 jsr _landing_walk
 dec launch_timer
 bne lift_sound_done
 jsr _begin_flight
 lda #100
 sta _px
 lda #123
 sta _py
_lift_sound:
 lda #2
 sta _launch_phase
 lda #0
 sta _input
 sta $d40b
 sta $d40c
 lda #$c4
 sta $d40d
 lda #$11
 sta $d40b
lift_sound_done:
 rts
lift:
 lda #0
 sta _input
 dec _py
 dec _py
 lda _py
 asl
 sta $d407
 lda #8
 sta $d408
 lda _py
 cmp #47
 bcs @done
 lda #0
 sta _launch_phase
 sta _landing_state
 sta $d40b
@done:
 rts


.export _engine_tick
.segment "CODE"
_engine_tick:
 lda _stage
 cmp #1
 bne engine_off
 lda _launch_phase
 bne engine_done
 lda _sample_left
 ora _sample_left+1
 ora _scream_time
 bne engine_done
 lda #$08
 sta $d40c
 lda #$36
 sta $d40d
 lda #$80
 sta $d409
 lda #$08
 sta $d40a
 lda _frame
 and #7
 clc
 adc #$30
 sta $d407
 lda #$04
 sta $d408
 lda #$11
 sta $d40b
 rts
engine_off:
 lda _sample_left
 ora _sample_left+1
 ora _scream_time
 bne engine_done
 lda #0
 sta $d40b
engine_done:
 rts

.import _landing_state

.import _ui_font
