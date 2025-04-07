;
; Sound effects driver for GB
;
; Copyright 2018, 2025 Damian Yerrick
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

; Changes:
; 2025-03-03: DY replaced with gb
; 2022-01-14: DY added driver notes on suggestion from tbsp
; <https://github.com/tbsp/shock-lobster/blob/28e7fb19c671b9086c07eabfb96dff4945e5ceac/src/misc/audio.asm>

include "src/hardware.inc"

def LOG_SIZEOF_CHANNEL equ 3
def LOG_SIZEOF_SFX equ 2
def NUM_CHANNELS equ 4

def ENVB_DPAR equ 5
def ENVB_PITCH equ 4
def ENVF_QPAR equ $C0
def ENVF_DPAR equ $20
def ENVF_PITCH equ $10
def ENVF_DURATION equ $0F

section "audio_wram", WRAM0, ALIGN[LOG_SIZEOF_CHANNEL]
audio_channels: ds NUM_CHANNELS << LOG_SIZEOF_CHANNEL
def Channel_envseg_cd equ 0
def Channel_envptr equ 1
def Channel_envpitch equ 3

section "wavebank", ROM0, ALIGN[4]
wavebank:
;  db $FF,$EE,$DD,$CC,$BB,$AA,$99,$88,$77,$66,$55,$44,$33,$22,$11,$00
.ping:
  db $00,$14,$8c,$ff,$fd,$96,$43,$35,$78,$99,$87,$78,$9b,$dd,$da,$73

; Each entry in sfx_table is 4 bytes
; - First byte is the channel to use for the effect
;   0: pulse 1; 1: pulse 2; 2: wave; 3: noise
;   Use pulse 2 sparingly, as it's more likely to interrupt music
;   if you have a music player hooked up.
; - Second byte is unused (padding the entry to a power of 2 bytes)
; - Final word is the address of the effect segments

sfx_table:
  db 0, 0
  dw fx_tomlo
  db 0, 0
  dw fx_tomhi
  db 0, 0
  dw fx_closedhat
  db 0, 0
  dw fx_closedhat
  db 3, 0
  dw fx_snare
  db 3, 0
  dw fx_closedhat
  db 3, 0
  dw fx_openhat
  db 3, 0
  dw fx_kick

sgb_sfx_table:
  ; To be filled in later

; Format of a sound effect
; - Each sound effect is a sequence of segments.
; - Each segment is 1 to 3 bytes:
;   - The first byte is a bitfield.  Bits 7-6 (mask $C0) are a 2-bit
;     "quick parameter" whose interpretation varies per channel type.
;     Bit 5 (ENVF_DPAR = $20) is true if a deep parameter follows.
;     Bit 4 (ENVF_PITCH = $10) is true if a pitch change follows.
;     Bits 3-0 (mask $0F) are the length in frames of the segment
;     minus 1.  Values 0-F produce length 1-16.  For longer
;     durations, add another segment.
;   - The second and third bytes are the deep parameter and pitch,
;     in that order, if their flags are set.
; - Quick parameter $00, $40, $80, or $C0 controls pulse duty or
;   wave volume.
;   - On pulse, $00 means 1/8 duty, $40 means 1/4, and $80 means 1/2.
;     ($C0 is 3/4, which sounds the same as 1/4.)
;   - On wave, $00 means full volume, $40 means 1/2, $80 means 1/4,
;     and $C0 means mute.
;   - On noise, quick parameter does nothing.
;   Because value $C0 with a deep parameter or pitch isn't very
;   useful, a first byte in $F0-$FF is reserved for special purposes,
;   of which $FF is defined as end of the effect.
; - Deep parameter changes a value and retriggers the note.
;   - On wave, the value is an index into wavebank in 16-byte units.
;   - On pulse or noise, the value is a volume envelope (NRx2).
; - Pitch is an NR43 value on noise or a semitone number elsewhere.
; - The driver does not expose hardware sweep or length counter.

fx_tomlo:
  db ENVF_DPAR|ENVF_PITCH|$80, $81, 17
  db ENVF_PITCH|$80, 15
  db ENVF_PITCH|$80, 13
  db ENVF_DPAR|ENVF_PITCH|$87, $42, 12
  db $FF

