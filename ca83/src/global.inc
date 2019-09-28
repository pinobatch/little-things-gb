.ifndef GLOBAL_INC
.define GLOBAL_INC 1

.global main

.global cur_keys, new_keys
.global SOAM, oam_used, vblank_lcdc_value

; RSTs
.globalzp memset_inc, memset_tiny, wait_vblank_irq

; Common routines
.global clear_scrn0_to_0, clear_scrn0_to_h, memset, memcpy
.global busy_wait_vblank, lcd_off, lcd_clear_oam

; unpb8.z80
.global pb8_unpack

.endif
