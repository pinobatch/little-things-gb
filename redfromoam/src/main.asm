; preliminary name: Red from OAM

include "src/hardware.inc"

; Macros ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;
; Syntax: lb rp, high, low
; Sets the high and low bytes of a register pair
macro lb
  ld \1, ((\2) << 8) | (low(\3))
  endm

;;
; Syntax: ldxy rp, xpos, ypos[, mapbase]
; Sets a register pair to the address of (x, y) tile coordinates
; within a tilemap.
; @param rp a register pair (BC, DE, HL)
; @param x horizontal distance in tiles from left (0-31)
; @param y vertical distance in tiles from top (0-31)
; @param mapbase start address of 32-cell-wide tilemap:
;   _SCRN0 (default), _SCRN1, or a virtual tilemap in WRAM.
macro ldxy
  if _NARG < 4
    ld \1, (\3) * SCRN_VX_B + (\2) + _SCRN0
  else
    ld \1, (\3) * SCRN_VX_B + (\2) + (\4)
  endc
  endm

;;
; Syntax: dwxy xpos, ypos[, mapbase]
; Writes an X, Y position within a tilemap as a 16-bit address.
macro dwxy
  if _NARG < 3
    dw (\2) * SCRN_VX_B + (\1) + _SCRN0
  else
    dw (\2) * SCRN_VX_B + (\1) + (\3)
  endc
  endm

;;
; Syntax: drgb $FF9966 for color #FF9966
; Divides each hex tuplet by 8 and rounds down, forming an RGB555
; color word suitable for SNES/SGB or GBC/GBA/DS.
macro drgb
  dw (\1 & $F80000) >> 19 | (\1 & $00F800) >> 6 | (\1 & $0000F8) << 7
endm

; Main program ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
section "main", ROM0
main:
  ld a, 84
  ldh [rLYC], a
  ld a, STATF_LYC
  ldh [rSTAT], a
  xor a
  ldh [rIF], a
  ld a, IEF_STAT
  ldh [rIE], a
  ei
  ld a, $E4
  ldh [rBGP], a
  ldh [rOBP0], a
  cpl
  ldh [rOBP1], a

  ; Load tile data
  ld hl, $8E00
  ld de, chr_2bpp
  ld bc, $10000 + chr_2bpp - chr_2bpp.end
  .chrloop:
    ld a, [de]
    inc de
    ld [hl+], a
    ld [hl+], a
    inc c
    jr nz, .chrloop
    inc b
    jr nz, .chrloop

if 0
  ld hl, $8FF0
  ld a, 1
  .controlloop:
    ld [hl+], a
    inc l
    add a
    jr nc, .controlloop
endc
  ld a, %10101010
  ld [$8FF6], a  ; y=3 plane=0
  ; the test line is Y+4 but it's vflipped

  ; Clear tilemap
  ld a, $E0  ; blank tile
  ; ld c, 0  ; guaranteed by chrloop
  ld hl, $9800
  rst memset_tiny
  rst memset_tiny
  rst memset_tiny

  ; Fill tilemap
  ld de, tilemap_strings
  jr .stringsloop_next
  .stringsloop
    ld c, a
    inc de
    ld a, [de]
    ld l, a
    inc de
    ld a, [de]
    ld h, a
    inc de
    ld a, [de]
    inc de
    rst memset_inc
  .stringsloop_next
    ld a, [de]
    or a
    jr nz, .stringsloop

  ; Behavior of PPU OAM reading during OAM DMA per SameBoy source
  ; During mode 2 on DMG and CGB pre-E:
  ;   The PPU reads $FF (out of range)
  ;   ref: add_object_from_index() in display.c
  ;'During mode 2 on CGB E and later:
  ;   It looks like the PPU uses the last read X or Y coordinate
  ;   respectively.
  ;   ref: add_object_from_index() in display.c
  ; During mode 3 (and always on CGB E and later):
  ;   The PPU reads the selected half (low or high) of the 16-bit
  ;   unit currently being written by DMA.
  ;   Tile number overwrites last read Y (affects >= CGB E).
  ;   gb->oam[(gb->dma_current_dest & ~1) | (addr & 1)];
  ;   ref: oam_read() in display.c
  ;   ref: GB_display_run() in display.c near /* Handle objects */

  ; Fill shadow OAM
  ld de, wShadowOAM
  ld hl, oamdata
  call memcpy_pascal16

  ld a, LCDCF_ON|LCDCF_BGON|LCDCF_BG8800|LCDCF_BG9800|LCDCF_OBJON
  ldh [rLCDC], a

