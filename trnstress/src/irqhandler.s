include "src/hardware.inc"

section "stat_hram_src", ROM0[$40]
stat_handler:        ;  5
  push af            ;  9
  jr lyc_stat_hram   ; 12

stat_tail:
  ; Schedule next interrupt
  ldh a, [rLYC]
  add 8
  ldh [rLYC], a
  cp 104
  jr c, .not_complete
    cpl
    ldh [rLYC], a    ; Cancel STAT IRQ for remainder of frame
  .not_complete:

  push hl
  ; Read next value from stat table
  ld hl, wStatValuesPtr
  ld a, [hl+]
  ld h, [hl]
  ld l, a
  ld a, [hl+]
  ldh [hStatSMC+3], a
  ; Update hint table pointer
  ld a, l
  ld [wStatValuesPtr+0], a
  ld a, h
  ld [wStatValuesPtr+1], a
  pop hl
  pop af
  reti

section "stat_hram_src", ROM0
stat_hram_src:
  dw stat_hram
  dw stat_hram.end-stat_hram
load "stat_hram", HRAM[$FFF9]
hStatSMC:
  ld a, $30          ; 14
  ldh [rP1], a       ; 17
  jr stat_tail
.end
endl

section "init_hram_src", ROM0
;;
; Sets up STAT IRQ value table for the next frame.
; Precondition: in vblank, and stat_hram already copied to HRAM
; @param HL pointer to register address then 12 values
setup_stat_handler:
  ld a, [hl+]
  ldh [hStatSMC+1], a  ; set address
  ld c, a
  ld a, [hl+]
  ldh [c], a           ; write first value
  ld a, [hl+]
  ldh [hStatSMC+3], a  ; set second value
  ld a, 8
  ldh [rLYC], a        ; set when to write second value
  ld a, l
  ld [wStatValuesPtr+0], a
  ld a, h
  ld [wStatValuesPtr+1], a

  ; On DMG/SGB, writing to STAT enables all four sources for one
  ; cycle.  Road Rash and Legend of Zerd require this and won't run
  ; on GBC.  Suppress this interrupt while setting it up.
  di
  ld a, STATF_LYC
  ldh [rSTAT], a
  xor a
  ldh [rIF], a  ; cancel pending interrupts
  reti
