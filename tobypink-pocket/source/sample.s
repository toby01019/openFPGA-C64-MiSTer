; 3000 Hz original Beach Head II scream and recorded CC0 shotgun, CIA2 NMI.
.export _sample_start,_sample_shot,_sample_nmi,_sample_left,_sample_mode
.import _weapon,_stage
.export _ua_init,_ua_ready,_ua_status

.segment "BSS"
_sample_left: .res 2
_sample_mode: .res 1
_ua_ready: .res 1
_ua_status: .res 1
_scream_variant: .res 1
.segment "RODATA"
sample_data: .incbin "beach-head-scream.pcm"
sample_end:
shot_data: .byte 8
shot_end:
.segment "CODE"
_sample_shot:
 lda _ua_ready
 beq :+
 jmp ua_shot
:
 lda _stage
 cmp #1
 beq laser_fallback
 lda _sample_left
 ora _sample_left+1
 beq @start
 lda _sample_mode
 cmp #1
 bne :+
 rts
:
@start:
 jsr stop_timer
 lda #2
 sta _sample_mode
 lda #<shot_data
 sta sample_fetch+1
 lda #>shot_data
 sta sample_fetch+2
 lda #<(shot_end-shot_data)
 ldx #>(shot_end-shot_data)
 ldy _weapon
 beq :+
 lda #1
 ldx #0
:
 sta _sample_left
 stx _sample_left+1
 jmp setup_dac
laser_fallback:
 ; A stock C64 uses a SID laser, not a shotgun DAC interrupt, in flight.
 lda #0
 sta $d404
 sta $d400
 sta $d405
 lda #$28
 sta $d401
 lda #$84
 sta $d406
 lda #$21
 sta $d404
 lda #10
 sta _sound_time
 rts
_sample_start:
 lda _stage
 cmp #1
 beq :+
 cmp #3
 bne :++
:
 rts
:
 lda _ua_ready
 beq :+
 jmp ua_scream
:
 jsr stop_timer
 lda #1
 sta _sample_mode
 lda #<sample_data
 sta sample_fetch+1
 lda #>sample_data
 sta sample_fetch+2
 lda #<(sample_end-sample_data)
 sta _sample_left
 lda #>(sample_end-sample_data)
 sta _sample_left+1
setup_dac:
 lda #0
 sta $d404
 sta $d40b
 sta $d40e
 sta $d40f
 sta $d413
 lda #$f0
 sta $d414
 lda #$ff
 sta $d410
 lda #$0f
 sta $d411
 lda #$49
 sta $d412
 lda #<327
 sta $dd06
 lda #>327
 sta $dd07
 lda #$82
 sta $dd0d
 lda #$11
 sta $dd0f
sample_return:
 rts
stop_timer:
 lda #0
 sta $dd0f
 lda #2
 sta $dd0d
 lda $dd0d
 rts
_sample_nmi:
 pha
 lda $dd0d
 and #2
 beq sample_exit
sample_fetch:
 lda sample_data
 sta $d418
 inc sample_fetch+1
 bne :+
 inc sample_fetch+2
:
 lda _sample_left
 bne :+
 dec _sample_left+1
:
 dec _sample_left
 lda _sample_left
 ora _sample_left+1
 bne sample_exit
 lda #0
 sta $dd0f
 sta $d412
 sta _sample_mode
 lda #2
 sta $dd0d
 lda #15
 sta $d418
sample_exit:
 pla
 rti

; Ultimate enhanced audio: signed 16-bit PCM, two independent hardware voices.
.segment "RODATA"
.include "ultimate-sample-tables.inc"
ua_offsets: .byte 4,5,6,7,9,10,11,14,15
ua_open: .byte 1,2,1
 .byte 47,83,68,47,83,112,105,101,108,101,47,84,111,98,121,32,84,114,121,32,116,111,32,83,97,118,101,32,116,104,101,32,80,105,110,107,47,86,48,50,55,45,65,85,68,73,79,46,82,69,85
