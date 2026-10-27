.macpack longbranch
.export _enemy_before,_enemy_after,_enemy_idle,_death_start,_death_tick
.export _enemy_air,_death_age
.import _enemies,_px,_py,_frame,_draw_page,_spr_image
.import _sprite,_hide,_sample_start,_blood_spread,_gore_x,_gore_y
.import pusha,pushax
.segment "BSS"
old_x: .res 4
old_y: .res 2
_enemy_air: .res 2
enemy_vy: .res 2
actor_slot: .res 1
_death_age: .res 1
.segment "CODE"
_enemy_before:
    ldx #1
@each:
    ldy #0
    txa
    beq :+
    ldy #10
:
    lda _enemies+2,y
    sta old_y,x
    txa
    asl
    pha
    tax
    lda _enemies,y
    sta old_x,x
    lda _enemies+1,y
    sta old_x+1,x
    pla
    lsr
    tax
    dex
    bpl @each
    rts
_enemy_after:
    lda #1
    sta actor_slot
@each:
    ldx actor_slot
    ldy #0
    txa
    beq :+
    ldy #10
:
    lda _enemies+7,y
    jne @clear
    lda _enemy_air,x
    bne @fall
    lda _enemies+8,y
    jne @next
    lda _enemies+6,y
    jne @next
    lda old_y,x
    cmp #51
    beq @test
    cmp #107
    jne @next
@test:
    clc
    adc #24
    cmp _py
    jcs @next
    lda #1
    sta _enemy_air,x
    sta enemy_vy,x
    lda old_y,x
    clc
    adc #3
    sta old_y,x
@fall:
    lda old_y,x
    clc
    adc enemy_vy,x
    sta _enemies+2,y
    lda _frame
    and #3
    bne :+
    lda enemy_vy,x
    cmp #6
    bcs :+
    inc enemy_vy,x
:
    lda _enemies+2,y
    cmp #163
    bcc @middle
    lda #163
    sta _enemies+2,y
    jmp @clear
@middle:
    cmp #107
    jcc @next
    lda old_y,x
    cmp #107
    jcs @next
    ; Land on either middle ledge; otherwise continue through the gap.
    lda _enemies+1,y
    bne @right_high
    lda _enemies,y
    cmp #16
    jcc @next
    cmp #128
    bcc @land
    cmp #184
    bcs @land
    jcc @next
@right_high:
    cmp #1
    jne @next
    lda _enemies,y
    cmp #48
    jcs @next
@land:
    lda #107
    sta _enemies+2,y
@clear:
    lda #0
    sta _enemy_air,x
@next:
    dec actor_slot
    jpl @each
    rts
_enemy_idle:
    rts
_death_start:
    lda #0
    sta _death_age
    rts
_death_tick:
    lda _death_age
    cmp #32
    jeq _gameover_panel
    jcs death_panel_done
    lda _death_age
    bne :+
    jsr _sample_start
:
    lda _death_age
    cmp #255
    beq :+
    inc _death_age
:
    lda _px
    sta _gore_x
    lda _py
    sta _gore_y
    lda _frame
    and #15
    bne :+
    jsr _blood_spread
:
    lda #1
    jsr pusha
    lda _px
    ldx _px+1
    jsr pushax
    jsr _toby_death_y
    jsr pushax
    lda #58
    ldx _death_age
    cpx #12
    bcc :+
    lda #60
:
    jsr pusha
    lda #11
    jsr _sprite
    lda #0
    jsr pusha
    lda _px
    ldx _px+1
    jsr pushax
    jsr _toby_death_y
    jsr pushax
    lda #59
    ldx _death_age
    cpx #12
    bcc :+
    lda #61
:
    jsr pusha
    lda #1
    jsr _sprite
    lda #7
    jsr pusha
    lda _px
    ldx _px+1
    clc
    adc #10
    bcc :+
    inx
:
    jsr pushax
    lda _frame
    and #15
    clc
    adc _py
    ldx #0
    jsr pushax
    lda #62
    jsr pusha
    lda #2
    jmp _sprite


death_panel_done:
    rts
.export _gameover_panel
.import _bubble_drawn,_bar_active,_weapon_reset,_sprite_ready,_spr_enabled
.segment "RODATA"
gameover_title: .byte 7,1,13,5,32,15,22,5,18
gameover_retry: .byte 16,18,5,19,19,32,6,9,18,5,32,20,15,32,18,5,20,18,25
.segment "CODE"
_gameover_panel:
    inc _death_age
    lda $d011
    and #$6f
    sta $d011
    lda #0
    sta $d015
    sta _sprite_ready
    sta _spr_enabled
    sta _spr_enabled+1
    sta _bubble_drawn
    sta _bar_active
    sta _bar_active+1
    jsr _weapon_reset
    php
    sei
    lda $01
    pha
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
    pla
    sta $01
    plp
    ldx #0
@clear:
    lda #32
    sta $cc00,x
    sta $cd00,x
    sta $ce00,x
    sta $cee8,x
    lda #0
    sta $d800,x
    sta $d900,x
    sta $da00,x
    sta $dae8,x
    inx
    bne @clear
    ldx #8
@title:
    lda gameover_title,x
    sta $cd9f,x
    lda #10
    sta $d99f,x
    dex
    bpl @title
    ldx #18
@retry:
    lda gameover_retry,x
    sta $ce12,x
    lda #15
    sta $da12,x
    dex
    bpl @retry
    lda $d011
    and #$7f
    ora #16
    sta $d011
    rts

.import _ui_font

.import _toby_death_y

.export _enemy_old_x
_enemy_old_x = old_x
