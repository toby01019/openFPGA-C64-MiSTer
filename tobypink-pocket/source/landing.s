.macpack longbranch
.export _landing_state,_landing_tick,_landing_walk,_landing_reset,_scene_fx
.import _px,_py,_stage,_input,_last_input,_face,_grounded,_pvy,_climbing
.import _level,_hp,_frame,_draw_actors,_begin_flight,_new_room,_load_walk
.import _draw_page,_spr_x,_spr_y,_spr_color,_spr_image,_spr_multi,_spr_enabled,_spr_high
.import _attack,_shot,_fireheld,_invincible,_enemies,_head,_gore_time,_enemy_talk
.import _sample_left,_weapon_reset,_ua_ready
.import _flight_time
.import _raster_scroll
.importzp ptr1,ptr2
.segment "BSS"
_landing_state: .res 1
park_x: .res 2
_portal_phase: .res 1
portal_rows: .res 1
.export _portal_phase
.segment "RODATA"
landing_guide: .byte 4,15,23,14,58,32,6,12,25,32,47,32,20,1,16,58,32,12,1,14,4
landing_active: .byte 12,1,14,4,9,14,7,46,46,46
shore_guide: .byte 23,1,12,11,32,20,15,32,3,1,22,5,32,32,21,16,58,32,5,14,20,5,18
.export portal_map,portal_colors
portal_map:
portal_colors:
.segment "CODE"
stop_sample:
    lda _ua_ready
    beq :+
    lda #0
    sta $df20
    sta $df40
:
    lda #0
    sta $dd0f
    sta _sample_left
    sta _sample_left+1
    lda #2
    sta $dd0d
    lda $dd0d
    rts
_landing_reset:
    lda #0
    sta _landing_state
    sta _portal_phase
    jmp stop_sample
guide:
    ldy #39
    lda #32
@clear:
    sta $cfc0,y
    dey
    bpl @clear
    ldy #20
@text:
    lda landing_guide,y
    sta $cfc1,y
    lda #15
    sta $dbc1,y
    dey
    bpl @text
    rts
_landing_tick:
    lda _launch_phase
    beq :+
    rts
:
    lda _landing_state
    cmp #3
    jeq centre_camera
    cmp #1
    jeq descend
    lda _flight_time
    cmp #1
    bne :+
    lda _flight_time+1
    bne :+
    jsr guide
:
    lda _input
    and #2
    cmp #2
    jne leave
    ; DOWN changes altitude freely. Landing requires a fresh DOWN press
    ; close to the ground, after releasing it on approach.
    lda _last_input
    and #2
    jne leave
    lda _py
    cmp #96
    jcc leave
    jsr _can_land
    jcc leave
    lda _px
    sta park_x
    lda _px+1
    sta park_x+1
    lda #3
    sta _landing_state
    ldy #9
@landing_message:
    lda landing_active,y
    sta $cfc1,y
    dey
    bpl @landing_message
    lda #32
    ldy #28
@clear_tail:
    sta $cfcb,y
    dey
    bpl @clear_tail
    lda #9
    sta portal_rows
    jsr stop_sample
    jsr _weapon_reset
    lda #0
    sta _gore_time
    sta _head+6
    sta _enemy_talk
    lda #255
    sta _enemies+8
    sta _enemies+18
    lda _world_x
    cmp #128
    lda #1
    bcc :+
    lda #255
:
    sta _flight_dir
centre_camera:
    lda #98
    sta _py
    lda _world_x+1
    and #1
    bne camera_left
    lda _world_x
    cmp #128
    beq camera_ready
    bcc camera_right
camera_left:
    lda _world_x
    bne :+
    dec _world_x+1
:
    dec _world_x
    lda #255
    bne camera_face
camera_right:
    inc _world_x
    bne :+
    inc _world_x+1
:
    lda #1
camera_face:
    sta _flight_dir
    sta _face
    lda _world_x+1
    and #1
    jne leave
    lda _world_x
    cmp #128
    jne leave
camera_ready:
    lda #1
    sta _landing_state
    sta _face
    sta _flight_dir
    jmp leave
descend:
    ; Coast is frozen: ease the bike to the pad before beginning descent.
    lda _px+1
    bne @from_right
    lda _px
    cmp #174
    bcc @approach
    cmp #179
    bcc @aligned
@from_right:
    sec
    lda _px
    sbc #2
    sta _px
    lda _px+1
    sbc #0
    sta _px+1
    jmp leave
@approach:
    clc
    lda _px
    adc #2
    sta _px
    bcc :+
    inc _px+1
:
    jmp leave
@aligned:
    lda _px
    sta park_x
    lda _px+1
    sta park_x+1
    lda #14
    sta _portal_phase
    lda _py
    cmp #123
    bcs dismount
    inc _py
leave:
    rts
dismount:
    ; Walking planes share RAM with two flight fonts. Restore them once;
    ; the shore raster now uses the common C000 charset for every band.
    lda #3
    sta _stage
    lda #2
    sta _landing_state
    ; Parked entrance has a dedicated slot; walking poses occupy F800.
    ldy #63
@shore_cave:
    lda _destination
    cmp #4
    bcc @regular_cave
    lda pink_cave_sprite,y
    jmp @cave_pixel
