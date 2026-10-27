# How SPINE was found

## The dream

As a teenager, Melissa had an idea: copy the 48K ROM into RAM, run
BASIC from the copy, and so have BASIC be *hers*.

> it exactly feels like you're in regular BASIC on a Spectrum, the
> editor, the ability to run programs, the whole thing. But my code
> has captured control.

Then shrink it: wherever a piece of the copy can be replaced by a
call into the real ROM that doesn't steal control back, replace it.
What's left is the spine. She knew it could be done. But it fell
out of her code somewhere, she had no tools to see where, and she
set it down. Her guess for the spine's size was 3 to 4K.

Forty-odd years later, on Sunday 25 October 2026, she asked Fern to
do it. Fern guessed 1.5K.

## Measuring

The copy, at C000, is the ROM disassembled by SkoolKit and
reassembled. A test harness (`tools/difftest.py`) types the same
keys into the real ROM and into the copy, and compares the screen
and BASIC's report after every step. An execution map says whether
the real ROM's main loop ever ran, in which case control *fell
out*. The shrink (`tools/shrink.py`) replaces routines in groups
with jumps into the real ROM, keeps a group if the tests still pass,
and splits it if they don't.

The first answer was **556 bytes**: NEW, MAIN-EXEC and MAIN-ADD.
With those in RAM, control always comes home.

A first escape detector was wrong. It looked up the stack for "our"
return addresses and found stale ones. The execution map replaced
it, and 556 survived.

Requiring *every statement* to pass through our loop gave **1,794
bytes** on the test suite.

## Standing alone

The copy at C000 was 16K with stubs in it. The spine proper is only
the routines it keeps, assembled as themselves and calling the ROM
by address (`tools/build_spine.py`). Three things went wrong that
the copy had hidden:

1. **Tables that point at code must come along.** The parameter
   table names FOR, IF, INPUT and the rest by address. With the
   ROM's table, the ROM's own commands ran, and jumped back into
   the ROM's own loop.
2. **Low bytes matter.** The ROM tells SAVE, LOAD, VERIFY and MERGE
   apart by the low byte of a pointer into that table. The copy at
   C000 kept every low byte. The spine's table now starts at an
   address ending in 48, as the ROM's 1A48 does.
3. **Falling through is a jump.** At run time REM is one byte,
   `POP BC`, which drops into the ROM's LINE_END and so into its
   loop. None of the tests ran a REM inside a program, but
   Melissa's Advent of Code tapes did.

## Proving it

`tools/reach.py` builds the ROM's control-flow graph from the
disassembly. It finds every instruction from which the ROM's loops
can be reached, then checks every place the spine hands the ROM
control. Against an earlier build it named exactly the escapes the
tests had found. Then it found one no test had: **REPORT_G**, "No
room for line". While MAIN-ADD inserts a line, it pushes REPORT_G's
address into the slot ERR_SP points at, and the ROM's REPORT_G
jumps straight into the ROM's main loop. Owning it costs eight
bytes, and makes the loose spine **564 bytes**.

Typing a line like `10 SAVE "x": PRINT 1` also had the ROM's loop
check the rest of the line, because SAVE calls CHECK_END, which in
syntax mode walks into the loop. The spine owns the front of SAVE,
LIST and DRAW, up to their last CHECK_END call, then jumps back into
the ROM mid-routine. With that, and DATA, LLIST and SAVE's class
routine, every statement, run or checked, is ours: **2,439 bytes**.

## The bug from 1984

The slot ERR_SP points at isn't a handler anyone installs. It's the
bottom of the main loop's stack, and holds whatever the main loop
is calling: MAIN-2's return while you edit, MAIN-4's while a line
runs. An error does `LD SP,(ERR_SP)` and `RET`, so it lands wherever
the main loop is.

Enter a copy of the main loop by `RANDOMIZE USR` (because that keeps
your program) and the ROM's own frames are still underneath, with
the ROM's MAIN-4 in that slot. Everything works until the first
error, which silently hands the machine back to the ROM, with the
report looking exactly right. Unless you typed RUN or CLEAR first:
CLEAR rebuilds the bottom of the stack and puts *your* MAIN-4 there.
So it fell out sometimes, and not others.

`SPINE_WARM` is the cure, in 15 bytes. It rebuilds the bottom of the
stack as NEW does, then enters the main loop, keeping the program.

## Growing BASIC

Then the loops were ours to extend:
- **The four words** that had sat unused on every 48K since 1982:
  CAT, ERASE, FORMAT and MOVE.
- **Two reports** that say whose machine it is: "OK, still yours"
  and "BREAK, still yours".
- **Minding itself.** P_RAMT tells the ROM where RAM ends, so its
  own CLEAR refuses to go above the spine. LOAD CODE and POKE are
  guarded.
- **A calling convention for USR.** SCANNING saves USR's operation
  code ($10ED) on the machine stack, and takes the result's type
  from bit 7 of it when USR returns. Copying the stack out from
  inside a running FN showed that, and clearing the bit returns a
  string.

## Owning expressions too

With the loops ours, the ROM's SCANNING still evaluated every
expression. How much would owning it cost? `tools/closure.py` found
every ROM routine from which SCANNING can be reached by a way the
spine could take. It follows each `RST 28` only to the operations
its literal stream names. That came to 39 routines and 1,955 bytes,
plus SCANNING's function table (25 bytes: one-byte offsets, now
rewritten so they still land). VAL is a back door: the calculator
reaches `val` through its own table of addresses, so the dispatcher
comes too (210 bytes), and SCANNING's operator step calls the
spine's.

The guesses, made before measuring: Melissa's 3K, Fern's 3.5K, and
another Fern's 4.5K. The `expr` module is 2,190 bytes, which makes a
spine owning statements and expressions 4,629. It was proved as the
spine was:
- reach.py with SCANNING as the target, with the calculator's
  streams modelled;
- every real-ROM comparison with SCANNING's range forbidden.

## Mistakes, kept

- **The first escape detector** read stale stack.
- **A `tail -3` hid four failing lines.** The checks count DIFF
  lines now.
- **A guess that typing a numbered line "re-anchors" the stack.** It
  doesn't; RUN does.
- **EA58 converted to decimal by hand** gave 60248 instead of 59992.
  Every address now comes from the `.sym`.
- **A stack probe overwrote itself.**
- **DEF FN's check:** A held FLAGS, not the character.
- **FN_RET's string results came back as garbage**, because the
  calculator takes STKEND from DE on its way back. The float example
  had only worked by luck.

Each one was caught by looking, and each one is now a rule in
HACKING.md.
