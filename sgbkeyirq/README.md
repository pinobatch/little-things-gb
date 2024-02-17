SGB Key IRQ Timing
==================

This test, a sequel to Telling LYs, is intended to more precisely
characterize timing behavior of the Super Game Boy (SGB) accessory's
controller input.

Background
----------

Game Boy (DMG), Game Boy pocket (MGB), and Game Boy Color (GBC)
systems (collectively GB) contain a system on chip (SoC) comprising
an 8-bit central processing unit (CPU), timers, a picture processing
unit (PPU) that reads video memory and generates a picture signal,
and other components.  While the display is on, the PPU produces a
line every 456 cycles, and it sends 144 lines of picture followed by
10 lines of vertical blanking period ("vblank") for a total of 154
lines.  The frame period, or the time from the start of one vblank
to the start of the next, is thus 456 times 154 or 70224 dots.

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
- Times of button presses while waiting for the SGB to warm up,
  which reflect initial phase between S-PPU and GB vblanks

You can test the SGB's startup delay by holding or mashing the B or
Start Button or using a controller's "slow motion" feature before
the result screen appears.

### 2. Rise time

Press and release the A Button and then Down on the Control Pad
to measure and display the rise time, or the time for input to
settle after deselecting half of the key matrix.  For example,
"Down to btns" means that while you hold Down on the Control Pad,
the test will select the Control Pad, wait, select the buttons,
and time how long it takes for the Down bit to return to 1.

* A to dirs: Select buttons (P1=$10), wait,
  select Control Pad (P1=$20), measure
* A to none: Select buttons (P1=$10), wait,
  select nothing (P1=$30), measure
* Down to btns: Select Control Pad (P1=$20), wait,
  select buttons (P1=$10), measure
* Down to none: Select Control Pad (P1=$20), wait,
  select nothing (P1=$30), measure

Rise time is measured in units of 4 T-states (about 1 microsecond)
and differs between DMG and MGB.  The Control Pad had a longer
rise time than the buttons in units owned by the developer, and
there was no time difference between selecting the other half
and deselecting the entire matrix.

This measures time to respond to changes in the select bits,
not time when the player physically releases a key.

### 3. Frame period

Repeatedly press the A, B, or Start Button.  The program watches for
presses and displays the exact time of each of the last 7, in units
of 64 T-states (nominally 1/65536 second).  On handhelds, some
releases also count as presses because the buttons bounce for a few
microseconds when they make or break contact.  To clear the history,
wait 1 second before the next press.

Once you have at least 3 press times, press the Select Button to
calculate the SGB's frame period by looking for patterns in the
timing of the last few presses.  It uses an algorithm based on the
median of approximate greatest common divisors of differences
between press times.  It confirms the guess by displaying
press times divided by that period.

Caveats:

- Frame period estimation is more resistant to subharmonic errors
  with at least 5 presses within 1 second.
- The detection thresholds are set for SGB's roughly 60 Hz update
  rate, not the allegedly faster polling of the Game Boy Player
  accessory for Nintendo GameCube.  Nor will it give a meaningful
  result on a handheld; you can tell because the quartiles will be
  much farther apart.

Results
-------

Tested using GB-LIVE32, a USB EPROM emulator by Gekkio that does
not display a menu before starting the game.  Console is a 1/1/1
US Super NES.  Controller is asciiPad, chosen for its turbo and
slow motion features.

### Super Game Boy

NTSC Super Game Boy
```
SGB   1  AF 0100  SP FFFE
BC 0014  DE 0000  HL C060
LY    0  DIV  D8  NR52 F0
```

Early press times

* Hold A: 5329
* Hold B, Y, Select, or Start: 45575
* Slow motion: 47827, 54575, 58977, 64653, 70229, 74696, 80297

Measured rise time: all 0

Frame times should be close to 71473.2 / 64 = 1117 ticks.


Super Game Boy 2
```
SGB   1  AF FF00  SP FFFE
BC 0014  DE 0000  HL C060
LY    0  DIV  D8  NR52 F0
```

Early press times

* Hold A: 5522
* Hold B, Y, Select, or Start: 44818
* Slow motion: 49108, 53607, 60017, 64553, 69998, 75444, 80904

Measured rise time: all 0

Frame times should be close to 69790.1 / 64 = 1090 ticks.

### Handhelds

Game Boy
```
SGB   0  AF 01B0  SP FFFE
BC 0013  DE 00D8  HL 014D
LY    0  DIV  AB  NR52 F1
```

Measured rise time

* A to dirs: 1 us
* A to none: 1 us
* Down to btns: 3 us
* Down to none: 3 us

Game Boy pocket
```
SGB   0  AF FFB0  SP FFFE
BC 0013  DE 00D8  HL 014D
LY    0  DIV  AB  NR52 F1
```

Measured rise time

* A to dirs: 0 us
* A to none: 0 us
* Down to btns: 2 us
* Down to none: 2 us

Game Boy Color
```
SGB   0  AF 1180  SP FFFE
BC 0000  DE 0008  HL 007C
LY  148  DIV  26  NR52 F1
```

Measured rise time: all 0

Game Boy Advance results are the same as Game Boy Color, except that
BC is 0100.

Handhelds do not sample on vblank.  If they did, as some emulators
do, the frame times would be close to 70224 / 64 = 1097 ticks.
