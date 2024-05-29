include "src/hardware.inc"
include "src/global.inc"

def SIZEOF_SGB_PACKET EQU 16
def CHAR_BIT EQU 8

section "help_line_buffer", WRAM0, ALIGN[5]
help_line_buffer: ds 32

; Super Game Boy detection ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section "sgb_detection", ROM0

;;
; Sets hCapability to 1 if the player number is 2 or 4.
; rP1 must be $30 (key matrix released), such as after sgb_send or
; read_pad.  When this happens, SGB returns 4 - player number in
; bits 1-0, where 3 means player 1, 2 means player 2, etc.
; Fully reading advances to the next player.
capa_1_if_player_2:
  call read_pad
  ldh a, [rP1]
  rra  ; players 1 or 3: carry set; players 2 or 4: carry clear
  ret c
  ld a, $01
  ldh [hCapability],a
  ret

;;
; Freezes the display, such as while doing transfers.
sgb_freeze::
  call busy_wait_vblank
  ld a, $17*8+1
  ld b, $01  ; Freeze current screen
  jr sgb_send_ab

;;
; Unfreezes the display after a transfer is done.
sgb_unfreeze::
  call busy_wait_vblank
  ld a, $17*8+1
  ld b, $00  ; Freeze current screen
  jr sgb_send_ab

;;
; Sets hCapability to $01 if on a Super Game Boy.
detect_sgb::
  ; Try to set the SGB to 2-player mode
  di
  ld b, 1
  call sgb_set_bplus1_players
  call capa_1_if_player_2
  call capa_1_if_player_2

  ; Now turn off 2-player mode
  ld b, 0
  fallthrough sgb_set_bplus1_players

;;
; Set the number of controllers to read to B + 1, where B is
; 0, 1, or 3 for 1, 2, or 4 (multitap only) players.
sgb_set_bplus1_players::
  ld a, ($11 << 3) + 1
  fallthrough sgb_send_ab

;;
; Send a 1-packet SGB command whose first two bytes are A and B
; and whose remainder is zero filled.
sgb_send_ab::
  ld c, 0
  fallthrough sgb_send_abc

;;
; Send a 1-packet SGB command whose first three bytes are A, B, and C
; and whose remainder is zero filled.
sgb_send_abc::
  ld hl, help_line_buffer
  push hl
  ld [hl+], a
  ld a, b
  ld [hl+], a
  ld a, c
  ld [hl+], a
  xor a
  ld c, 13
  rst memset_tiny
  pop hl
  jr sgb_send

;;
; Clears the Super Game Boy attribute table to 0.
sgb_send_if_sgb::
  ldh a, [hCapability]
  rra
  ret nc
  fallthrough sgb_send

;;
; Sends a Super Game Boy packet starting at HL.
; Assumes no IRQ handler does any sort of controller autoreading.
; @return HL first byte after end of last packet
sgb_send::

  ; B: Number of remaining bytes in this packet
  ; C: Number of remaining packets
  ; D: Remaining bit data
  ld a,$07
  and [hl]
  ret z
  ld c,a
  di

.packetloop:
  ; Start transfer by asserting both halves of the key matrix
  ; momentarily.  (This is like strobing an NES controller.)
  xor a
  ldh [rP1],a
  ld a,$30
  ldh [rP1],a
  ld b,SIZEOF_SGB_PACKET
.byteloop:
  ld a,[hl+]  ; Read a byte from the packet

  ; Put bit 0 in carry and the rest (and a 1) into D.  Once this 1
  ; is shifted out of D, D is 0 and the byte is finished.
  ; (PB16 and IUR use the same principle for loop control.)
  scf      ; A = hgfedcba, CF = 1
  rra      ; A = 1hgfedcb, CF = a
  ld d,a
.bitloop:
  ; Send a 1 as $10 then $30, or a 0 as $20 then $30.
  ; This is constant time thanks to ISSOtm, unlike SGB BIOS
  ; which takes 1 mcycle longer to send a 0 then a 1.
  ld a,$10
  jr c, .bitIs1
  add a,a ; ld a,$20
.bitIs1:
  ldh [rP1],a
  ld a,$30
  ldh [rP1],a

  ldh a, [rIE]  ; Burn 3 cycles to retain original loops's speed

  ; Advance D to next bit (this is like NES MMC1)
  srl d
  jr nz,.bitloop
  dec b
  jr nz,.byteloop

  ; Send $20 $30 as end of packet
  ld a,$20
  ldh [rP1],a
  ld a,$30
  ldh [rP1],a

  call sgb_wait
  dec c
  jr nz,.packetloop
  ret

;;
; Waits 4 frames for Super Game Boy to have processed a command.
sgb_wait::
  ei
  call wait_vblank_set_raster
  call wait_vblank_set_raster
  call wait_vblank_set_raster
  fallthrough wait_vblank_set_raster
wait_vblank_set_raster:
  call wait_vblank_irq
  ldh a, [hRasterToUse]
  or a
  ret z
  ; A scramble is in effect. Set up raster.
  push hl
  push bc
  call setup_raster_for_scramble
  pop bc
  pop hl
  ret

section "sgbcode", ROM0