fx_tomhi:
  db ENVF_DPAR|ENVF_PITCH|$80, $81, 22
  db ENVF_PITCH|$80, 20
  db ENVF_PITCH|$80, 18
  db ENVF_DPAR|ENVF_PITCH|$87, $42, 17
  db $FF

fx_closedhat:
  db ENVF_DPAR|ENVF_PITCH|4, $41, $05
  db $FF

fx_openhat:
  db ENVF_DPAR|ENVF_PITCH|7, $44, $05
  db ENVF_DPAR|14, $27
  db $FF

fx_kick:
  db ENVF_DPAR|ENVF_PITCH|0, $81, $25
  db ENVF_PITCH|4, $7D
  db $FF

fx_snare:
  db ENVF_DPAR|ENVF_PITCH|0, $81, $45
  db ENVF_PITCH, $25
  db ENVF_DPAR|10, $52
  db $FF

section "audioengine", ROM0

; Starting sequences ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

audio_init::
  ; Init PSG
  ld a,$80
  ldh [rNR52],a  ; bring audio out of reset
  ld a,$FF
  ldh [rNR51],a  ; set panning
  ld a,$77
  ldh [rNR50],a
  ld a,$08
  ldh [rNR10],a  ; disable sweep

  ; Silence all channels
  xor a
  ldh [rNR12],a
  ldh [rNR22],a
  ldh [rNR32],a
  ldh [rNR42],a
  ld a,$80
  ldh [rNR14],a
  ldh [rNR24],a
  ldh [rNR34],a
  ldh [rNR44],a

  ; Clear sound effect state
  xor a
  ld hl,audio_channels
  ld c,NUM_CHANNELS << LOG_SIZEOF_CHANNEL
  ; fallthrough memset_tiny
memset_tiny::
  ld [hl+], a
  dec c
  jr nz, memset_tiny
  ret

;;
; Plays sound effect A.
; Trashes ABCHL
audio_play_fx::
  ld h,high(sfx_table >> 2)
  add low(sfx_table >> 2)
  jr nc,.nohlwrap
    inc h
  .nohlwrap:
  ld l,a
  add hl,hl
  add hl,hl
  ld a,[hl+]  ; channel ID
  inc l
  ld c,[hl]   ; ptr lo
  inc l
  ld b,[hl]   ; ptr hi

  ; Get pointer to channel
  rept LOG_SIZEOF_CHANNEL
    add a
  endr
  add low(audio_channels+Channel_envseg_cd)
  ld l,a
  ld a,0
  adc high(audio_channels)
  ld h,a

  xor a  ; begin effect immediately
  ld [hl+],a
  ld a,c
  ld [hl+],a
  ld [hl],b
  ret

; Sequence reading ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

audio_update::
  ld hl, audio_channels+(0 << LOG_SIZEOF_CHANNEL)+Channel_envseg_cd
  call audio_update_ch_hl
  ld hl, audio_channels+(1 << LOG_SIZEOF_CHANNEL)+Channel_envseg_cd
  call audio_update_ch_hl
  ld hl, audio_channels+(2 << LOG_SIZEOF_CHANNEL)+Channel_envseg_cd
  call audio_update_ch_hl
  ld hl, audio_channels+(3 << LOG_SIZEOF_CHANNEL)+Channel_envseg_cd
;  fallthrough audio_update_ch_hl

audio_update_ch_hl:
  ; Each segment has a duration in frames.  If this segment's
  ; duration has not expired, do nothing.
  ld a,[hl+]
  or a
  jr z,.read_next_segment
    dec l
    dec [hl]
    ret
  .read_next_segment:

  ; Is an effect even playing on this channel?
  ld e,[hl]
  inc l
  ld a,[hl-]
  ld d,a
  or e
  ret z  ; address $0000: no playback

  ; HL points at low byte of effect position
  ; DE = effect pointer
  ld a,[de]
  cp $F0
  jr c,.not_special
    ; Currently all specials mean stop playback
    xor a
    ld [hl+],a
    ld [hl+],a  ; Clear pointer to sound sequence
    ld d,a
    ld bc,($C0 | ENVF_DPAR) << 8
    jr .call_updater
  .not_special:
  inc de

  ; Save this envelope segment's duration
  ld b,a
  and ENVF_DURATION
  dec l
  ld [hl+],a

  bit ENVB_DPAR,b  ; Is there a deep parameter?
  jr z,.nodeep
    ld a,[de]
    inc de
    ld c,a
  .nodeep:

  bit ENVB_PITCH,b  ; Is the pitch changing?
  jr z,.nopitch
    ld a,[de]
    inc de
    inc l
    inc l
    ld [hl-],a
    dec l
  .nopitch:

  ; Write back envelope position
  ld [hl],e
  inc l
  ld [hl],d
  inc l
  ld d,[hl]
  ; Regmap:
  ; B: quick parameter and flags
  ; C: deep parameter valid if BIT 5, B
  ; D: pitch, which changed if BIT 4, B