@regular_cave:
    lda cave_sprite,y
@cave_pixel:
    sta $f3c0,y
    dey
    bpl @shore_cave
    ; The complete entrance lives outside the walking-data range before
    ; it is unpacked. Both staged pages and the live pointer agree.
    lda #207
    sta _spr_image+5
    sta _spr_image+13
    sta $cffd
    jsr _load_walk
    lda #1
    sta _grounded
    lda #0
    sta _pvy
    sta _climbing
    sta _attack
    sta _shot
    sta _fireheld
    sta _invincible
    jsr guide
    ldy #24
    lda #32
@blankcaption:
    sta $cfc1,y
    dey
    bpl @blankcaption
    ldy #22
@caption:
    lda shore_guide,y
    sta $cfc1,y
    dey
    bpl @caption
    jsr _final_shore
    jsr _landing_walk
    rts
_landing_walk:
    lda _input
    and #4
    beq @right
    lda #255
    sta _face
    sec
    lda _px
    sbc #2
    sta _px
    lda _px+1
    sbc #0
    sta _px+1
@right:
    lda _input
    and #8
    beq @bounds
    lda #1
    sta _face
    clc
    lda _px
    adc #2
    sta _px
    bcc @bounds
    inc _px+1
@bounds:
    lda _px+1
    bmi @min
    beq @low
    lda _px
    cmp #41
    bcc @draw
    lda #40
    sta _px
    lda #1
    sta _px+1
    bne @draw
@low:
    lda _px
    cmp #8
    bcs @draw
@min:
    lda #8
    sta _px
    lda #0
    sta _px+1
@draw:
    jsr _draw_actors
    ; Keep only Toby and the two parked bike planes enabled.
    ldx _draw_page
    lda #7
    sta _spr_enabled,x
    lda #6
    sta _spr_multi,x
    lda _spr_high,x
    and #243
    sta _spr_high,x
    clc
    lda park_x
    adc #16
    pha
    lda park_x+1
    adc #0
    beq :+
    lda _spr_high,x
    ora #4
    sta _spr_high,x
:
    txa
    asl
    asl
    asl
    tax
    pla
    sta _spr_x+2,x
    clc
    adc #18
    sta _spr_x+3,x
    lda park_x+1
    adc #0
    pha
    lda park_x
    cmp #214
    bcc :+
    pla
    lda #1
    pha
:
    pla
    beq :+
    ldy _draw_page
    lda _spr_high,y
    ora #8
    sta _spr_high,y
:
    lda #173
    sta _spr_y+2,x
    sta _spr_y+3,x
    lda #184
    sta _spr_image+2,x
    lda #182
    sta _spr_image+3,x
    lda #11
    sta _spr_color+2,x
    lda #15
    sta _spr_color+3,x
    jsr _preview_draw
    lda _input
    and #1
    beq @done
    lda _last_input
    and #1
    bne @done
    lda _px+1
    bne @enter
    lda _px
    cmp #254
    bcc @bike
@enter:
    jmp _enter_cave
@bike:
    ; Signed distance must fit within +/-24 pixels, including page wrap.
    sec
    lda _px
    sbc park_x
    sta ptr1
    lda _px+1
    sbc park_x+1
    beq @positive
    cmp #255
    bne @done
    lda ptr1
    cmp #232
    bcc @done
    bcs @mount
@positive:
    lda ptr1
    cmp #25
    bcs @done
@mount:
    jsr stop_sample
    jsr _weapon_reset
    jsr _preview_install
    lda #1
    sta _stage
    sta _landing_state
    lda park_x
    sta _px
    lda park_x+1
    sta _px+1
    lda #123
    sta _py
    lda #0
    sta _py+1
    sta _grounded
    jmp _lift_sound
@done:
    rts
_scene_fx:
    jmp _crystal_glint

.import _can_land,_enter_cave,_final_shore

.import _crystal_glint

.import _launch_phase
.import _lift_sound
.export _launch_ground
_launch_ground:
 lda #100
 sta park_x
 lda #0
 sta park_x+1
 sta _input
 jmp dismount

.import _world_x,_flight_dir


; Return through the doorway to the same shore, with the bike still parked.
.export _return_shore
.import _campaign_save,_cave_id,_destination
.segment "BSS"
return_ticks: .res 1
.segment "CODE"
_return_shore:
 jsr _campaign_save
 lda _cave_id
 sta _destination
 asl
 sta _world_x+1
 lda #128
 sta _world_x
 jsr _begin_flight
 lda $d011
 and #111
 sta $d011
 lda #176
 sta _px
 lda #0
 sta _px+1
 lda #1
 sta _face
 sta _landing_state
 lda #109
 sta _py
 lda #0
 sta _py+1
 sta _launch_phase
 sta _input
 sta _portal_phase
 lda #9
 sta portal_rows
 lda #15
 sta return_ticks
@rebuild:
 jsr _landing_tick
 dec return_ticks
 bne @rebuild
 lda #18
 sta _px
 lda #1
 sta _px+1
 sta _last_input
 lda #255
 sta _face
 jsr _landing_walk
 lda $d011
 and #127
 ora #16
 sta $d011
 rts


.import _preview_draw,_preview_install
.import cave_sprite,pink_cave_sprite
