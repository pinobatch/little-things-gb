bdos subset
===========

by Damian Yerrick

The file bdos.z80 implements a subset of the BDOS (`call 5`) API,
used by CP/M programs to output text, on the Game Boy.  I intend this
terminal library to help with testing math routines and the like.

So far, these call numbers are supported:

- `c = 0`: End program (also `rst $00`)
- `c = 2`: Write ASCII character in E to the terminal.  The terminal
  is a 20 by 18 character tty supporting backspace ($08), return
  ($0D), newline ($0A), and form feed ($0C).
- `c = 9`: Write characters starting at DE to the terminal,
  stopping at the end of string byte.
- `c = 110`: Set end of string byte to E, or if DE is $FFFF,
  retrieve the old end of string byte in A.
- `c = 111`: DE points to a 2-word struct containing a start address
  of a block of memory and length in bytes.  Write all bytes to the
  screen.
- `c = 141`: Wait for DE frames

Intentional departures from CP/M:

- Newline causes a carriage return, as in UNIX.
- The end of string byte defaults to $00, as in C, not $24.

