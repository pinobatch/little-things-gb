; Definition file stolen from Furrykef's Snesify project.
; https://github.com/furrykef/snesify
.p816
.smart
.macpack generic
.feature force_range

FLAG_XY8 = $10
FLAG_M8 = $20

; I've edited these to use literal values instead of the defs.
; ca65 warned "Warning: Cannot track processor status byte" otherwise.
; (Which is weird. Shouldn't the defs be as constant as the literals?)
.macro SetM8
    sep #$20 ;FLAG_M8
.endmacro

.macro SetM16
    rep #$20 ;FLAG_M8
.endmacro

.macro SetXY8
    sep #$10 ;FLAG_XY8
.endmacro

.macro SetXY16
    rep #$10 ;FLAG_XY8
.endmacro

.macro SetMXY8
    sep #$30 ;FLAG_M8 | FLAG_XY8
.endmacro

.macro SetMXY16
    rep #$30 ;FLAG_M8 | FLAG_XY8
.endmacro

.macro ClearB
    xba
    lda     #0
    xba
.endmacro


; Joypad bit numbers
JOY_R           = 1 << 4
JOY_L           = 1 << 5
JOY_X           = 1 << 6
JOY_A           = 1 << 7
JOY_RIGHT       = 1 << 8
JOY_LEFT        = 1 << 9
JOY_DOWN        = 1 << 10
JOY_UP          = 1 << 11
JOY_START       = 1 << 12
JOY_SELECT      = 1 << 13
JOY_Y           = 1 << 14
JOY_B           = 1 << 15


; RGB colors
.define COLOR(r, g, b)  (b << 10 | g << 5 | r)


; Taken from MAME's snes.h and ASM-ified

; Definitions for PPU Memory-Mapped registers
INIDISP       = $2100
OBSEL         = $2101
OAMADDL       = $2102
OAMADDH       = $2103
OAMDATA       = $2104
BGMODE        = $2105  ; abcdefff = abcd: bg4-1 tile size | e: BG3 high priority | f: mode 
MOSAIC        = $2106  ; xxxxabcd = x: pixel size | abcd: affects bg 1-4 
BG1SC         = $2107
BG2SC         = $2108
BG3SC         = $2109
BG4SC         = $210A
BG12NBA       = $210B
BG34NBA       = $210C
BG1HOFS       = $210D
BG1VOFS       = $210E
BG2HOFS       = $210F
BG2VOFS       = $2110
BG3HOFS       = $2111
BG3VOFS       = $2112
BG4HOFS       = $2113
BG4VOFS       = $2114
VMAIN         = $2115  ; i---ffrr = i: Increment timing | f: Full graphic | r: increment rate 
VMADDL        = $2116  ; aaaaaaaa = a: LSB of vram address 
VMADDH        = $2117  ; aaaaaaaa = a: MSB of vram address 
VMDATAL       = $2118  ; dddddddd = d: data to be written 
VMDATAH       = $2119  ; dddddddd = d: data to be written 
M7SEL         = $211A  ; ab----yx = a: screen over | y: vertical flip | x: horizontal flip 
M7A           = $211B  ; aaaaaaaa = a: COSINE rotate angle / X expansion 
M7B           = $211C  ; aaaaaaaa = a: SINE rotate angle / X expansion 
M7C           = $211D  ; aaaaaaaa = a: SINE rotate angle / Y expansion 
M7D           = $211E  ; aaaaaaaa = a: COSINE rotate angle / Y expansion 
M7X           = $211F
M7Y           = $2120
CGADD         = $2121
CGDATA        = $2122
W12SEL        = $2123
W34SEL        = $2124
WOBJSEL       = $2125
WH0           = $2126  ; pppppppp = p: Left position of window 1 
WH1           = $2127  ; pppppppp = p: Right position of window 1 
WH2           = $2128  ; pppppppp = p: Left position of window 2 
WH3           = $2129  ; pppppppp = p: Right position of window 2 
WBGLOG        = $212A  ; aabbccdd = a: BG4 params | b: BG3 params | c: BG2 params | d: BG1 params 
WOBJLOG       = $212B  ; ----ccoo = c: Colour window params | o: Object window params 
TM            = $212C
TS            = $212D
TMW           = $212E
TSW           = $212F
CGWSEL        = $2130
CGADSUB       = $2131
COLDATA       = $2132
SETINI        = $2133
MPYL          = $2134
MPYM          = $2135
MPYH          = $2136
SLHV          = $2137
ROAMDATA      = $2138
RVMDATAL      = $2139
RVMDATAH      = $213A
RCGDATA       = $213B
OPHCT         = $213C
OPVCT         = $213D
STAT77        = $213E
STAT78        = $213F
APU00         = $2140
APU01         = $2141
APU02         = $2142
APU03         = $2143
WMDATA        = $2180
WMADDL        = $2181
WMADDM        = $2182
WMADDH        = $2183

; Definitions for CPU Memory-Mapped registers
OLDJOY1       = $4016
OLDJOY2       = $4017
NMITIMEN      = $4200
WRIO          = $4201
WRMPYA        = $4202
WRMPYB        = $4203
WRDIVL        = $4204
WRDIVH        = $4205
WRDVDD        = $4206
HTIMEL        = $4207
HTIMEH        = $4208
VTIMEL        = $4209
VTIMEH        = $420A
MDMAEN        = $420B
HDMAEN        = $420C
MEMSEL        = $420D
RDNMI         = $4210
TIMEUP        = $4211
HVBJOY        = $4212
RDIO          = $4213
RDDIVL        = $4214
RDDIVH        = $4215
RDMPYL        = $4216
RDMPYH        = $4217
JOY1L         = $4218
JOY1H         = $4219
JOY2L         = $421A
JOY2H         = $421B
JOY3L         = $421C
JOY3H         = $421D
JOY4L         = $421E
JOY4H         = $421F

; DMA
DMAP0         = $4300
BBAD0         = $4301
A1T0L         = $4302
A1T0H         = $4303
A1B0          = $4304
DAS0L         = $4305
DAS0H         = $4306
DSAB0         = $4307
A2A0L         = $4308
A2A0H         = $4309
NTRL0         = $430A
DMAP1         = $4310
BBAD1         = $4311
A1T1L         = $4312
A1T1H         = $4313
A1B1          = $4314
DAS1L         = $4315
DAS1H         = $4316
DSAB1         = $4317
A2A1L         = $4318
A2A1H         = $4319
NTRL1         = $431A
DMAP2         = $4320
BBAD2         = $4321
A1T2L         = $4322
A1T2H         = $4323
A1B2          = $4324
DAS2L         = $4325
DAS2H         = $4326
DSAB2         = $4327
A2A2L         = $4328
A2A2H         = $4329
NTRL2         = $432A
DMAP3         = $4330
BBAD3         = $4331
A1T3L         = $4332
A1T3H         = $4333
A1B3          = $4334
DAS3L         = $4335
DAS3H         = $4336
DSAB3         = $4337
A2A3L         = $4338
A2A3H         = $4339
NTRL3         = $433A
DMAP4         = $4340
BBAD4         = $4341
A1T4L         = $4342
A1T4H         = $4343
A1B4          = $4344
DAS4L         = $4345
DAS4H         = $4346
DSAB4         = $4347
A2A4L         = $4348
A2A4H         = $4349
NTRL4         = $434A
DMAP5         = $4350
BBAD5         = $4351
A1T5L         = $4352
A1T5H         = $4353
A1B5          = $4354
DAS5L         = $4355
DAS5H         = $4356
DSAB5         = $4357
A2A5L         = $4358
A2A5H         = $4359
NTRL5         = $435A
DMAP6         = $4360
BBAD6         = $4361
A1T6L         = $4362
A1T6H         = $4363
A1B6          = $4364
DAS6L         = $4365
DAS6H         = $4366
DSAB6         = $4367
A2A6L         = $4368
A2A6H         = $4369
NTRL6         = $436A
DMAP7         = $4370
BBAD7         = $4371
A1T7L         = $4372
A1T7H         = $4373
A1B7          = $4374
DAS7L         = $4375
DAS7H         = $4376
DSAB7         = $4377
A2A7L         = $4378
A2A7H         = $4379
NTRL7         = $437A

