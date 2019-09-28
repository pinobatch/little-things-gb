Telling LYs?
============

This program tests a Game Boy emulator's input entropy.

The Game Boy has an interrupt that can fire when a button changes
from not pressed to pressed.  This interrupt can fire at any time in
the frame: top, middle, bottom, or in the vertical blanking between
frames.  A program can see exactly when the interrupt fired by
inspecting a hardware register called `LY`, which presumably stands
for LCD Y Position.  For instance, it could wait for a press at the
title screen and then seed a random number generator from `LY`.

But simple emulators always fire the joypad interrupt at the same
time each frame, such as the start or end of vertical blanking.
The lack of variance in `LY` is telling about whether an emulator
was used; hence the name.

How to use
----------
Starting at the title screen, press all four directions on the
Control Pad and all four buttons (A, B, Select, and Start), one
after another in any order.  The arrow at the right side tells
exactly when, relative to the LCD frame, your button changed from
not pressed to pressed.  Once you have pressed all eight keys,
a screen for passing or failing appears.

Test results
------------
These pass with an essentially random arrow position, good for
four or more bits of entropy.

- Game Boy (DMG), Game Boy pocket (MGB), Game Boy Color (CGB)
- Game Boy Player (DOL-017)
- BGB 1.5.7

These pass but are poor entropy sources because the arrow slowly
creeps up or down the screen, indicating that polling occurs on
S-PPU vblank.  However, these can be detected in other ways.

- Super Game Boy (SNS-027)
- Super Game Boy 2

These fail, indicating that polling occurs on GB vblank:

- mGBA 0.8-5388-f92059be (Qt)

Legal
-----
Copyright 2018 Damian Yerrick

Permission is granted to use this program under the terms of the
zlib License.
