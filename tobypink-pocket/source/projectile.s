.export _weapon_projectile
.import _shot,_shot_x,_shot_y,_shot_dir,_shot_vy,_enemies,_drops,_damage_enemy,_show_drop,_distance
.import _bullet_step
.import decsp1,incsp1,pushax,pusha,mulax7,mulax10,mulax3,shlax3
.importzp c_sp,ptr1,tmp1,sreg
.macpack longbranch
.segment "CODE"
.proc _weapon_projectile: near
 jsr decsp1
L000D:	lda     _shot
	jeq     L0034
	ldx     #$00
	lda     _shot_dir
	bpl     L0012
	dex
L0012:	jsr _bullet_step
	clc
	adc     _shot_x
	sta     _shot_x
	txa
	adc     _shot_x+1
	sta     _shot_x+1
	ldx     #$00
	lda     _shot_vy
	bpl     L0013
	dex
L0013:	clc
	adc     _shot_y
	sta     _shot_y
	txa
	adc     _shot_y+1
	sta     _shot_y+1
	ldx     _shot_x+1
	cpx     #$80
	bcs     L0044
	lda     _shot_x
	cmp     #$35
	lda     _shot_x+1
	sbc     #$01
	bvs     L0016
	eor     #$80
L0016:	bmi     L0044
	lda     _shot_y
	cmp     #$14
	lda     _shot_y+1
	sbc     #$00
	bvc     L0017
	eor     #$80
L0017:	bmi     L0044
	lda     _shot_y
	cmp     #$AB
	lda     _shot_y+1
	sbc     #$00
	bvs     L0018
	eor     #$80
L0018:	bmi     L0044
	lda     #$00
	jmp     L0046
L0044:	lda     #$00
	sta     _shot
	jmp     L004D
L0046:	tay
L0036:	sta     (c_sp),y
	cmp     #$02
	jcs     L001C
	ldx     #$00
	lda     (c_sp),y
	jsr     mulax10
	clc
	adc     #<(_enemies)
	sta     ptr1
	txa
	adc     #>(_enemies)
	sta     ptr1+1
	ldy     #$07
	lda     (ptr1),y
	jne     L001D
	lda     _shot_x
	ldx     _shot_x+1
	clc
	adc     #$04
	bcc     L0021
	inx
L0021:	jsr     pushax
	ldy     #$02
	ldx     #$00
	lda     (c_sp),y
	jsr     mulax10
	clc
	adc     #<(_enemies)
	sta     ptr1
	txa
	adc     #>(_enemies)
	sta     ptr1+1
	dey
	lda     (ptr1),y
	tax
	dey
	lda     (ptr1),y
	clc
	adc     #$0A
	bcc     L0022
	inx
L0022:	jsr     _distance
	cmp     #$10
	txa
	sbc     #$00
	bvc     L0023
	eor     #$80
L0023:	bpl     L001D
	lda     _shot_y
	ldx     _shot_y+1
	jsr     pushax
	ldy     #$02
	ldx     #$00
	lda     (c_sp),y
	jsr     mulax10
	clc
	adc     #<(_enemies)
	sta     ptr1
	txa
	adc     #>(_enemies)
	sta     ptr1+1
	iny
	lda     (ptr1),y
	tax
	dey
	lda     (ptr1),y
	jsr     _distance
	cmp     #$14
	txa
	sbc     #$00
	bvc     L0024
	eor     #$80
L0024:	bpl     L001D
	ldy     #$00
	lda     (c_sp),y
	jsr     pusha
	lda     #$02
	jsr     _damage_enemy
	lda     #$00
	sta     _shot
	jmp     L001C
L001D:	ldy     #$00
	clc
	lda     #$01
	adc     (c_sp),y
	jmp     L0036
L001C:	lda     _shot
	jeq     L0029
	lda     #$00
	tay
L0037:	sta     (c_sp),y
	cmp     #$06
	jcs     L0029
	ldx     #$00
	lda     (c_sp),y
	jsr     mulax3
	clc
	adc     #<(_drops)
	sta     ptr1
	txa
	adc     #>(_drops)
	sta     ptr1+1
	ldy     #$02
	lda     (ptr1),y
	cmp     #$01
	jne     L002A
	lda     _shot_x
	ldx     _shot_x+1
	jsr     pushax
	ldy     #$02
	ldx     #$00
	lda     (c_sp),y
	jsr     mulax3
	sta     ptr1
	txa
	clc
	adc     #>(_drops)
	sta     ptr1+1
	ldy     #<(_drops)
	ldx     #$00
	lda     (ptr1),y
	jsr     shlax3
	jsr     _distance
	cmp     #$0C
	txa
	sbc     #$00
	bvc     L002E
	eor     #$80
L002E:	bpl     L002A
	lda     _shot_y
	ldx     _shot_y+1
	clc
	adc     #$09
	bcc     L002F
	inx
L002F:	jsr     pushax
	ldy     #$02
	ldx     #$00
	lda     (c_sp),y
	jsr     mulax3
	clc
	adc     #<(_drops)
	sta     ptr1
	txa
	adc     #>(_drops)
	sta     ptr1+1
	dey
	ldx     #$00
	lda     (ptr1),y
	jsr     shlax3
	jsr     _distance
	cmp     #$0C
	txa
	sbc     #$00
	bvc     L0030
	eor     #$80
L0030:	bpl     L002A
	ldx     #$00
	lda     (c_sp,x)
	jsr     mulax3
	clc
	adc     #<(_drops)
	sta     ptr1
	txa
	adc     #>(_drops)
	sta     ptr1+1
	lda     #$00
	ldy     #$02
	sta     (ptr1),y
	tay
	lda     (c_sp),y
	jsr     _show_drop
	lda     #$00
	sta     _shot
	jmp     L0029
L002A:	ldy     #$00
	clc
	lda     #$01
	adc     (c_sp),y
	jmp     L0037
L004D:
L0029:
L0034:	jmp incsp1

.endproc

