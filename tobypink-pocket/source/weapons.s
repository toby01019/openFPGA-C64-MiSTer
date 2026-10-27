; Three independent projectiles. Sprite 4 carries the leading round;
; short reversible character overlays make all following rounds visible.
.macpack longbranch
.export _shoot,_weapon_control,_weapon_projectiles,_weapon_render,_weapon_erase
.export _weapon_tick,_weapon_reset,_weapon_hud,_weapon_pump_pose
.export _gun_sound,_gun_audio,_weapon,_weapon_key,_debug_weapon_key
.export _weapon_cooldown,_round_active,_round_y,_round_kind,_round_x
.import _input,_last_input,_attack,_fireheld,_stage,_ammo,_px,_py,_face,_pose
.import _shot,_shot_x,_shot_y,_shot_dir,_shot_vy,_sound_time,_sample_left
.import gun_kind
.import _melee,_hud,_sprite,_hide,_weapon_projectile
.import pusha,pushax,incsp1
.importzp c_sp,ptr1,ptr2,tmp1,tmp2
.segment "BSS"
_weapon: .res 1 ; 0=pump, 1=machine gun
_weapon_key: .res 1
_debug_weapon_key: .res 1
key_latch: .res 1
switch_hold: .res 1
switch_consumed: .res 1
burst_fired: .res 1
_weapon_cooldown: .res 1
gun_age: .res 1
gun_total: .res 1
gun_profile: .res 1
bullet_kind: .res 1
aim: .res 1
spawn_count: .res 1
spawn_vy: .res 1
slot: .res 1
_round_active: .res 3
_round_x: .res 3
round_xhi: .res 3
_round_y: .res 3
round_yhi: .res 3
round_dir: .res 3
round_vy: .res 3
_round_kind: .res 3
round_age: .res 3
drawn: .res 4
saved_at: .res 4
saved_athi: .res 4
saved_a: .res 4
saved_b: .res 4
saved_ca: .res 4
saved_cb: .res 4
render_sprite: .res 1
.segment "RODATA"
mg_sprite: .incbin "shot-mg.bin"
pump_sprite: .incbin "shot-pump.bin"
.segment "CODE"
_weapon_tick:
    lda _flash_time
    beq :+
    dec _flash_time
:
    lda _weapon_cooldown
    beq @keys
    dec _weapon_cooldown
    lda _weapon
    bne @keys
    lda _weapon_cooldown
    cmp #12
    bne @keys
    ; Two short mechanical strokes between pumpgun shots.
    lda #2
    sta gun_profile
    lda #0
    sta gun_kind
    lda #4
    sta gun_total
    sta _sound_time
    lda #0
    sta gun_age
    sta $d404
    sta $d405
    lda #$04
    sta $d406
    lda #$19
    sta $d401
    lda #$81
    sta $d404
@keys:
    lda _weapon_key
    ora _debug_weapon_key
    beq @released
    lda key_latch
    bne @joystick
    inc key_latch
    jsr toggle
    jmp @joystick
@released:
    sta key_latch
@joystick:
    rts
toggle:
    lda _weapon
    eor #1
    sta _weapon
    lda #0
    sta _weapon_cooldown
    jsr _weapon_hud
    rts

_weapon_control:
    lda _attack
    beq :+
    dec _attack
:
    lda _input
    and #32
    beq @keyfire
    lda _last_input
    and #32
    bne @keyfire
    jsr _melee
@keyfire:
    lda _input
    and #64
    beq @joyfire
    lda _weapon
    bne @keyboard_auto
    lda _last_input
    and #64
    bne @joyfire
@keyboard_auto:
    lda _input
    jsr _shoot
@joyfire:
    lda _input
    and #16
    beq @release
    lda _fireheld
    cmp #250
    bcs :+
    inc _fireheld
:
    ; Down+FIRE operates the chainsaw; weapon selection stays on F1.
    lda _input
    and #2
    beq @ranged
    lda _attack
    bne @return
    jsr _melee
    jmp @return
@ranged:
    lda _weapon
    bne @auto
    lda _last_input
    and #16
    bne @return
@auto:
    lda _input
    jsr _shoot
@return:
    rts
@release:
    lda #0
    sta _fireheld
    sta switch_consumed
    sta burst_fired
    rts

