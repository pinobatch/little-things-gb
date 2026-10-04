.include "snes.inc"

SOURCE_BUFFER  = $600               ; Base address for where the SGB firmware stores the last received index 0 SGB packet.

SGB_RMS        = $6003              ; Reset/multiplayer/speed. (Is there an official name for this register?)
SGB_CONTROLLER = $6004              ; Controller data.
SGB_ICD2REV    = $600F              ; ICD2 chip revision.


.smart +
.segment "code"
.proc irq_handler
zero:
        php

        SetM8

        lda #%00000001          ; Hold the GB CPU in reset.
        sta SGB_RMS

wait_for_y_sel:
        jsr wait_frame

        lda #%01000000          ; Button mask for sel+Y
        bit JOY1H
        beq wait_for_y_sel


        lda #%10000001          ; Run, one controller, 4 MHz
        sta SGB_RMS

        lda TIMEUP              ; Acknowledge the IRQ that's inevitably pending. (Not mandatory but prevents an ugly 1 frame glitch.)

        plp                     ; Restore XY and A mode to whatever it was before.

        cli                     ; Enable interrupts.
        rts

wait_frame:
        lda #1                  ; Auto read busy flag.

        ; Wait until the next time autoread is finished. (Which indirectly waits for the next frame.)
wait_autoread_start:
        bit HVBJOY
        beq wait_autoread_start
        ; Autoread has started. (Implies VBlank.)

wait_autoread_end:
        bit HVBJOY
        bne wait_autoread_end
        ; Autoread has ended. (Still in VBlank. Joypad can now safely be polled.)

        rts

.endproc
