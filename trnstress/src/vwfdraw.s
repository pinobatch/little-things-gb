;
; Variable width font drawing for Game Boy
; Copyright 2018 Damian Yerrick
; 
; SPDX-License-Identifier: Zlib
;
include "src/hardware.inc"
include "src/global.inc"

def USE_HBLANK_COPY EQU 0

def lineImgBufLen EQU 128  ; number of 1bpp planes

; Align is a logarithm in rgbasm, unlike in ca65 where it's an actual
; byte count
section "lineImgBuf",wram0,align[8]
lineImgBuf:: ds lineImgBufLen * 2

def CHAR_BIT EQU 8
def LOG_GLYPH_HEIGHT EQU 3
def GLYPH_HEIGHT EQU (1 << LOG_GLYPH_HEIGHT)
def GLYPH_HEIGHT_MINUS_1 EQU GLYPH_HEIGHT + (-1)

def NUM_GLYPHS EQU 104
export NUM_GLYPHS
def FIRST_PRINTABLE_CU EQU $18
export FIRST_PRINTABLE_CU

; Approximate timing for vwfPutTile:
;
; The glyph drawing itself is about 478 cycles for height 8
; Per glyph: 46
; call: 6, rot glyphid: 5, get dstoffset: 6, get bitmask: 12, 
; get shift slide jump: 6, split glyphid: 8, final ret: 3
; Per row: 53+(X%8) avg 56 or 12 if blank
; read blank sliver: 7
; read sliver: 6, shift sliver: 8+(X%8) avg 11, split sliver: 8,
; left OR: 11, right OR: 15, row advance: 5
;
; vwfPuts thus runs at avg 519 cycles/character
; load ch: 6, save and draw: 18+478 (or 3 for space),
; add width: 12, buffer overflow test: 5
;
; Further work:
; not drawing space (" ") at all
; skipping shifting for $00 slivers

section "vwfPutTile", ROM0, align[3]  ; log(CHAR_BIT) to not cross page
not_ff_shr_x:: db $00,$80,$C0,$E0,$F0,$F8,$FC,$FE

; The second half of the routine comes before the first half to ease alignment
vwfPutTile_shifter:
  local hShifterMask, 1
  local hDestAddrLo, 1

  rept CHAR_BIT-1
    rrca
  endr
  ld h,a  ; H: all glyph bits, circularly rotated

  ; Load destination address
  ldh a,[.hDestAddrLo]
  ld l,a

  ; Break up glyph bits into 2 bytes
  ldh a,[.hShifterMask]
  and h
  ld c,a  ; C: right half bits
  xor h   ; A: left half bits

  ; OR in the left byte
  ld h,high(lineImgBuf)
  or [hl]
  ld [hl],a

  ; OR in the left
  ld a,l
  add GLYPH_HEIGHT
  ld l,a
  ld a,[hl]
  or c
  ld [hl],a
  ld a,l
  sub GLYPH_HEIGHT-1
.have_new_dstoffset:
  ldh [.hDestAddrLo],a

  ; Advance to next row
  and GLYPH_HEIGHT-1
  ret z

  ; Shift each row
.rowloop:
  ; Read an 8x1 sliver of the glyph into A
  ld a,[de]
  inc e
  or a
  jr z,.sliver_is_blank

  ; Shift the sliver
  ld h,high(vwfPutTile_shifter)
  ld l,b
  jp hl

  ; Fast path handling for blank slivers
.sliver_is_blank:
  ldh a,[.hDestAddrLo]
  inc a
  jr .have_new_dstoffset

;;
; Draws the tile for glyph A at horizontal position B
; using the font at vwfChrData, which must be aligned to
; LOG_GLYPH_HEIGHT bits
vwfPutTile::

  ; Calculate address of glyph
  ld h,0
  ld l,a
  ld de,vwfChrData - (FIRST_PRINTABLE_CU*GLYPH_HEIGHT)
  rept LOG_GLYPH_HEIGHT
    add hl,hl
  endr
  add hl,de

  ; Get the destination offset in line buffer
  ld a,b
  if LOG_GLYPH_HEIGHT > 3
    rept LOG_GLYPH_HEIGHT-3
      rlca
    endr
  endc
  and $100-GLYPH_HEIGHT
  ldh [vwfPutTile_shifter.hDestAddrLo],a
  
  ; Get the mask of which bits go here and which to the next tile
  xor b
  ld e,a  ; E = horizontal offset within tile
  ld bc,not_ff_shr_x
  add c
  ld c,a  ; BC = ff_shr_x+horizontal offset
  ld a,[bc]
  ldh [vwfPutTile_shifter.hShifterMask],a

  ; Calculate the address of the shift routine
  ld a,low(vwfPutTile_shifter) + CHAR_BIT - 1
  sub e
  ld b,a  ; B: which shifter to use

  ld d,h
  ld e,l
  jr vwfPutTile_shifter.rowloop