_shoot:
    sta aim
    lda _weapon_cooldown
    jne @return
    lda _ammo
    beq @return
    ldx #2
@free:
    lda _round_active,x
    beq @start
    dex
    bpl @free
@return:
    rts
@start:
    dec _ammo
    lda #0
    sta spawn_vy
    lda aim
    and #1
    beq :+
    lda #$fd
    sta spawn_vy
:
    lda aim
    and #2
    beq :+
    lda #3
    sta spawn_vy
:
    lda #1
    sta spawn_count
    lda #5
    sta _weapon_cooldown
    lda _weapon
    bne @spawn
    lda #3
    sta spawn_count
    lda #24
    sta _weapon_cooldown
    dec spawn_vy
@spawn:
    ldx #0
@find:
    lda _round_active,x
    beq @put
    inx
    cpx #3
    bcc @find
    jmp @sound
@put:
    lda #1
    sta _round_active,x
    lda #0
    sta round_age,x
    lda _weapon
    sta _round_kind,x
    lda _face
    sta round_dir,x
    lda spawn_vy
    sta round_vy,x
    lda _px
    sta _round_x,x
    lda _px+1
    sta round_xhi,x
    lda _face
    bmi @left
    clc
    lda _round_x,x
    adc #20
    sta _round_x,x
    bcc @vertical
    inc round_xhi,x
    jmp @vertical
@left:
    sec
    lda _round_x,x
    sbc #16
    sta _round_x,x
    bcs @vertical
    dec round_xhi,x
@vertical:
    clc
    lda _py
    adc #2
    sta _round_y,x
    lda _py+1
    adc #0
    sta round_yhi,x
    inc spawn_vy
    dec spawn_count
    bne @spawn
@sound:
    lda #6
    sta _attack
    jsr _gun_sound
    jmp _hud

_weapon_projectiles:
    lda #0
    sta slot
@each:
    ldx slot
    lda _round_active,x
    beq @next
    inc round_age,x
    lda round_age,x
    cmp #45
    bcs @expire
    lda _round_kind,x
    bne @move
    lda round_age,x
    cmp #19
    bcc @move
@expire:
    lda #0
    sta _round_active,x
    beq @next
@move:
    jsr load_round
    jsr _weapon_projectile
    ldx slot
    lda _shot
    sta _round_active,x
    lda _shot_x
    sta _round_x,x
    lda _shot_x+1
    sta round_xhi,x
    lda _shot_y
    sta _round_y,x
    lda _shot_y+1
    sta round_yhi,x
@next:
    inc slot
    lda slot
    cmp #3
    bcc @each
    ; Expose a live round to existing pose/diagnostic code.
    ldx #1
    lda _round_active,x
    bne load_round
    ldx #0
@first:
    lda _round_active,x
    bne load_round
    inx
    cpx #3
    bcc @first
    lda #0
    sta _shot
    lda #4
    jmp _hide
load_round:
    lda _round_kind,x
    sta bullet_kind
    lda _round_active,x
    sta _shot
    lda _round_x,x
    sta _shot_x
    lda round_xhi,x
    sta _shot_x+1
    lda _round_y,x
    sta _shot_y
    lda round_yhi,x
    sta _shot_y+1
    lda round_dir,x
    sta _shot_dir
    lda round_vy,x
    sta _shot_vy
    rts

_weapon_erase:
    ldx #3
@each:
    lda drawn,x
    beq @next
    lda saved_at,x
    sta ptr1
    lda saved_athi,x
    sta ptr1+1
    ldy #0
    lda saved_a,x
    sta (ptr1),y
    iny
    lda saved_b,x
    sta (ptr1),y
    lda ptr1+1
    clc
    adc #12
    sta ptr1+1
    lda saved_cb,x
    sta (ptr1),y
    dey
    lda saved_ca,x
    sta (ptr1),y
    lda #0
    sta drawn,x
@next:
    dex
    bpl @each
    rts

_weapon_render:
    jsr _weapon_hud
    lda _stage
    jne @flash
    lda #0
    sta slot
    sta render_sprite
@each:
    ldx slot
    lda _round_active,x
    jeq @next
@chars:
    ldx slot
    lda _round_y,x
    clc
    adc #9
    lsr
    lsr
    lsr
    cmp #3
    jcc @next
    cmp #23
    jcs @next
    tay
    lda #0
    sta ptr1
    lda #$cc
    sta ptr1+1
