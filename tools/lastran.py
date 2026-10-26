"""lastran.py SPINE.bin AT NEW TAPE|STEPS.txt [DELTA]: boot the spine, LOAD the tape
(or type the steps), and when the real statement loop (1B28-1B9D)
first runs, name the ROM and spine code that ran in the DELTA T-states before it, and the stack at that moment."""
import ctypes, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import spinepaths as P  # noqa: E402
P.emulator()
from speccy import Speccy
binf, at, new, tape = sys.argv[1], int(sys.argv[2], 16), int(sys.argv[3], 16), os.path.expanduser(sys.argv[4])
delta = int(sys.argv[5]) if len(sys.argv) > 5 else 3000
def table(f):
    return {int(a, 16): n for n, a in re.findall(r'^(\S+)\s+EQU\s+0?([0-9A-F]+)H', open(f).read(), re.M)}
rom, sp_ = table(P.built('rom0.sym')), table(os.path.splitext(binf)[0] + '.sym')
sp_ = {a: n for a, n in sp_.items() if a >= at}
def name(a):
    t = sp_ if a >= at else rom
    k = max((x for x in t if x <= a), default=None)
    return f'{a:04X} {t[k]}+{a - k}' if k is not None else f'{a:04X}'
def boot():
    zx = Speccy(); zx.wait_ready()
    zx.type(f'CLEAR {os.environ.get("SPINE_CLEAR", at - 1)}\n'); zx.wait_ready()
    zx.write(at, open(binf, 'rb').read())
    zx.type(f'RANDOMIZE USR {new}\n'); zx.run(100)
    if tape.endswith('.txt'):                      # typed steps: all but the last, then the last without waiting
        steps = [l.rstrip('\n') for l in open(tape) if l.strip()]
        for st in steps[:-1]:
            zx.type(st + '\n'); zx.wait_ready()
        zx.type(steps[-1])
    else:
        zx.insert_tape(tape); zx.type('LOAD ""')
    zx.press('ENTER')                              # ENTER by hand, so the breakpoints are set before anything runs
    return zx
def until(zx, frames):
    pc = zx.run_until((0x1B28, 0x1B9D), frames=3)
    zx.release('ENTER')
    return pc if pc is not None else zx.run_until((0x1B28, 0x1B9D), frames=frames)
zx = boot(); t0 = zx.lib.zx_tstates(zx.z)
pc = until(zx, 50 * 900)
if pc is None:
    sys.exit('the real statement loop never ran')
t1 = zx.lib.zx_tstates(zx.z)
zx = boot()
zx.lib.zx_run_tstates(zx.z, t1 - delta - zx.lib.zx_tstates(zx.z))
zx.lib.zx_execmap(zx.z, 1, -1)
pc2 = until(zx, 5)
m = ctypes.cast(zx.lib.zx_execmap_get(zx.z), ctypes.POINTER(ctypes.c_uint32))
ran = [a for a in range(0x10000) if m[a] and (a < 0x4000 or a >= at)]
seen = []
for a in ran:
    n = name(a).split(' ')[1].split('+')[0]
    if n not in seen: seen.append(n)
print(f'hit {name(pc)} at T {t1}; replay hit {name(pc2) if pc2 is not None else None}')
print('ran in the last', delta, 'T:', ' '.join(seen))
s = zx.regs()['sp']; mem = zx.read(s, 12)
print('stack:', [name(mem[i] | mem[i + 1] << 8) for i in range(0, 12, 2)])
