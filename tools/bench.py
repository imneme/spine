"""bench.py [SPINE.bin ...]: how long jumps take. A program of 300 REM lines, then two loops after them, each 200
times round: FOR/NEXT, and GO TO; each jump finds its line by walking past the 300. Timed in frames (FRAMES, the
50ths of a second the machine counts itself), on the real ROM and on each build (entered at SPINE_COLD)."""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import spinepaths as P                                              # noqa: E402
P.emulator()
from speccy import Speccy                                           # noqa: E402

PROG = [f'{n} REM' for n in range(1, 301)] + [
    '9000 POKE 23672,0: POKE 23673,0: FOR i=1 TO 200: NEXT i: PRINT "next ";PEEK 23672+256*PEEK 23673',
    '9100 POKE 23672,0: POKE 23673,0: LET n=0',
    '9110 LET n=n+1: IF n<200 THEN GO TO 9110',
    '9120 PRINT "goto ";PEEK 23672+256*PEEK 23673']


def bench(binf):
    zx = Speccy(); zx.wait_ready()
    if binf:
        sym = P.sym(os.path.splitext(binf)[0] + '.sym')
        zx.type(f'CLEAR {sym["SPINE_START"] - 1}\n'); zx.wait_ready()
        zx.write(sym['SPINE_START'], open(binf, 'rb').read())
        zx.type(f'RANDOMIZE USR {sym.get("SPINE_COLD", sym["NEW"])}\n'); zx.wait_ready()
    for line in PROG:
        zx.type(line + '\n'); zx.wait_ready()
    out = {}
    for start in (9000, 9100):
        zx.type(f'CLS: GO TO {start}\n'); zx.wait_ready(max_frames=50 * 600)
        m = re.search(r'(next|goto) (\d+)', zx.screen_text())
        out[m.group(1)] = int(m.group(2))
    return out


base = bench(None)
print(f'{"real ROM":24s} next {base["next"]:4d} frames   goto {base["goto"]:4d} frames')
for b in sys.argv[1:]:
    r = bench(b)
    print(f'{os.path.basename(b):24s} next {r["next"]:4d} frames ({base["next"] / r["next"]:.2f}x)   '
          f'goto {r["goto"]:4d} frames ({base["goto"] / r["goto"]:.2f}x)')