;;
; Write glyphs for the 8-bit-encoded characters string at (hl) to
; X position B in the VWF buffer
; @return HL pointer to the first character not drawn
vwfPuts::
.chloop:
  ; Load character, stopping at control character
  ld a,[hl+]
  cp FIRST_PRINTABLE_CU
  jr c,.decret

  ; Save position, draw glyph, load position
  ld c,a
  push hl
  push bc
  cp " "  ; Optimization: Don't draw glyph for space character
  call nz, vwfPutTile
  pop bc
  pop hl
  ld a,c
  
  ; Add up the width of the glyph
  ld de,vwfChrWidths-FIRST_PRINTABLE_CU
  add e
  ld e,a
  adc d
  sub e
  ld d, a
  ld a,[de]
  add b
  ld b,a

  cp lineImgBufLen
  jr c,.chloop
  ret

; Return points HL at the first undrawn character
.decret:
  dec hl
  ret

;;
; Calculates the width of a string in pixels
; @param HL pointer to unprintable-terminated string
; @return A: last char; B: width; HL points at end of string;
; C unchanged; DE trashed
vwfStrWidth::
  ld b,0
.loop:
  ld a,[hl+]
  sub FIRST_PRINTABLE_CU
  jr c,vwfPuts.decret

  ld de,vwfChrWidths
  add e
  ld e,a
  adc d
  sub e
  ld d, a
  ld a,[de]
  add b
  ld b,a
  jr .loop

;;
; Clears the line image.
; @return A = C = 0; HL = lineImgBuf + lineImgBufLen
vwfClearBuf::
  ld hl,lineImgBuf
  ld c,lineImgBufLen/4
  xor a
.loop:
  rept 4
    ld [hl+],a
  endr
  dec c
  jr nz,.loop
  ret

;;
; Copies the VWF buffer to VRAM address HL using fg color 1 or 3
; and bg color 0
; @param HL destination address
; @param DE source address within lineImgBuf (if using _continue)
; @param C tile count (if using _lenC)
; @param B $00 for color 1 on 0 or $FF for color 3 on 0
; @return DE end of lineImgBuf; C=0; B unchanged
vwfPutBuf03::
  ld c,lineImgBufLen/8
  fallthrough vwfPutBuf03_lenC
vwfPutBuf03_lenC::
  ld de,lineImgBuf
  fallthrough vwfPutBuf03_continue_lenC
vwfPutBuf03_continue_lenC::  ; this entry for intermediate WRAM buffer
  sla c
.loop:
  rept 4
    ld a,[de]
    inc e
    ld [hl+],a
    and b
    ld [hl+],a
  endr
  dec c
  jr nz,.loop
  ret

  if USE_HBLANK_COPY

;;
; Copies the VWF line buffer to WRAM during hblank.
;
; Drawing a glyph with 2 nonblank rows and 6 blank rows takes about
; 400 cycles.  The 112 pixel window can hold about 25 glyphs across,
; totaling 13000 cycles or 88 scanlines to fill the buffer.
; Copying it to VRAM using the most general loop for forced-blank
; use at 4x unroll is 9 cycles/byte, completing 112 bytes in 1008.
; But when OAM DMA is active, only 1140-176=964 cycles are available.
; So most of this copying will be done during hblank, which has
; about 69 cycles depending on exact scroll and sprite positions,
; so long as the copy routine stays out of the way of the rSTAT IRQ.
;
; @param HL the address to start writing
; @param C number of tiles to copy
; clobbers all regs
vwfPutBufHBlank::
  ld de,lineImgBuf
  .tileloop:

    ; Read the first tile row and keep it in registers ready to
    ; write as soon as possible
    ld a,[de]
    inc e
    ld b,a

    ; Wait for either vblank or the very start of hblank.
    ; This takes several spinloops.

    ; Skip lines around start of frame, as line 0 has no hblank
    ; period before the draw time.  So if on line 153 or 0, wait
    ; for line 1.
.unsafe153:
    ldh a,[rLY]
    or a
    jr z,.unsafe153
    cp 153
    jr z,.unsafe153
    cp 144
    jr nc,.safetime

    ; The two lines above the split point are also tricky, as the
    ; rSTAT IRQ handler can use enough cycles to overflow hblank.
    ldh a,[rLYC]
    push hl
    push bc
    sub 2
    ld c,a
    ld hl,rLY
    .nonmiddle:
      ld a,[HL]
      sub c
      cp 2
      jr c,.nonmiddle
    pop bc

    ; Wait for mode 1 (vblank) or 3 (draw)
    ld hl,rSTAT
    .nonhblank:
      bit 0,[HL]
      jr z,.nonhblank

    ; Wait for mode 0 (hblank) or 1 (vblank)
    .nondraw:
      bit 1,[HL]
      jr nz,.nondraw
    pop hl

.safetime:
    ; Now that we're in a safe time, copy the tile's first line
    ld a,b
    ld [hl+],a
    inc l

    ; Copy the rest of the lines
    rept 7
      ld a,[de]
      ld [hl+],a
      inc l
      inc e
    endr
  dec c
  jr nz,.tileloop
  ret

  endc
