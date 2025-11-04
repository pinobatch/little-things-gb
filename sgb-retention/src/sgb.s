include "src/hardware.inc"

; Super Game Boy detection ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section "sgb_detection", ROM0

;;
; Sets hCapability to 1 if the player number is 2 or 4.
; rP1 must be $30 (key matrix deselected), such as after sgb_send
; or read_pad.  When this happens, SGB returns 4 - player number in
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
  ; fall through

;;
; Set the number of controllers to read to B + 1, where B is
; 0, 1, or 3 for 1, 2, or 4 (multitap only) players.
sgb_set_bplus1_players::
  ld a, ($11 << 3) + 1
  ; fall through

;;
; Send a 1-packet SGB command whose first two bytes are A and B
; and whose remainder is zero filled.
sgb_send_ab::
  ld c, 0
  ; fall through

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

DEF SIZEOF_SGB_PACKET EQU 16
DEF CHAR_BIT EQU 8

;;
; Clears the Super Game Boy attribute table to 0.
sgb_send_if_sgb::
  ldh a, [hCapability]
  rra
  ret nc

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
; Waits about 4 frames for Super Game Boy to have processed a command
; Ideally, 4 frames is 4*154 = 616 scanlines or 4*154*114 = 70224
; M-cycles.  But in fact, the guideline might be referring to
; NTSC Super NES frames, which are 262 scanlines of 68.2 M-cycles
; each.  Thus we can try waiting 4*262*68.2 = 71473.6 cycles.
; Each iteration of the inner loop takes 4+3/256 cycles.
; Thus we wait 71473 / 4 = 17868 iterations.
sgb_wait::
  ld de, 65536 - 17868
.loop:
  inc e
  jr nz, .loop
  inc d
  jr nz, .loop
  ret

