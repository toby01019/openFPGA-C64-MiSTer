.macpack longbranch
.export _campaign_reset,_campaign_room,_campaign_save,_campaign_hud,_campaign_fly
.export _pad_erase,_pad_draw,_can_land,_enter_cave,_final_shore,_cave_exit
.export _cave_total,_cave_id,_remaining,_world_x,_flight_dir,_saved_drops,_destination
.import _drops,_pink,_show_drop,_new_room,_begin_flight,_stage,_input,_last_input,_px,_py,_level
.import _launch_phase
 .import _face,_spr_x,_spr_image,_spr_high
.import _score_digits,_spr_enabled,_draw_page
.importzp ptr1,ptr2,ptr3,tmp1,tmp2
.segment "BSS"
_cave_id: .res 1
_destination: .res 1
_cave_total: .res 1
_remaining: .res 1
_world_x: .res 2
_flight_dir: .res 1
_saved_drops: .res 24
ci: .res 1
co: .res 1
base: .res 1

.segment "RODATA"
totals: .byte 3,3,3,3
rest_label: .byte 18,5,13,1,9,14,9,14,7,32,3,18,25,19,20,1,12,19,32
win1: .byte 25,15,21,32,8,1,22,5,32,23,15,14,32,20,8,5,32,16,9,14,11,0
win2: .byte 1,13,9,7,1,32,52,48,48,48,46,32,3,15,14,7,18,1,20,21,12,1,20,9,15,14,19,46,0
.segment "CODE"
_campaign_reset:
 lda #0
 sta _cave_id
 sta _launch_phase
 sta _world_x+1
 ldx #23
:
 sta _saved_drops,x
 dex
 bpl :-
 ldx #5
:
 sta _score_digits,x
 dex
 bpl :-
 lda #128
 sta _world_x
 lda #1
 sta _flight_dir
 lda #12
 sta _remaining
 rts
offset:
 lda _cave_id
 asl
 sta base
 asl
 clc
 adc base
 sta base
 rts
_campaign_room:
 jsr offset
 ldx _cave_id
 lda totals,x
 sta _cave_total
 lda #0
 sta _pink
 sta ci
 sta co
@each:
 lda ci
 cmp _cave_total
 bcc @load
 lda #3
 bne @state
@load:
 clc
 adc base
 tax
 lda _saved_drops,x
 cmp #3
 bne @state
 inc _pink
@state:
 ldx co
 sta _drops+2,x
 lda ci
 jsr _show_drop
 inc ci
 lda co
 clc
 adc #3
 sta co
 lda ci
 cmp #6
 jcc @each
 rts
_campaign_save:
 jsr offset
 lda #0
 sta ci
 sta co
@each:
 ldx co
 lda _drops+2,x
 pha
 lda ci
 clc
 adc base
 tax
 pla
 sta _saved_drops,x
 inc ci
 lda co
 clc
 adc #3
 sta co
 lda ci
 cmp _cave_total
 jcc @each
 lda #12
 sta _remaining
 ldx #23
:
 lda _saved_drops,x
 cmp #3
 bne :+
 dec _remaining
:
 dex
 bpl :--
 rts
_campaign_hud:
 ldx #10
@weapon:
 lda weapon_label,x
 sta $cc1b,x
 lda #15
 sta $d81b,x
 dex
 bpl @weapon
 ldx #18
:
 lda rest_label,x
 sta $cc28,x
 lda #10
 sta $d828,x
 dex
 bpl :-
 lda _remaining
 ldx #48
:
 cmp #10
 bcc :+
 sec
 sbc #10
 inx
 bne :-
:
 stx $cc3b
 clc
 adc #48
 sta $cc3c
 lda #10
 sta $d83b
 sta $d83c
 jsr campaign_locator
 rts
_campaign_fly:
 lda _landing_state
 jne @hud
@move:
 lda _flight_dir
 sta _face
 bmi @back
 clc
 lda _world_x
 adc _flight_speed
 sta _world_x
 bcc :+
 inc _world_x+1
