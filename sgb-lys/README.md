SGB Key IRQ Test
================

This is a planned sequel to Telling LYs, intended to more precisely
characterize timing behavior of the Super Game Boy (SGB) accessory's
controller input.

On Game Boy (DMG), Game Boy pocket (MGB), and Game Boy Color (GBC)
systems, the states of "keys" (buttons or Control Pad directions) can
change at any time.  The LCD Y position (LY) of each press is random
enough for a program to use to seed a pseudorandom number generator
(PRNG).  On SGB, by contrast, key states appear to change at the
same rate as Super NES frames, with a constant rate of drift between
Super NES and Game Boy frames so long as the LCD remains on.

1. [Done] Display register values at program start time
2. [Done] While holding the A Button, estimate P1 bit 0 rise time
   after deselecting the buttons half of the key matrix.
   This should be 0 on SGB and GBC and positive on DMG and MGB.
3. [To do] Log frame count and LY of presses of the A Button, and
   compare to estimated frame counts.
4. [Done] Slow motion feature: if the Start Button is pressed before
   the menu loads, display the frame count and LY of the first press
   to establish initial phase.  Check for this during a 1-second
   pause before sending `MLT_REQ` to detect SGB.

Estimates of each SGB variant's input period:

- NTSC SGB: 71473.2 T-states, down 2.74 lines per frame
- NTSC SGB2: 69790.1 T-states, up 0.95 lines per frame
- PAL SGB: 85113.6 T-states, down 32.65 lines per frame