@row:
    clc
    lda ptr1
    adc #40
    sta ptr1
    bcc :+
    inc ptr1+1
:
    dey
    bne @row
    lda round_xhi,x
    sta tmp1
    lda _round_x,x
    lsr tmp1
    ror
    lsr
    lsr
    cmp #39
    bcs @next
    clc
    adc ptr1
    sta ptr1
    bcc :+
    inc ptr1+1
:
    lda ptr1
    sta saved_at,x
    lda ptr1+1
    sta saved_athi,x
    ldy #0
    lda (ptr1),y
    sta saved_a,x
    iny
    lda (ptr1),y
    sta saved_b,x
    lda _round_kind,x
    asl
    clc
    adc #190
    dey
    sta (ptr1),y
    iny
    clc
    adc #1
    sta (ptr1),y
    lda ptr1+1
    clc
    adc #12
    sta ptr1+1
    lda (ptr1),y
    sta saved_cb,x
    dey
    lda (ptr1),y
    sta saved_ca,x
    lda #1
    sta (ptr1),y
    iny
    sta (ptr1),y
    sta drawn,x
@next:
    inc slot
    lda slot
    cmp #3
    jcc @each
@flash:
    jsr _muzzle_flash
    jsr _toby_lower
    jmp _foes_prepare

_weapon_reset:
    jsr _weapon_erase
    lda #0
    sta _weapon_cooldown
    sta burst_fired
    sta switch_consumed
    ldx #2
:
    sta _round_active,x
    dex
    bpl :-
    rts

_weapon_hud:
    rts

_weapon_pump_pose:
    lda _weapon
    jne @return
    lda _weapon_cooldown
    cmp #7
    bcc @return
    cmp #17
    bcs @return
    lda #4
    sta _pose
@return:
    rts

_gun_sound:
 lda #4
 sta _flash_time
 lda #0
 sta _sound_time
 sta gun_total
 jsr _sample_shot
@sprite:
    ldx #63
:
    lda _weapon
    beq @pump
    lda mg_sprite,x
    jmp @write
@pump:
    lda pump_sprite,x
@write:
    sta $eb00,x
    dex
    bpl :-
    rts

_gun_audio:
 lda _stage
 cmp #1
 bne @done
 lda _ua_ready
 bne @done
 lda _sound_time
 beq @done
 cmp #1
 bne :+
 lda #$20
 sta $d404
 rts
:
 asl
 asl
 sta $d401
@done:
 rts

.export _speeder_exhaust
.import _gore_time,_frame
_speeder_exhaust:
    lda _gore_time
    jne flight_blood
    ldx _draw_page
    lda _spr_enabled,x
    ora #128
    sta _spr_enabled,x
    lda _spr_high,x
    and #127
    sta _spr_high,x
    lda _px
    clc
    ldy _flight_dir
    bmi exhaust_left
    adc #9
    jmp exhaust_position
exhaust_left:
    adc #59
exhaust_position:
    sta tmp1
    lda _px+1
    adc #0
    beq :+
    lda _spr_high,x
    ora #128
    sta _spr_high,x
:
    txa
    asl
    asl
    asl
    tax
    lda tmp1
    sta _spr_x+7,x
    lda _py
    clc
    adc #52
    sta _spr_y+7,x
    lda #183
    sta _spr_image+7,x
    lda _frame
    and #2
    beq :+
    lda #7
    bne exhaust_colour
:
    lda #8
exhaust_colour:
    sta _spr_color+7,x
    rts

.export _bullet_step
_bullet_step:
    cmp #$80
    bcs @left
    ldx #0
    lda bullet_kind
    beq :+
    lda #14
    rts
:
    lda #7
    rts
@left:
    ldx #$ff
    lda bullet_kind
    beq :+
    lda #$f2
    rts
:
    lda #$f9
    rts

.export _flight_bullet_step
_flight_bullet_step:
    pha
    lda _weapon
    sta bullet_kind
    pla
    jmp _bullet_step

.export _flash_time
.segment "BSS"
_flash_time: .res 1
.segment "CODE"
_muzzle_flash:
    lda _flash_time
    jeq @return
    lda _stage
    cmp #2
    jeq @return
    cmp #1
    jeq @return
    lda _py
    clc
    adc #9
    lsr
    lsr
    lsr
    cmp #3
    jcc @return
    cmp #23
    jcs @return
    tay
    lda #0
    sta ptr1
    lda #$cc
    sta ptr1+1