.call_updater:
  ; Seek to the appropriate audio channel's updater
  ld a,l
  sub low(audio_channels)
  rept LOG_SIZEOF_CHANNEL + (-1)
    rra
  endr
  and %00000110

;  tailcalls channel_writing_jumptable
  add low(channel_writing_jumptable)
  ld l, a
  adc high(channel_writing_jumptable)
  sub l
  ld h, a
  jp hl

; Channel hardware updaters ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

update_noise:
  ; Noise has no quick parameter.  Change pitch and timbre first
  ld a,d
  ldh [rNR43],a
  ; If no deep parameter, return quickly
  bit ENVB_DPAR,b
  ret z

  ; New deep parameter
  ld a,c
  ldh [rNR42],a
  ; See note below about turning off the DAC
  ld a,8
  cp c
  jr c,.no_vol8fix
    ldh [rNR42],a
  .no_vol8fix:
  ld a,$80
  ldh [rNR44],a
  ret

update_pulse1:
  ld hl,rNR11
  jr update_pulse_hl
update_pulse2:
  ld hl,rNR21
;  fallthrough update_pulse_hl
update_pulse_hl:
  ld [hl],b  ; Quick parameter is duty
  inc l
  bit ENVB_DPAR,b
  jr z,.no_new_volume
    ; Deep parameter is volume envelope
    ; APU turns off the DAC if the starting volume (bit 7-4) is 0
    ; and increase mode (bit 3) is off, which corresponds to NRx2
    ; values $00-$07.  Turning off the DAC makes a clicking sound as
    ; the level gradually returns to 7.5 as the current leaks out.
    ; But LIJI32 in gbdev Discord pointed out that if the DAC is off
    ; for only a few microseconds, it doesn't have time to leak out
    ; appreciably.
    ld a,8
    cp c
    ld [hl],c
    jr c,.no_vol8fix
      ld [hl],a
    .no_vol8fix:
  .no_new_volume:
  inc l
;  fallthrough set_pitch_hl_to_d
set_pitch_hl_to_d:
  ; Write pitch
  ld a,d
  add a
  ld de,pitch_table
  add e
  ld e,a
  jr nc,.nodewrap
    inc d
  .nodewrap:
  ld a,[de]
  inc de
  ld [hl+],a
  ld a,[de]
  bit ENVB_DPAR,b
  jr z,.no_restart_note
    set 7,a
  .no_restart_note:
  ld [hl+],a
  ret

;;
; @param B quick parameter and flags
; @param C deep parameter if valid
; @param D current pitch
channel_writing_jumptable:
  jr update_pulse1
  jr update_pulse2
  jr update_wave
  jr update_noise

update_wave:
  ; First update volume (quick parameter)
  ld a,b
  add $40
  rra
  ldh [rNR32],a

  ; Update wave 9
  bit ENVB_DPAR,b
  jr z,.no_new_wave

  ; Get address of wave C
  ld h,high(wavebank >> 4)
  ld a,low(wavebank >> 4)
  add c
  ld l,a
  add hl,hl
  add hl,hl
  add hl,hl
  add hl,hl

  ; Copy wave
  xor a
  ldh [rNR30],a  ; give CPU access to waveram
  def I = 0
  rept 16
    ld a,[hl+]
    ldh [_AUD3WAVERAM + I],a
    def I = I + 1
  endr
  ld a,$80
  ldh [rNR30],a  ; give APU access to waveram

.no_new_wave:
  ld hl,rNR33
  jr set_pitch_hl_to_d
