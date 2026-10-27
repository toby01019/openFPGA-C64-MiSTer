; Hand-written PAL 6510 movement. Input and integration once per game frame.
; One-way platforms, edge-triggered jumps, ladders, immediate facing.
.export _player_physics
.export _flight_physics
.import _px, _py, _pvy, _face, _grounded, _climbing
.import _input, _last_input, _frame
.importzp ptr1, ptr2, tmp1, tmp2, tmp3, tmp4
.segment "RODATA"
floor_y: .byte 184,128,128,72
floor_left_lo: .byte 0,16,184,56
floor_left_hi: .byte 0,0,0,0
floor_right_lo: .byte <320,128,<304,<272
floor_right_hi: .byte >320,0,>304,>272
.segment "CODE"
ladder_test:
    ; Returns A=1 inside one of the four 20-pixel-wide ladder corridors.
    lda _py
    cmp #104
    bcc upper_ladders
    cmp #167
    bcs upper_ladders
    lda _px+1
    bne right_lower
    lda _px
    cmp #79
    bcc upper_ladders
    cmp #98
    bcc yes_ladder
    bcs upper_ladders
right_lower:
    cmp #1
    bne upper_ladders
    lda _px
    cmp #7
    bcc upper_ladders
    cmp #26
    bcc yes_ladder
upper_ladders:
    lda _py
    cmp #48
    bcc no_ladder
    cmp #111
    bcs no_ladder
    lda _px+1
    bne no_ladder
    lda _px
    cmp #47
    bcc no_ladder
    cmp #66
    bcc yes_ladder
    cmp #207
    bcc no_ladder
    cmp #226
    bcc yes_ladder
no_ladder:
    lda #0
    rts
yes_ladder:
    lda #1
    rts

; X=platform index, A=1 if player's feet overlap its horizontal span.
overlap:
    clc
    lda _px
    adc #17
    sta tmp1
    lda _px+1
    adc #0
    cmp floor_left_hi,x
    bcc no_overlap
    bne check_right
    lda tmp1
    cmp floor_left_lo,x
    bcc no_overlap
check_right:
    clc
    lda _px
    adc #7
    sta tmp1
    lda _px+1
    adc #0
    cmp floor_right_hi,x
    bcc yes_overlap
    bne no_overlap
    lda tmp1
    cmp floor_right_lo,x
    bcs no_overlap
yes_overlap:
    lda #1
    rts
no_overlap:
    lda #0
    rts

_player_physics:
    lda _input
    and #4
    beq move_right
    lda #$ff
    sta _face
    lda _input
    and #16
    bne move_right
    sec
    lda _px
    sbc #2
    sta _px
    lda _px+1
    sbc #0
    sta _px+1
move_right:
    lda _input
    and #8
    beq clamp_x
    lda #1
    sta _face
    lda _input
    and #16
    bne clamp_x
    clc
    lda _px
    adc #2
    sta _px
    lda _px+1
    adc #0
    sta _px+1
clamp_x:
    lda _px+1
    bpl clamp_max
    lda #0
    sta _px
    sta _px+1
clamp_max:
    lda _px+1
    beq test_climb
    cmp #1
    bne set_max
    lda _px
    cmp #41
    bcc test_climb
set_max:
    lda #<296
    sta _px
    lda #>296
    sta _px+1
test_climb:
    lda _input
    and #16
    bne existing_climb
    lda _input
    and #3
    beq existing_climb
    jsr ladder_test
    beq existing_climb
    lda #1
    sta _climbing
    lda #0
    sta _pvy
    sta _grounded
    lda _input
    and #1
    beq climb_down
    sec
    lda _py
    sbc #2
    cmp #51
    bcs store_climb
    lda #51
    bne store_climb
climb_down:
    clc
    lda _py
    adc #2
    cmp #164
    bcc store_climb
    lda #163
store_climb:
    sta _py
    lda #0
    sta _py+1
    rts
existing_climb:
    lda _climbing
    beq jump_test
    jsr ladder_test
    beq leave_ladder
    rts
leave_ladder:
    lda #0
    sta _climbing