;;
; Turns off the LCD, sets scroll to 0, sets BGP to identity ($E4),
; turns off objects and window, sets BG pattern to $8000/$8800 and
; tilemap base to _SCRN0, and sets up an identity tilemap in _SCRN0
; for Super Game Boy *_TRN commands.  (Clobbers entire _SCRN0.)
sgb_load_trn_tilemap::
  call lcd_off
  ld a, %11100100
  ldh [rBGP], a
  ldh [rOBP0], a
  ld a, LCDCF_BGON|LCDCF_BLK01|LCDCF_BG9800
  ldh [rLCDC], a
  call clear_scrn0_to_0
  ld hl, _SCRN0+640
  push hl
  xor a
  ld c, a
  ldh [rSCX], a
  ldh [rSCY], a
  call memset_inc
  pop hl
  ld de, _SCRN0
  jp load_full_nam

def SGB_BORDER_COLS EQU 32
def SGB_BORDER_ROWS EQU 28
def SIZEOF_SGB_BORDER_TILEMAP EQU SGB_BORDER_ROWS * 2 * SGB_BORDER_COLS
def SIZEOF_SGB_BORDER_PALETTE EQU 16 * 2 * 3
def SGB_BORDER_PALETTE_ADDR EQU $8800

;;
; Sends a NORMAL border consisting of the following:
; 1. unique tile count minus 1
; 2. 1-256 4bpp tiles compressed with PB16
; 3. 1792 bytes of tilemap compressed with PB16
; 4. 96 bytes of palette (not compressed)
; @param HL start of border data
sgb_send_border::
  push hl
  call sgb_freeze
  ldh a, [hScrambleToUse]
  ldh [hRasterToUse], a
  call sgb_load_trn_tilemap
  pop de

  ; Load tiles
  ld a, [de]
  inc de
  add a
  jr c, .is_2_chr_trns
    ; Only one CHR_TRN
    add 2
    ld b, a
    call pb16_unpack_to_CHRRAM0
    call sgb_scramble_chr
    ;ld b, 0  ; B=0: load first half
    jr .do_final_CHR_TRN
  .is_2_chr_trns:
    ; First half is 4K
    push af
    ld b, low(128 * 32 / 16)
    call pb16_unpack_to_CHRRAM0
    call sgb_scramble_chr
    ld a, $13<<3|1
    push de
    call sgb_send_trn_ab
    call sgb_load_trn_tilemap
    pop de
    pop af

    ; Second half is the remaining bytes
    add 2
    ld b, a
    call pb16_unpack_to_CHRRAM0
    call sgb_scramble_chr
    inc b  ; B=1: load second half
  .do_final_CHR_TRN:
  ld a, $13<<3|1
  push de
  call sgb_send_trn_ab
  call sgb_load_trn_tilemap
  pop de

  ; Unpack tilemap and copy palette
  ld b,SIZEOF_SGB_BORDER_TILEMAP/16
  call pb16_unpack_to_CHRRAM0

  ; In the SNESdev Discord server on March 23, 2023, user dalton
  ; pointed out that some Super Game Boy commands caused the bottom
  ; scanline of the border to flicker.  Pino investigated in Mesen.
  ;
  ; It turns out that 29 rows of the border tilemap sent through
  ; PCT_TRN are at least partly visible.  The SGB system software
  ; sets the border layer's vertical scroll position (BG1VOFS) to 0.
  ; Because the S-PPU normally displays lines BGxVOFS+1 through
  ; BGxVOFS+224 of each layer, this hides the first scanline of the
  ; top row of tiles and adds one scanline of the nominally invisible
  ; 29th row.  Most of the time, SGB hides this scanline with forced
  ; blanking (writing $80 to address $012100).  While SGB is busy
  ; doing some things, such as fading out the border's palette, it
  ; neglects to force blanking, making the scanline visible at least
  ; some of the time.
  ; 
  ; To eliminate flicker, write a row of all-black tilemap entries
  ; after the bottom row of the border ($8700-$873F in VRAM in a
  ; PCT_TRN), or at least a row of tiles whose top row is blank.
  ; If that is not convenient, such as if a border data format
  ; doesn't guarantee a particular index for a black tile, make
  ; the flicker less objectionable by repeating the last scanline.
  ; Take the bottommost row (at $86C0-$86FF in VRAM) and copy it to
  ; the extra row, flipped vertically (XOR with $8000).
  ;
  ; Border Crossing currently uses the latter approach.
  push de  ; Stack: data stream (points at palette)
  ld de, $8000 + SIZEOF_SGB_BORDER_TILEMAP - 64
  ld c, SGB_BORDER_COLS
  .below_bottom_loop:
    ld a, [de]
    ld [hl+], a
    inc e
    ld a, [de]
    xor %10000000  ; vertically flip repeated row
    ld [hl+], a
    inc e
    dec c
    jr nz, .below_bottom_loop

  ; Copy palette and that's all
  pop hl
  ld de, SGB_BORDER_PALETTE_ADDR
  ld c, SIZEOF_SGB_BORDER_PALETTE
  call memcpy
  call sgb_scramble_pct
  ;ld b, 0
  ld a, $14<<3|1  ; PCT_TRN
  call sgb_send_trn_ab
  xor a
  ldh [hRasterToUse], a
  ret

;;
; Turns on rendering, sends a *_TRN packet with first two bytes
; A and B, and turns rendering back off.
sgb_send_trn_ab::
  ld l, a
  ldh a, [rLCDC]
  or LCDCF_ON
  ldh [rLCDC], a
  ld a, l
  call sgb_send_ab
  jp lcd_off
