;
; Basic LCD routines for Game Boy
;
; Copyright 2018 Damian Yerrick
; 
; This software is provided 'as-is', without any express or implied
; warranty.  In no event will the authors be held liable for any damages
; arising from the use of this software.
; 
; Permission is granted to anyone to use this software for any purpose,
; including commercial applications, and to alter it and redistribute it
; freely, subject to the following restrictions:
; 
; 1. The origin of this software must not be misrepresented; you must not
;    claim that you wrote the original software. If you use this software
;    in a product, an acknowledgment in the product documentation would be
;    appreciated but is not required.
; 2. Altered source versions must be plainly marked as such, and must not be
;    misrepresented as being the original software.
; 3. This notice may not be removed or altered from any source distribution.
;
include "src/hardware.inc"
include "src/global.inc"

section "irqvars",HRAM
; Used for bankswitching BG CHR RAM
hVblanks:: ds 1

; Shadow OAM is a display list that gets copied using DMA to OAM
; after every frame in which sprites moved.
section "ram_ppuclear",WRAM0,ALIGN[8]
SOAM:: ds 160
oam_used:: ds 1  ; How much of the display list is used

SECTION "vblank_handler", ROM0[$0040]
  push af
  ldh a, [hVblanks]
  inc a
  ldh [hVblanks], a
  pop af
  reti

; Tiny sections help the linker can squeeze code into tiny holes
; between aligned or fixed-address sections.

SECTION "lcd_off", ROM0
;;
; Waits for blanking and turns off rendering.
;
; The Game Boy PPU halts entirely when rendering is off.  Stopping
; the signal outside vblank confuses the circuitry in the LCD panel,
; causing it to get stuck on a scanline.  This stuck state is the
; same as the dark horizontal line when you turn off the Game Boy.
;
; Turning rendering on, by contrast, can be done at any time and
; is done by writing the nametable base addresses and sprite size
; to rLCDC with bit 7 set to true.
lcd_off::
  call busy_wait_vblank

  ; Use a RMW instruction to turn off only bit 7
  ld hl, rLCDC
  res 7, [hl]
  ret

SECTION "wait_vblank_irq", ROM0[$10]
;;
; Waits for the vblank ISR to increment the count of vertical blanks.
; Will lock up if DI, vblank IRQ off, or LCD off.
; Clobbers A, HL
wait_vblank_irq::
  ld hl, hVblanks
  ld a, [hl]
  jr wait_vblank_irq_tail

section "wait_vblank_run_dma", ROM0[$18]
wait_vblank_run_dma::
  rst wait_vblank_irq
  fallthrough run_dma
run_dma::
  ld a, SOAM >> 8
  ld bc, (41 << 8) | low(rDMA)
  jr run_dma_tail
wait_vblank_irq_tail:
  halt
  nop
  cp [hl]
  jr z, wait_vblank_irq_tail
  ret

SECTION "busy_wait_vblank", ROM0

;;
; Waits for forced blank (rLCDC bit 7 clear) or vertical blank
; (rLY >= 144).  Use before VRAM upload or before clearing rLCDC bit 7.
busy_wait_vblank::
  ; If rLCDC bit 7 already clear, we're already in forced blanking
  ldh a,[rLCDC]
  rlca
  ret nc

  ; Otherwise, wait for LY to become 144 through 152.
  ; Most of line 153 is prerender, during which LY reads back as 0.
.wait:
  ldh a, [rLY]
  cp 144
  jr c, .wait
  ret

SECTION "rom_ppuclear", ROM0

;;
; Moves sprites in the display list from SOAM+[oam_used] through
; SOAM+$9C offscreen by setting their Y coordinate to 0, which is
; completely above the screen top (16).
lcd_clear_oam::
  ; Destination address in shadow OAM
  ld hl, oam_used
  ld a, [hl]
  and $FC
  ld l,a

  ; iteration count
  rrca
  rrca
  add 256 - 40
  ld c,a

  xor a
.rowloop:
  ld [hl+],a
  inc l
  inc l
  inc l
  inc c
  jr nz, .rowloop
  ret

load_full_nam::
  ld bc,256*20+18
  fallthrough load_nam

;;
; Copies a B column by C row tilemap from HL to screen at DE.
; Assumes LCD is off.
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