jump_test:
    lda _input
    and #16
    bne integrate
    lda _input
    and #1
    beq integrate
    lda _last_input
    and #1
    bne integrate
    lda _grounded
    beq integrate
    lda #$f8
    sta _pvy
    lda #0
    sta _grounded
integrate:
    clc
    lda _py
    adc #21
    sta tmp3
    lda _grounded
    bne test_landing
    clc
    lda _py
    adc _pvy
    sta _py
    lda _frame
    and #1
    bne test_landing
    lda _pvy
    bmi gravity
    cmp #8
    bcs test_landing
gravity:
    inc _pvy
test_landing:
    clc
    lda _py
    adc #21
    sta tmp4
    lda _pvy
    bmi check_support
    ldx #0
landing_loop:
    lda floor_y,x
    cmp tmp3
    bcc next_landing
    cmp tmp4
    beq landing_height
    bcs next_landing
landing_height:
    jsr overlap
    beq next_landing
    sec
    lda floor_y,x
    sbc #21
    sta _py
    lda #0
    sta _pvy
    lda #1
    sta _grounded
    bne check_support
next_landing:
    inx
    cpx #4
    bne landing_loop
check_support:
    lda _grounded
    beq vertical_limits
    lda #0
    sta _grounded
    clc
    lda _py
    adc #21
    sta tmp4
    ldx #0
support_loop:
    lda floor_y,x
    cmp tmp4
    bne next_support
    jsr overlap
    beq next_support
    lda #1
    sta _grounded
    bne vertical_limits
next_support:
    inx
    cpx #4
    bne support_loop
vertical_limits:
    lda _py
    cmp #164
    bcc upper_limit
    lda #163
    sta _py
    lda #0
    sta _pvy
    lda #1
    sta _grounded
upper_limit:
    lda _py
    cmp #25
    bcs physics_done
    lda #25
    sta _py
    lda #0
    sta _pvy
physics_done:
    lda #0
    sta _py+1
    rts

; Safe free flight. Holding fire changes aim without moving the speeder.
_flight_physics:
    lda _launch_phase
    beq :+
    rts
:
    lda _landing_state
    beq :+
    rts
:
    lda _input
    and #16
    beq :+
    rts
:
    lda _input
    and #4
    beq flight_right
    sec
    lda _px
    sbc #2
    sta _px
    lda _px+1
    sbc #0
    sta _px+1
flight_right:
    lda _input
    and #8
    beq flight_limit_x
    clc
    lda _px
    adc #2
    sta _px
    lda _px+1
    adc #0
    sta _px+1
flight_limit_x:
    lda _px+1
    bne flight_high_x
    lda _px
    cmp #8
    bcs flight_up
    lda #8
    sta _px
    bne flight_up
flight_high_x:
    bmi flight_min_x
    cmp #1
    bne flight_max_x
    lda _px
    cmp #19
    bcc flight_up
flight_max_x:
    lda #<274
    sta _px
    lda #>274
    sta _px+1
    bne flight_up
flight_min_x:
    lda #8
    sta _px
    lda #0
    sta _px+1
flight_up:
    lda _input
    and #1
    beq flight_down
    sec
    lda _py
    sbc #2
    sta _py
flight_down:
    lda _input
    and #2
    beq flight_limit_y
    inc _py
    inc _py
flight_limit_y:
    lda _py
    cmp #30
    bcs flight_y_max
    lda #30
    sta _py
flight_y_max:
    lda _py
    cmp #101
    bcc flight_y_hi
    lda #100
    sta _py
flight_y_hi:
    lda #0
    sta _py+1
flight_done:
    rts

.import _landing_state

.import _launch_phase

.export _beach_camera_step
.import _enemies,_landing_state,_launch_phase,_flight_dir
.segment "CODE"
_beach_camera_step:
 tax
 lda _landing_state
 ora _launch_phase
 bne @done
 txa
 beq :+
 lda #10
:
 tax
 lda _flight_dir
 bmi @back
 sec
 lda _enemies,x
 sbc _flight_speed
 sta _enemies,x
 bcs @done
 dec _enemies+1,x
 rts
@back:
 clc
 lda _enemies,x
 adc _flight_speed
 sta _enemies,x
 bcc @done
 inc _enemies+1,x
@done:
 rts
.import _flight_speed