:
 lda _world_x+1
 cmp #10
 bcc @hud
 lda #255
 sta _world_x
 lda #9
 sta _world_x+1
 lda #255
 sta _flight_dir
 bne @hud
@back:
 sec
 lda _world_x
 sbc _flight_speed
 sta _world_x
 lda _world_x+1
 sbc #0
 sta _world_x+1
 bcs @hud
 lda #0
 sta _world_x
 sta _world_x+1
 lda #1
 sta _flight_dir
@hud:
 lda _world_x+1
 lsr
 cmp _destination
 beq campaign_fly_done
 sta _destination
 jsr campaign_locator
campaign_fly_done:
 rts
_can_land:
 lda _world_x+1
 and #1
 bne @left
 lda _world_x
 cmp #64
 bcc @no
 bcs @allowed
@left:
 lda _world_x
 cmp #172
 bcs @no
@allowed:
 lda _world_x+1
 lsr
 cmp #4
 bne @yes
 lda _remaining
 bne @no
@yes:
 sec
 rts
@no:
 clc
 rts
_pad_erase:
 jmp _preview_erase
_pad_draw:
 jmp _preview_draw
_enter_cave:
 lda _destination
 cmp #4
 jeq victory
 sta _cave_id
 clc
 adc #1
 sta _level
 jmp _new_room
_cave_exit:
 lda _input
 and #5
 beq @done
 and #1
 bne @up_edge
 lda _px
 cmp #9
 bcs @done
 jmp @up
@up_edge:
 lda _last_input
 and #1
 bne @done
@up:
 lda _py
 cmp #152
 bcc @done
 lda _px+1
 bne @done
 lda _px
 cmp #28
 bcs @done
 jmp _return_shore
@done:
 rts
_final_shore:
 ; The final entrance uses the same natural shore as the other caves.
 ; preview.s and landing.s already provide its pink stone arch.
 ; The Amiga computer is revealed only inside the reward room.
 rts
victory:
 lda _remaining
 bne @done
 lda #4
 sta _stage
 jsr _reward_room
 ldx _draw_page
 lda #0
 sta _spr_enabled,x
 ; The reward bitmap already contains the complete requested caption.
 lda _reward_scene_ready
 bne @done
 ldx #0
:
 lda win1,x
 beq :+
 sta $cc81,x
 lda #10
 sta $d881,x
 inx
 bne :-
:
 ldx #0
:
 lda win2,x
 beq @prompt
 sta $cca6,x
 lda #15
 sta $d8a6,x
 inx
 bne :-
@prompt:
 ldx #19
@replay:
 lda replay_prompt,x
 sta $cf7a,x
 lda #10
 sta $db7a,x
 dex
 bpl @replay
@done:
 rts
.segment "RODATA"
.segment "CODE"
font_fetch:
 lda (ptr1),y
 inc ptr1
 bne :+
 inc ptr1+1
:
 ora #0
 rts
font_write:
 sta (ptr2),y
 inc ptr2
 bne :+
 inc ptr2+1
:
 rts
.export _crystal_glint
.import _frame,_drop_x,_drop_y
.segment "CODE"
_crystal_glint:
 lda #0
 sta ci
 sta co
@each:
 ldx ci
 lda _drop_y,x
 sec
 sbc #2
 sta tmp1
 lda #0
 sta ptr1
 sta ptr1+1
@row:
 clc
 lda ptr1
 adc #40
 sta ptr1
 bcc :+
 inc ptr1+1
