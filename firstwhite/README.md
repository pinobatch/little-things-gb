First Frame White
=================

This program should display a white screen.  In fact, on a monochrome
Game Boy, it should display the same whiter-than-white shade that it
displays when the power is off. If you get text, your emulator needs
to be fixed and probably shows 1-frame glitches in _Pokémon Pinball_.

Test results
------------
These pass by displaying nothing:
- Game Boy, Game Boy pocket: Screen is whiter than white
- Game Boy Color, Game Boy Advance, Game Boy Player: White screen
- BGB 1.5.7: White screen

These fail by displaying something:
- mGBA 0.8-5388-f92059be (Qt): Error message
- Super Game Boy, Super Game Boy 2: Error message on rolling screen,
  as if on a TV with poor vertical hold

Legal
-----
Copyright 2018 Damian Yerrick

Permission is granted to use this program under the terms of the
zlib License (see file LICENSE).
