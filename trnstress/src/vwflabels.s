;
; Variable width font label drawing for Game Boy
; Copyright 2018 Damian Yerrick
; SPDX-License-Identifier: Zlib
;
include "src/hardware.inc"
section "vwflabels",ROM0

; Drawing text at random places on the screen ;;;;;;;;;;;;;;;;;;;;;;;

;;
; @param DE destination of rendered tiles in CHR RAM, shifted right
; by 4: E is tile number and D is $08 or $09
; @param HL a list of x pixels, y pixels, ascii chars, terminator,
; where terminator is $0A between strings or $00 at end
vwfDrawLabels::
  push de  ; Position in CHR RAM won't be needed until much later
  push hl
  call vwfClearBuf
  pop hl

  push hl
  inc hl  ; Skip X
  inc hl  ; Skip Y
  call vwfStrWidth
  pop hl  ; B: width of string; HL: X; stack: DE
  
  ; Calculate the width in pixels of tiles occupied by this string,
  ; including left and right partial tiles
  ld a,[hl]
  and %00000111  ; A: X coord within tile
  add b          ; A: X coord at right side of string

  ; Round up to nearest whole tile
  dec a          ; A: Last pixel of string
  or %00000111   ; A: Last pixel of last tile of string
  inc a          ; A: First pixel beyond last tile of string
  srl a
  srl a
  srl a          ; A: Tile count
  push af        ; Stack: Width in tiles, CHR RAM destination

  ; Retrieve rest of label's position
  ld a,[hl+]
  ld b,a
  ld a,[hl+]
  and %11111000  ; discard low bits of Y
  ld c,a
  push bc  ; Stack: XY, width in tiles, CHR RAM destination
  ld a,b
  and %00000111
  ld b,a   ; B = position of text within first tile
  call vwfPuts
  
  ; The text is in the line buffer.
  ; Rearrange the stack for blitting it to VRAM.
  pop bc
  pop af
  pop de
  push hl
  push de
  push af  ; Stack: width in tiles, CHR RAM destination, string end
  
  ; Calculate XY position in tilemap
  ld l,c
  ld h,high(_SCRN0)>>2
  add hl,hl
  add hl,hl
  ld a,b  ; A: x position in pixels
  srl a
  srl a
  srl a   ; A: x position in tiles
  or l
  ld l,a  ; HL: starting position in tilemap

  ; Write tiles to tilemap
  pop bc  ; B: width in tiles; C: garbage flags
  ld c,b  ; Save width in tiles for later
  pop de  ; D: pattern table (8 or 9); E: starting tile number
  ld a,e
.tilemaploop:
  ld [hl+],a
  inc a
  dec b
  jr nz,.tilemaploop

  ; Write pixels to tiles
  ld h,d
  ld l,e
  add hl,hl
  add hl,hl
  add hl,hl
  add hl,hl  ; HL: destination tile address
  ld a,e     ; Calculate new tile number
  add c
  ld e,a
  adc d  ; Wrap from tile $8FF to $900, not $8FF to $800
  sub e
  ld d, a
  push de  ; Stack: new tilenum, string end

  ; Copy C tiles' worth of pixels
;  ld b,$00  ; 0 means colors 0/1; B is still 0 after the last loop
  call vwfPutBuf03_lenC
  pop de
  pop hl

  ; Read which terminator was encounted (null or linefeed)
  ld a,[hl+]
  or a
  jr nz,vwfDrawLabels
  ret

  if 0
xytexttest:
  db  12, 32,"Hello 12,32",10
  db  13, 40,"Hello 13,40",10
  db  14, 48,"Hello 14,48",10
  db  15, 56,"Hello 15,56",10
  db  16, 64,"Hello 16,64",10
  db  17, 72,"Hello 17,72",10
  db  18, 80,"Hello 18,80",10
  db  19, 88,"Hello 19,88",0
  endc
