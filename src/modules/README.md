# SPINE's modules

Each module is a file of Z80 source that extends BASIC. `./spine
build` takes them all by default, or `--with a,b` or
`--without a,b`. HACKING.md explains how a module is put together.
Sizes are in bytes, on top of the spine (2,439, plus 30 for its two
entry points).

| Module | Bytes | What |
|---|---:|---|
| `move` | 24 | `MOVE x,y`: the plot position, with no dot (B if off the screen) |
| `erase` | 63 | `ERASE a TO b`: lines a to b, gone; the running line can't be (S) |
| `cat` | 98 | `CAT`: the variables by name |
| `format` | 533 | `FORMAT` or `FORMAT start,step`: renumber, GO TOs too (T past 9999) |
| `guard` | 288 | LOAD CODE and POKE into the spine get U |
| `fnusr` | 156 | `DEF FN m$(…)=USR n`: the calling convention's helpers |
| `fnusr-examples` | 90 | three routines that use it (needs fnusr) |
| `stillyours` | | `0 OK, still yours`, `L BREAK, still yours` |
| `udg` | 207 | UDGs A to U at boot, and the heart on the © line |
| `expr` | 2,190 | expressions owned too: SCANNING and every way into it, so the ROM's never runs |
| `builtins` | 148 | `FN m(a,b)` (a MOD b) and `FN x$(n)` (n in hex), with no DEF FN needed (needs expr) |
| `percent` | 57 | the `%` operator: `a % b` is a MOD b, at the priority of `*` and `/` (needs expr) |
| `fastlines` | 36 | GO TO, GO SUB, RETURN and NEXT find their line faster: 1.8× on a 300-line program |

The **reports table** costs 435 bytes. It comes with the first
module that adds a report (erase S, format T, guard U) or rewords
one (stillyours); the rest of its entries are the ROM's own words.

CLEAR above the spine is refused by the ROM's own CLEAR whatever
modules you choose: both of the spine's entry points set P_RAMT.

## The calling convention (fnusr)

    DEF FN h(x,y)=USR addr        numeric context
    DEF FN r$(a$)=USR addr        string context

The machine code finds its arguments through the spine's helpers,
and returns with:
- `RET` and BC: a whole number, as USR always did
- `JP FN_RET`: the value on top of the calculator stack, a number,
  or a string in string context
- `JP FN_RETS` with DE = start, BC = length: that string

The helpers:
- `FN_CTX`: carry set in string context.
- `FN_ARG`: A = n gives HL pointing at argument n's five bytes,
  carry set if it's a string. Report Q if there's no such argument.
- `FN_STK`: A = n puts argument n on the calculator stack, ready
  for RST 28.

How it works: just before USR's machine code runs, SCANNING saves
USR's operation code ($10ED) on the machine stack. Afterwards it
takes the result's type from bit 7 of that code. In string context,
FN_RET clears the bit, and BASIC carries on with a string.

The examples, in `fnusr-examples`:
- `FN_HYPOT`: floats in and out
- `FN_REV`: a string reversed, built in the workspace
- `FN_YOURS`: one routine that answers 2026 to `FN c()` and
  "still yours" to `FN c$()`
