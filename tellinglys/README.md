Telling LYs?
============

Tests whether a Game Boy emulator produces realistic timing
for button presses.

The Game Boy has an interrupt that can fire when a button changes
from not pressed to pressed.  This interrupt can fire at any time in
the frame: top, middle, bottom, or in the vertical blanking between
frames.  A program can see exactly when the interrupt fired by
inspecting a hardware register called `LY`, which presumably stands
for LCD Y Position.  For instance, a game could wait for a press at
the title screen and then seed a random number generator from `LY`.

Simple emulators always fire the joypad interrupt at the same
time each frame, such as the start or end of vertical blanking.
In a sense, such emulators are "lying" to the game about when
the button is pressed.  The lack of variance in `LY` is telling
about whether an emulator was used; hence the name.

How to use
----------
Starting at the title screen, press all four directions on the
Control Pad and all four buttons (A, B, Select, and Start), one
after another in any order.  The arrow at the right side tells
exactly when, relative to the LCD frame, your button changed from
not pressed to pressed.  As you press buttons, the lyrics of
"[Johny, Johny]" appear on the screen.  Once you have pressed all
eight keys, a screen for passing or failing appears.

[Johny, Johny]: https://youtu.be/FLd_n4p-S2M

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