:
 dec tmp1
 bne @row
 lda _drop_x,x
 sec
 sbc #1
 clc
 adc ptr1
 sta tmp1
 lda ptr1+1
 adc #0
 sta tmp2
 lda tmp1
 clc
 adc #<_base_screen
 sta ptr3
 lda tmp2
 adc #>_base_screen
 sta ptr3+1
 lda tmp1
 sta ptr1
 sta ptr2
 lda tmp2
 clc
 adc #$cc
 sta ptr1+1
 clc
 adc #12
 sta ptr2+1
 ldy #0
 lda (ptr3),y
 sta (ptr1),y
 lda tmp1
 clc
 adc #<_base_color
 sta ptr3
 lda tmp2
 adc #>_base_color
 sta ptr3+1
 lda (ptr3),y
 sta (ptr2),y
 ldx co
 lda _drops+2,x
 bne @next
 lda ci
 asl
 asl
 asl
 clc
 adc _frame
 and #63
 cmp #7
 bcs @next
 cmp #3
 bcs @small
 lda #254
 bne @paint
@small:
 lda #255
@paint:
 sta (ptr1),y
 lda #1
 sta (ptr2),y
@next:
 lda co
 clc
 adc #3
 sta co
 inc ci
 lda ci
 cmp _cave_total
 jcc @each
 rts

.export _unpack_font
_unpack_font:
 ldy #0
font_block:
 jsr font_fetch
 beq font_done
 pha
 and #127
 tax
 pla
 bmi font_zero
font_literal:
 jsr font_fetch
 jsr font_write
 dex
 bne font_literal
 beq font_block
font_zero:
 lda #0
 jsr font_write
 dex
 bne font_zero
 beq font_block
font_done:
 rts

.import _departure

.import _preview_draw,_preview_erase

.import _landing_state

.import _return_shore
.export _exit_hint
_exit_hint:
 ldx #39
 lda #32
@clear:
 sta $cfc0,x
 dex
 bpl @clear
 ldx #0
@text:
 lda exit_text,x
 beq @done
 sta $cfc2,x
 lda #10
 sta $dbc2,x
 inx
 bne @text
@done:
 rts
.segment "RODATA"
exit_text: .byte 12,5,6,20,32,5,4,7,5,58,32,21,16,32,20,15,32,5,24,9,20,32,3,1,22,5,0

.import _base_screen,_base_color

.segment "RODATA"
weapon_label: .byte 6,49,58,32,13,7,47,16,21,13,16
here_label: .byte 3,18,25,19,20,1,12,19,32,8,5,18,5,58,32
secret_label: .byte 19,5,3,18,5,20,32,1,13,9,7,1,32,3,1,22,5,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
end_guide: .byte 1,12,12,32,19,1,22,5,4,33,32,6,12,25,32,20,15,32,20,8,5,32,19,5,3,18,5,20,32,1,13,9,7,1,32,3,1,22,5,46
.segment "CODE"
campaign_locator:
 lda _remaining
 bne @site
 lda $cfc0
 cmp #1
 beq @site
 ldx #39
@end:
 lda end_guide,x
 sta $cfc0,x
 lda #10
 sta $dbc0,x
 dex
 bpl @end
@site:
 lda _stage
 cmp #1
 beq @flight
 cmp #3
 bne @done
@flight:
 lda _destination
 cmp #4
 beq @secret
 lda $cc50
 cmp #3
 beq @count_setup
 ldx #39
 lda #32
@clear:
 sta $cc50,x
 dex
 bpl @clear
 ldx #14
@label:
 lda here_label,x
 sta $cc50,x
 lda #10
 sta $d850,x
 dex
 bpl @label
@count_setup:
 lda _destination
 asl
 sta base
 asl
 adc base
 tax
 ldy _destination
 lda totals,y
 sta ci
 sta co
@count:
 lda _saved_drops,x
 cmp #3
 bne :+
 dec co
:
 inx
 dec ci
 bne @count
 lda co
 clc
 adc #48
 sta $cc5f
 lda #10
 sta $d85f
@done:
 rts
@secret:
 lda $cc50
 cmp #19
 beq @done
 ldx #39
@pink:
 lda secret_label,x
 sta $cc50,x
 lda #10
 sta $d850,x
 dex
 bpl @pink
 rts

.import _reward_room
.import _reward_scene_ready

.segment "RODATA"
replay_prompt: .byte 16,18,5,19,19,32,6,9,18,5,32,20,15,32,18,5,16,12,1,25,32

.import _flight_speed
