include "src/hardware.inc"
include "src/global.inc"

def TROUBLESHOOT_GOOMBA equ 0

section "stat_wram", WRAM0
wStatValuesPtr: ds 2

section "stat_hram_src", ROM0[$48]
stat_handler:   ;  5
  push af       ;  9
  jr hStatSMC   ; 12

stat_tail:
  ; Schedule next interrupt
  ldh a, [rLYC]
  add 8
  ldh [rLYC], a
  cp 104
  jr c, .not_complete
    ld a, $FF
    ldh [rLYC], a    ; Cancel STAT IRQ for remainder of frame
  .not_complete:

  push hl
  ; Read next value from stat table
  ld hl, wStatValuesPtr
  ld a, [hl+]
  ld h, [hl]
  ld l, a
  ld a, [hl+]
  ldh [hStatSMC+1], a
  ; Update hint table pointer
  ld a, l
  ld [wStatValuesPtr+0], a
  ld a, h
  ld [wStatValuesPtr+1], a
  pop hl
  pop af
  reti

; These routines get copied to the end of high RAM, preferably
; within JR range of RSTs and IRQs.

section "hramcode_src", ROM0
hramcode_src::
  dw hramcode_dst
  dw hramcode_src_end-hramcode_src-4
load "stat_hram", HRAM[$FFF4]
hramcode_dst:

;;
; Start OAM DMA and wait for it to finish.
;
; While OAM DMA is running, both ROM and WRAM are inaccessible; only
; HRAM is readable.  Yet the CPU continues to run for 161 cycles:
; one warm-up and one for each byte.
; @param A high byte of OAM DMA source address
; @param B 40
; @param C low(rDMA)
; @return B=0
run_dma_tail::
  ldh [c], a
.loop:
  dec b
  jr nz, .loop
  ; It's been 159 cycles after the write.  We need 2 more before
  ; we can read the stack again.
  if TROUBLESHOOT_GOOMBA
    ret
  else
    ret z  ; And the conditional return provides the extra 2.
  endc

;;
; Load a value and write it to an address, and then finish the
; STAT interrupt.  This is the self-modifying portion. 
hStatSMC:
  ld a, $30          ; 14
  ldh [rP1], a       ; 17
  jr stat_tail
endl
hramcode_src_end:

section "init_hram_src", ROM0
setup_raster_for_scramble::
  ldh a, [hRasterToUse]
  add a
  add a
  add a
  add 6
  add low(scrambles)
  ld l, a
  adc high(scrambles)
  sub l
  ld h, a  ; HL = &scrambles.procs[c]
  ld a, [hl+]
  ld h, [hl]
  ld l, a  ; HL = scrambles.procs[c]
  fallthrough setup_raster

;;
; Sets up STAT IRQ value table for the next frame.
; Precondition: in vblank, and stat_hram already copied to HRAM
; @param HL pointer to register address then 13 values, or 0
setup_raster::
  ld a, l
  or h
  jr nz, .not_null
    ; If there is no raster associated with this scramble,
    ; disable raster for this frame
    cpl
    ldh [rLYC], a
    ret
  .not_null:
  ld a, [hl+]
  ldh [hStatSMC+3], a  ; set address
  ld c, a
  ld a, [hl+]
  ldh [c], a           ; write first value
  ld a, [hl+]
  ldh [hStatSMC+1], a  ; set second value
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
