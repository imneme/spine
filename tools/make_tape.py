"""make_tape.py SPINE.bin DEMO.bas|- SECOND.bas|- OUTDIR: the tapes, SAVEd by the machines themselves. Tape 1: the loader
and the spine's code, SAVEd by the real ROM, then the demo, typed into the spine and SAVEd by it. Tape 2: the
second program, typed into the spine after a NEW and SAVEd by it (only the spine can run it). Every address comes
from SPINE.sym. Writes OUTDIR/spine-demo.tap and OUTDIR/fiddlehead.tap."""
import os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import spinepaths as P  # noqa: E402
P.emulator()
from speccy import Speccy
binf, demo, second, outdir = sys.argv[1:5]
sym = {n: int(a, 16) for n, a in re.findall(r'^(\S+)\s+EQU\s+0?([0-9A-F]+)H', open(os.path.splitext(binf)[0] + '.sym').read(), re.M)}
at, new, code = sym['SYNTAX'], sym['SPINE_COLD'], open(binf, 'rb').read()   # COLD: P_RAMT, then NEW
os.makedirs(outdir, exist_ok=True)


def do(zx, line, save=False):
    try:
        zx.type(line + '\n')
    except Exception as e:
        sys.exit(f'typing {line!r}: {e}')
    if save:                                       # "Start tape, then press any key."
        zx.run(10)
        zx.keystroke('ENTER')
    zx.wait_ready(max_frames=50 * 120)


def typein(zx, path):                               # {expr}: from the .sym (and TOTAL, the code's length)
    env = dict(sym, TOTAL=len(code), commas=lambda n: f'{n:,}')
    for l in open(path):
        if l.strip():
            do(zx, re.sub(r'\{([^}]+)\}', lambda m: str(eval(m.group(1), {}, env)), l.rstrip('\n')))


zx = Speccy(); zx.wait_ready()
do(zx, f'CLEAR {at - 1}')
zx.write(at, code)
do(zx, f'10 CLEAR {at - 1}: LOAD ""CODE : RANDOMIZE USR {new}')
do(zx, 'SAVE "spine" LINE 10', save=True)
do(zx, f'SAVE "spine"CODE {at},{len(code)}', save=True)
do(zx, f'RANDOMIZE USR {new}')                    # into the spine: NEW, the copyright screen
if demo != '-':                                    # (no demo: the tape is the loader and the code)
    typein(zx, demo)
    do(zx, 'SAVE "spine demo" LINE 1', save=True)
open(os.path.join(outdir, 'spine-demo.tap' if demo != '-' else 'spine.tap'), 'wb').write(zx.saved_tape(clear=True))
if second != '-':
    do(zx, 'NEW')                                  # the spine's own NEW: still the spine
    typein(zx, second)
    do(zx, 'SAVE "Fiddlehead" LINE 10', save=True)
    open(os.path.join(outdir, 'fiddlehead.tap'), 'wb').write(zx.saved_tape(clear=True))
print(f'spine at {at:04X}, the loader enters at {new} ({new:04X}: SPINE_COLD), {len(code)} bytes; reports: {zx.report()!r}')