forever:
  halt
  ; at the start of the test line, entering the interrupt is 5
  ; cycles and reti is 4 cycles
  ; PPU evaluates 2 sprites per CPU cycle
  ; burn a few cycles before run_dma
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  di
  call run_dma
  ei
  jr forever

section "CHR", ROM0, ALIGN[4]
chr_2bpp:
  incbin "obj/gb/chr.2bpp"
  .end

section "TILEMAP", ROM0
tilemap_strings:
  db 9      ; Title
  dwxy 4, 2
  db $E1
  db 11     ; Version/author
  dwxy 4, 3
  db $F0
  db 4      ; Control line->
  dwxy 3, 8
  db $FB
  db 3
  dwxy 7, 8
  db $ED
  db 6      ; Test line->
  dwxy 4, 10
  db $EA
  db 0      ; End of list

section "OAMMAP", ROM0
oamdata:
  dw .end-.start
  .start

  ; Data to interfere with attribute reading
  ds 24*4, $FF

  ; Test line consists of four $E0 sprites at (80, 80)
  ; whose character+flip is changed to $FF by OAM DMA blocking
  db 80+16, 80+8, $E0, $00
  db 80+16, 88+8, $E0, $00
  db 80+16, 96+8, $E0, $00
  db 80+16, 104+8, $E0, $00
  db 80+16, 112+8, $E0, $00
  db 80+16, 120+8, $E0, $00
  db 80+16, 128+8, $E0, $00
  db 80+16, 136+8, $E0, $00

  ; Control line consists of four $FF sprites at (80, 64)
  db 64+16, 80+8, $FF, $FF
  db 64+16, 88+8, $FF, $FF
  db 64+16, 96+8, $FF, $FF
  db 64+16, 104+8, $FF, $FF
  db 64+16, 112+8, $FF, $FF
  db 64+16, 120+8, $FF, $FF
  db 64+16, 128+8, $FF, $FF
  db 64+16, 136+8, $FF, $FF
  .end

; Administrative stuff ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section "Shadow OAM", WRAM0, ALIGN[8]
wShadowOAM: ds 160
wOAMUsed: ds 1

section "stack", WRAM0, ALIGN[1]
wStackTop: ds 64
wStackStart:

section "header", ROM0[$100]
  nop
  jp init
  ds 76, $00
init:
  di
  ld sp, wStackStart
  call lcd_off
;  ld a, $FF
;  ldh [hCurKeys], a
  ld hl, hramcode_LOAD
  ld de, hramcode_RUN
  call memcpy_pascal16
  xor a
  ld hl, wShadowOAM
  ld c, 160
  rst memset_tiny
  call run_dma
  jp main

section "stat_isr", ROM0[$48]
  reti

section "ppuclear", ROM0
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

lcd_off::
  call busy_wait_vblank

  ; Use a RMW instruction to turn off only bit 7
  ld hl, rLCDC
  res 7, [hl]
  ret

;;
; Moves sprites in the display list from wShadowOAM+[wOAMUsed]
; through wShadowOAM+$9C offscreen by setting their Y coordinate to
; 0, which is completely above the screen top (16).
lcd_clear_oam::
  ; Destination address in shadow OAM
  ld hl, wOAMUsed
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

section "memset_tiny",ROM0[$08]
;;
; Writes C bytes of value A starting at HL.
memset_tiny::
  ld [hl+],a
  dec c
  jr nz,memset_tiny
  ret

section "memset_inc",ROM0[$10]
;;
; Writes C bytes of value A, A+1, ..., A+C-1 starting at HL.
memset_inc::
  ld [hl+],a
  inc a
  dec c
  jr nz,memset_inc
  ret

section "memcpy", ROM0
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

section "HRAMCODE_src", ROM0
;;
; While OAM DMA is running, the CPU keeps fetching instructions
; while ROM and WRAM are inaccessible.  A program needs to jump to
; HRAM and busy-wait 160 cycles until OAM DMA finishes.
hramcode_LOAD:
  dw hramcode_RUN_end-hramcode_RUN
load "HRAMCODE", HRAM
hramcode_RUN:

;;
; Copy a display list from shadow OAM to OAM
; @param HL address to read once while copying is in progress
; @return A = value read from [HL]
run_dma::
  ld a, wShadowOAM >> 8
  ldh [rDMA],a
  ld b, 40
.loop:
  dec b
  jr nz,.loop
  ret

hramcode_RUN_end:
endl
