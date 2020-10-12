ca83 syntax
===========
Sharp SM83 is an 8-bit microprocessor core sometimes called "GBZ80"
after its similarity to Intel 8080 and Zilog Z80 processors and its
use in the Game Boy compact video game system.  The syntax used by
the majority of assemblers targeting SM83 resembles Zilog's syntax
more than Intel's.

For consistency, ca83 recognizes `[hl]`, not `(hl)`.  Square
brackets `[]` always denote memory access, and parentheses `()`
always denote grouping of arithmetic expressions.

All `ld` instructions can be written as `mov`.  The `ld` instruction
is not automatically optimized to `ldh`, even if the argument is
statically above `$FF00`.  Indexed HRAM accesses can be written as
`ldh [c], a` or as `ld [$ff00+c], a`.

All ALU operations with A (`add`, `adc`, `sub`, `sbc`, `and`,
`xor`, `or`, and `cp`) can be written in a 1- or 2-argument form:
`add [hl]` and `add a, [hl]` mean the same, as do `xor $10` and
`xor a, $10`.  Likewise, `cpl` and `cpl a` both work.

A `jr` 1 byte backward executes the `$FF` value as `rst $38` if
taken.  Thus `rst $38` (and _only_ `rst $38`) can be written with
condition codes, such as `rst nz, $38`.  This can prove convenient
for assertions if you have a crash handler at `$0038`.

The argument to `rst` need not be a literal constant.  It can be any
symbol, such as a label, so long as the linker places the symbol
at `$00`, `$08`, ..., or `$38`.  For example, if `wait_vblank_irq`
ends up at `$0008`, `rst wait_vblank_irq` is valid.

For convenience, the Z80 `djnz` is emulated as `dec b` then `jr nz`.

Halt instructions
-----------------
The `halt` instruction stops the CPU until the next interrupt.
If the interrupt master enable (IME) is on, such as after `ei`,
it calls the interrupt handler and then resumes after the HALT.
Like `wai` of 65816 and unlike `halt` of Z80, `halt` of SM83 works
even if IME is off: it waits for an interrupt, skips the interrupt
handler, and executes the next instruction.  This makes it useful
for synchronizing to the start of horizontal blanking for VRAM
transfer routines.

But when the CPU executes `halt` while IME is off and an interrupt
is already pending (`(IE & IF) != 0`), the CPU skips incrementing PC
after reading the following instruction byte, causing the byte to be
executed twice.  In addition, if IME is off, the interrupts that
ended the `halt` remain pending. The standard workaround fills this
byte with a 1-byte instruction that takes 1 cycle and is idempotent
(that is, it has the same effect if run twice).  Many assemblers
targeting SM83, such as RGBASM, insert `nop` after every `halt`
by default.  Other choices follow:

    scf
    ld reg8, reg8
    sub a, a
    sbc a, a
    and a, reg8
    xor a, a
    or a, reg8
    cp a, reg8
    di
    ei

One-byte instructions that access memory, such as `ld b, [hl]` or
`ld [$ff00+c], a`, are not idempotent if they cause a memory-mapped
I/O with side effects.

Using `nop` or another idempotent instruction after `halt` rather
than relying on double execution makes your program easier to
understand and more compatible with emulators and clones that do not
implement this quirk.  The vast majority of games use `nop`, but a
very tight VRAM transfer may fit better into hblank by putting a
different idempotent instruction in that slot.

For this reason, ca83 provides both `halt` and `hlt`.  The shorter
mnemonic emits a shorter encoding without the following `nop` and
is safe if the next instruction is 1 byte and idempotent or if IME
is guaranteed to be on.  However, some debugging emulators are not
set up to recognize all such safe instructions; they will break
on double execution of any instruction other than `nop`.

The `stop` instruction is used to turn off most of the system and
wait for a keypress while using very little power.  Games never
used it because the mechanism was prone to butt dialing.  Instead,
it was repurposed in the Game Boy Color to change its CPU speed.
The CPU ignores the byte after `stop`.  By default, ca83 emits `$00`
there; override this by specifying an argument such as `stop $31`.