ua_open_end:
ua_load: .byte 1,33
 .dword 0,272296 ; Complete bank, including selected scream 07 at its end.
.export _ua_load
_ua_load = ua_load
ua_close: .byte 1,3
.segment "CODE"
_ua_init:
 lda #0
 sta _ua_ready
 sta _ua_status
 ; Pocket edition: the APF loader preloads V027-AUDIO.REU. No Ultimate
 ; filesystem command is issued on Pocket. Missing/disabled audio falls
 ; back to the original SID effects. Keep Ultimate's original path below.
 lda $df18
 cmp #$50
 bne @ultimate
 lda $df19
 cmp #$4b
 bne @ultimate
 lda $df1a
 cmp #1
 bne ua_init_return
 lda $df1b
 and #1
 beq ua_init_return
 lda #1
 sta _ua_ready
 lda #0
 sta $df20
 sta $df40
 rts
@ultimate:
 lda $df1d
 cmp #$c9
 bne ua_init_return
 lda $df21
 cmp #$10
 bne ua_init_return
 ldx #0
@open:
 lda ua_open,x
 sta $df1d
 inx
 cpx #(ua_open_end-ua_open)
 bne @open
 jsr ua_command
 bcs ua_init_return
 ldx #0
@load:
 lda ua_load,x
 sta $df1d
 inx
 cpx #10
 bne @load
 jsr ua_command
 bcs @close
 lda #1
 sta _ua_ready
@close:
 lda #1
 sta $df1d
 lda #3
 sta $df1d
 jsr ua_command
 lda #0
 sta $df20
 sta $df40
ua_init_return:
 rts
ua_command:
 lda #1
 sta $df1c
 ldx #0
 ldy #0
@wait:
 lda $df1c
 and #$30
 cmp #$20
 beq @response
 dex
 bne @wait
 dey
 bne @wait
 lda #$ff
 sta _ua_status
 sec
 rts
@response:
 lda $df1f
 cmp #$30
 bne @bad
 lda $df1f
 cmp #$30
 bne @bad
 lda #0
 sta _ua_status
 lda #2
 sta $df1c
 clc
 rts
@bad:
 sta _ua_status
 lda #2
 sta $df1c
 sec
 rts
ua_shot:
 lda _stage
 cmp #1
 bne :+
 jmp ua_laser
:
 ldx #0
 ldy #0
 jsr ua_program
 lda _weapon
 beq @gate
 ; MG uses the same authentic transient, clipped to 136 ms.
 lda #0
 sta $df29
 lda #$2e
 sta $df2a
 lda #$e0
 sta $df2b
@gate:
 lda #$11
 sta $df20
 rts
ua_laser:
 ldx #27
 ldy #0
 jsr ua_program
 lda #$11
 sta $df20
 rts
ua_scream:
 lda _scream_variant
 eor #1
 sta _scream_variant
 beq :+
 ldx #36
 bne :++
:
 ldx #9
:

 ldy #$20
 jsr ua_program
 lda #$11
 sta $df40
 rts
ua_program:
 lda #0
 sta $df20,y
 lda #48
 sta $df21,y
 lda #8
 sta $df22,y
 stx ua_fetch+1
 ; Table index differs from channel displacement; use absolute self-modified read.
 txa
 clc
 adc #<sample_regs
 sta ua_fetch+1
 lda #>sample_regs
 adc #0
 sta ua_fetch+2
 ldx #0
ua_next:
ua_fetch:
 lda sample_regs
 pha
 lda ua_offsets,x
 sta ua_store+1
 tya
 clc
 adc #$20
 clc
 adc ua_store+1
 sta ua_store+1
 pla
ua_store:
 sta $df24
 inc ua_fetch+1
 bne :+
 inc ua_fetch+2
:
 inx
 cpx #9
 bne ua_next
 rts




.export _scream_variant

.import _sound_time
