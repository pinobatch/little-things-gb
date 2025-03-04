include "src/hardware.inc"

section "irqvars", HRAM
hVblanks:: ds 1

section "vblankisr", ROM0[$40]
  push af
  ldh a, [hVblanks]
  inc a
  ldh [hVblanks], a
  pop af
  reti

section "header", ROM0[$100]
  nop
  jp reset
  ds 76, $00

section "reset", ROM0
reset:
  di
  xor a
;  ldh [rBGP], a
  ldh [rSCX], a
  ldh [rSCY], a
  ldh [hVblanks], a
  ld [cur_keys], a
  
  ; turn off LCD
  ldh a, [rLCDC]
  add a
  jr nc, .nowait
  .spin_lcd_off:
    ld a, [rLY]
    xor 144
    jr nz, .spin_lcd_off
    ldh [rLCDC], a
  .nowait:

  ; clear VRAM and OAM
  ld de, _VRAM
  ld h, e
  ld bc, $2000
  call memset
  ld de, _OAMRAM
  ld bc, $A0
  call memset

  ; load used portion of VRAM
  ld hl, bg_2bpp
  ld de, $8000
  ld bc, bg_nam - bg_2bpp
  call memcpy
  ld de, _SCRN0 + 1 + 1 * 32
  ld bc, $110E
  call load_nam

  call audio_init
  xor a
  ldh [rIF], a
  inc a
  ldh [rIE], a
  ld a, %01101100
  ldh [rBGP], a
  ld a, LCDCF_ON|LCDCF_BLK01|LCDCF_BG9800|LCDCF_BGON
  ldh [rLCDC], a
  ei

.mainloop:
  call wait_vblank_irq
  call audio_update
  call read_pad

  ld a, [new_keys]
  or a
  jr z, .no_new_keys
    ld b, $FF
    ld b, b
    .find_new_key:
      inc b
      srl a
      jr nc, .not_pressed
        push af
        push bc
        ld a, b
        call audio_play_fx
        pop bc
        pop af
      .not_pressed:
      jr nz, .find_new_key
  .no_new_keys:
  jr .mainloop

section "memcpy", ROM0
clear_scrn0_to_0::
  ld h, 0
clear_scrn0_to_h::
  ld de,_SCRN0
  ld bc,32*32
  ; fall through to memset

;;
; Writes BC bytes of value H starting at DE.
memset::
  ; Increment B if C is nonzero
  dec bc
  inc b
  inc c
  ld a, h
.loop:
  ld [de],a
  inc de
  dec c
  jr nz,.loop
  dec b
  jr nz,.loop
  ret

;;
; Copy a string preceded by a 2-byte length from HL to DE.
; @param HL source address
; @param DE destination address
memcpy_pascal16::
  ld a, [hl+]
  ld c, a
  ld a, [hl+]
  ld b, a
  ; fall through to memcpy

;;
; Copies BC bytes from HL to DE.
; @return A: last byte copied; HL at end of source;
; DE at end of destination; B=C=0
memcpy::
  ; Increment B if C is nonzero
  dec bc
  inc b
  inc c
.loop:
  ld a, [hl+]
  ld [de],a
  inc de
  dec c
  jr nz,.loop
  dec b
  jr nz,.loop
  ret


SECTION "rom_ppuclear", ROM0
;;
; Waits for the vblank ISR to increment the count of vertical blanks.
; Will lock up if DI, vblank IRQ off, or LCD off.
; Clobbers A, HL
wait_vblank_irq::
  ld hl, hVblanks
  ld a, [hl]
.loop:
  halt
  nop
  cp [hl]
  jr z, .loop
  ret

;;
; Copies a B column by C row tilemap from HL to screen at DE.
load_nam::
  push bc
  push de
  .byteloop:
    ld a,[hl+]
    ld [de],a
    inc de
    dec b
    jr nz,.byteloop

  ; Move to next screen row
  pop de
  ld a,32
  add e
  ld e,a
  jr nc,.no_inc_d
    inc d
  .no_inc_d:

  ; Restore width; do more rows remain?
  pop bc
  dec c
  jr nz,load_nam
  ret

section "bgdata", ROM0
bg_2bpp: incbin "build/bg.2bpp"
bg_nam:  incbin "build/bg.nam"
