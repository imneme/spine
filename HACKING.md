# Hacking on SPINE

## How it's built

`./spine rom` runs `tools/mkrom.py`:
- SkoolKit's disassembly of the 48K ROM becomes `build/rom.asm`.
- That's assembled at 0000, and must be your ROM, byte for byte.
- Each routine's span and labels go into `build/routines.json`.

`tools/build_spine.py` then makes the spine from a **state**
(`src/states/full.json` or `loose.json`):
- the list of routines that must be ours, and
- for a few, a **prefix**: own them only up to an address, then
  jump back into the ROM mid-routine.

Only those routines' source is assembled. Every other label becomes
an `EQU` to the ROM's address, so the spine calls the ROM directly.
The builder also:
- turns a relative jump that now reaches the ROM into a `JP`;
- gives a routine that used to fall into one that isn't here an
  explicit `JP` to it;
- carries the parameter table (SYNTAX), and rebuilds the class
  table, when the statement loop is ours.

SYNTAX goes first, at an address ending in 48 like the ROM's 1A48.
The ROM tells SAVE, LOAD, VERIFY and MERGE apart by the low byte of
a pointer into that table, so every low byte in it must be the
ROM's.

`tools/assemble_spine.py` assembles it with pasmo, widening only
the jumps that turn out to be out of range.

## Modules

A module (`src/modules/*.asm`) is Z80 source in two parts.

**Before a line `;; code`** come new parameter entries, `P_X_NAME`.
They're placed straight after SYNTAX, and the offset for the
keyword's own entry, `P_NAME`, is pointed at them. Every ROM entry
keeps its address. For example:

    P_X_MOVE:
      DEFB $08          ; CLASS_08: two numbers, with a comma
      DEFB $00          ; CLASS_00: then the end of the statement
      DEFW SP_MOVE      ; and this runs (only when not checking syntax)

**After it** comes the code, placed after the spine. Directives, a
line each:

    ;; needs NAME ...      own these routines too
    ;; whole NAME ...      own all of these, not just a prefix
    ;; report X TEXT       report X says TEXT (S on are new)
    ;; cold LABEL          CALLed at a cold start, before NEW
    ;; patch LABEL         these lines go in after the spine's LABEL:,
    ...                    up to
    ;; end patch
    ;; replace TEXT        these lines replace the one spine line that
    ...                    starts with TEXT (spaces squeezed)
    ;; end patch

Add the module's name to `ALL` in `./spine`, a transcript test to
`tests/`, and a line to `src/modules/README.md`.

## The checks

`./spine check` runs these, in order:
- **static:** `tools/reach.py` builds the ROM's control-flow graph:
  every JP, JR, CALL, RST and fall-through. Then it checks that no
  place a build hands the ROM control can reach the ROM's statement
  loop (`--main`: its main loop). `--ld` also treats every code
  address the ROM loads into a register as a possible jump.
- **real ROM:** `tools/difftest.py` types the same keys into the
  real ROM and into a build, and compares the screen and the report
  after every step. `--strict` also fails if the ROM's statement
  loop ever runs; without it, only its main loop counts. The step
  files are `tests/steps_*.txt`.
- **modules:** `tools/feattest.py` runs `tests/steps_*.txt` on the
  batteries build, against `tests/golden_*.txt`. In steps, `{expr}`
  is worked out from the build's `.sym` (`{FN_HYPOT}`,
  `{SPINE_START-1}`), and the transcript keeps the `{expr}`, so it
  survives a rebuild.
- **tapes:** `tools/make_tape.py` has the machines SAVE them. The
  real ROM saves the loader and the code; the spine saves the demo,
  which is typed into it. `tools/playtape.py` plays them into a
  fresh 48K and checks the transcript in `tests/golden_play.txt`.

For looking closer:
- `tools/lastran.py` names what ran just before the ROM's loop
  first did.
- `tools/stackwatch.py` prints the named stack after each step.
- `tools/runbas.py` runs a .bas file and takes a screenshot.

## Rules learned the hard way

- **Addresses come from the `.sym`, never from your head.** EA58 is
  59992, not 60248.
- **Look, don't assume.** Copy the stack out from inside the call.
  Check what A holds before using it. Watch a test fail before
  trusting it to pass.
- **Count the DIFF lines.** A `tail` can hide four failures.
- **Falling through is a jump; a table is a jump; a handler on the
  stack is a jump.** reach.py knows the first two; `--ld`
  approximates the third.
