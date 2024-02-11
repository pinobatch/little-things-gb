SGB Key IRQ Test
================

This test, a sequel to Telling LYs, is intended to more precisely
characterize timing behavior of the Super Game Boy (SGB) accessory's
controller input.

Background
----------

Game Boy (DMG), Game Boy pocket (MGB), and Game Boy Color (GBC)
systems (collectively GB) contain a system on chip (SoC) comprising
an 8-bit central processing unit (CPU), a programmable sound
generator (PSG), timers, and a picture processing unit (PPU)
that reads video memory and generates a picture signal.  While the
display is on, the PPU sends a line every 456 cycles, and it sends
144 lines of picture followed by 10 lines of vertical blanking period
("vblank") for a total of 154 lines.  The frame period, or the time
from the start of one vblank to the start of the next, is thus
456 times 154 or 70224 dots.

GB has eight keys: four buttons and four Control Pad directions.
The player can press or release these at any time, and the running
program can read the PPU's vertical position (LY) or timer state
at the time of the press.  LY on a handheld is random enough for
a program to use to seed a pseudorandom number generator (PRNG).

DMG and MGB organize the keys as a 2 by 4 bit matrix.  The system on
chip has two output lines and four open-drain input lines normally
pulled high (5 volts) through resistors.  Contacts on the PCB pull
them to ground through a diode when selected by one of the outputs.
A program reads the controller by setting the outputs to poll one
half of the matrix (buttons or the Control Pad), both, or neither.
When deselecting one half, it takes a few microseconds for the lines
to return high.  This is called "rise time" and is probably caused
by capacitance between traces on the circuit board.

SGB is an accessory to play GB software on a Super NES.  Its system
software reads the controller once per vblank of the Super NES
Picture Processing Unit (S-PPU) and forwards updated key states
to the SGB's GB SoC.  A program on the GB can measure key state
changes to infer when S-PPU vblank occurs.  The two PPUs are not
synchronized; over the course of several presses, LY steadily drifts
up or down at a rate that depends on the SGB model:

- Handheld GB: 70224 T-states, 456 per line by 154 lines
- NTSC SGB: 71473.2 T-states, down 2.74 lines per frame
- PAL SGB: 85113.6 T-states, down 32.65 lines per frame
- NTSC SGB2: 69790.1 T-states, up 0.95 lines per frame

SGB also appears to start the GB program a fraction of a second
before it starts forwarding input.  If the player holds a button
at power-up on an NTSC SGB, the program sees it being pressed
about 40 frames after power-up.

GBC has eight input lines, as does the bridge chip between the GB and
Super NES sides in the SGB.  This means they have zero rise time.
They still present keys to the program as a matrix for compatibility.

The test
--------

### 1. Initial conditions

When the program starts, it reads the state of several processor and
input/output (I/O) registers.  After waiting for a second for the SGB
to finish its startup process, it displays the initial conditions.

- All CPU registers (AF, BC, DE, HL, SP)
- The DIV register associated with the timer
- The LY register associated with the PPU
- The NR52 register associated with the PSG, which indicates
  whether or not the boot ROM played a ding
- Whether the SGB system software responded to a packet to
  enable and disable controller 2
- Times of button presses while waiting for the SGB to warm up

You can test the SGB's startup delay by holding or mashing the B or
Start Button or using a controller's "slow motion" feature before
the result screen appears.

### 2. Rise time

Press and release the A Button and then Down on the Control Pad
to measure and display the rise time.  This differs between DMG and
MGB, and the Control Pad can have more rise time than the buttons.

### 3. Frame period

Repeatedly press the A, B, or Start Button.  The program watches for
and displays the exact time of each press, in units of 64 T-states
(nominally 1/65536 second).  On handhelds, some releases also count
as presses because the buttons bounce for a few microseconds when
they make or break contact.

Press the Select Button to calculate the SGB's frame period by
looking for patterns in the timing of the last few presses.
It uses an algorithm based on the median of approximate greatest
common divisors.  This won't give a meaningful result on a handheld.

Status
------

Everything through "rise time" is in the ROM.  The AGCD algorithm has
been prototyped in Python.  These remain to be built in the ROM:

1. Draw the presses to the screen
2. Calculate times between successive presses and pairwise AGCDs
   between those times
3. Display the AGCD and the predicted timestamp for each frame