@row:
    clc
    lda ptr1
    adc #40
    sta ptr1
    bcc :+
    inc ptr1+1
:
    dey
    bne @row
    lda _px+1
    sta tmp1
    lda _face
    beq @left_flash
    lda _px
    clc
    adc #20
    bcc :+
    inc tmp1
:
    jmp @flash_x
@left_flash:
    lda _px
    sec
    sbc #12
    bcs @flash_x
    dec tmp1
@flash_x:
    lsr tmp1
    ror
    lsr
    lsr
    cmp #39
    jcs @return
    clc
    adc ptr1
    sta ptr1
    bcc :+
    inc ptr1+1
:
    lda ptr1
    sta saved_at+3
    lda ptr1+1
    sta saved_athi+3
    ldy #0
    lda (ptr1),y
    sta saved_a+3
    lda #142
    sta (ptr1),y
    iny
    lda (ptr1),y
    sta saved_b+3
    lda #143
    sta (ptr1),y
    lda ptr1+1
    clc
    adc #12
    sta ptr1+1
    lda (ptr1),y
    sta saved_cb+3
    lda #1
    sta (ptr1),y
    dey
    lda (ptr1),y
    sta saved_ca+3
    lda #7
    sta (ptr1),y
    lda #1
    sta drawn+3
@return:
    rts

.import _flight_dir

.import _gore_x,_gore_y
.import _draw_page,_spr_enabled,_spr_multi,_spr_high,_spr_x,_spr_y,_spr_image,_spr_color
.segment "CODE"
flight_blood:
 dec _gore_time
 ldx _draw_page
 lda _spr_enabled,x
 ora #128
 sta _spr_enabled,x
 lda _spr_multi,x
 and #127
 sta _spr_multi,x
 lda _spr_high,x
 and #127
 sta _spr_high,x
 lda _gore_x
 clc
 adc #16
 bcc :+
 pha
 lda _spr_high,x
 ora #128
 sta _spr_high,x
 pla
:
 pha
 txa
 asl
 asl
 asl
 tax
 pla
 sta _spr_x+7,x
 lda _gore_y
 clc
 adc #42
 sta _spr_y+7,x
 lda _gore_time
 lsr
 lsr
 lsr
 eor #3
 clc
 adc #177
 sta _spr_image+7,x
 lda #2
 sta _spr_color+7,x
 rts

.import _sample_shot

.export _chainsaw_audio
_chainsaw_audio:
    lda _stage
    bne @done
    lda _attack
    beq @done
    ; Dedicated third SID voice keeps digitized shots and screams intact.
    lda _frame
    and #3
    clc
    adc #$09
    sta $d40f
    lda #$90
    sta $d40e
    lda #0
    sta $d413
    lda #$b4
    sta $d414
    lda #$81
    sta $d412
    rts
@done:
    lda #$80
    sta $d412
    rts

.import _drops,_show_drop,_distance
.segment "BSS"
restore_index: .res 1
.segment "CODE"
chainsaw_restore:
 lda #0
 sta restore_index
@next:
 jsr @slot
 lda _drops+2,x
 cmp #1
 bne @advance
 lda _px
 clc
 adc #10
 ldx _px+1
 bcc :+
 inx
:
 jsr pushax
 jsr @slot
 lda _drops,x
 asl
 asl
 asl
 ldx #0
 jsr _distance
 cpx #0
 bne @advance
 cmp #32
 bcs @advance
 lda _py
 clc
 adc #12
 ldx #0
 jsr pushax
 jsr @slot
 lda _drops+1,x
 asl
 asl
 asl
 clc
 adc #4
 ldx #0
 jsr _distance
 cpx #0
 bne @advance
 cmp #24
 bcs @advance
 jsr @slot
 lda #0
 sta _drops+2,x
 lda restore_index
 jsr _show_drop
@advance:
 inc restore_index
 lda restore_index
 cmp #6
 bcc @next
 rts
@slot:
 lda restore_index
 asl
 clc
 adc restore_index
 tax
 rts

.export _chainsaw_restore
_chainsaw_restore = chainsaw_restore

.import _toby_lower

.import _foes_prepare
.import _ua_ready
