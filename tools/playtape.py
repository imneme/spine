"""playtape.py TAPEDIR SHOTDIR: what Melissa will do, on a fresh 48K. LOAD "" the spine-demo tape (the loader brings
the spine up: the copyright screen), LOAD "" again (the demo), a key at each pause, BREAK and CONTINUE when asked,
then the suggested ERASE, LIST, FORMAT, LIST, RUN; then the Fiddlehead tape. A screenshot of each screen to
SHOTDIR (NN-name.png), each report printed, and whether the ROM's loops ran once the spine was up."""
import ctypes, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import spinepaths as P  # noqa: E402
P.emulator()
from speccy import Speccy
tapes, shots = sys.argv[1], sys.argv[2]
os.makedirs(shots, exist_ok=True)
zx = Speccy(); zx.wait_ready()
n = 0


def shot(name):
    global n
    n += 1
    zx.run(5)
    zx.shot(os.path.join(shots, f'{n:02d}-{name}.png'))
    print(f'{n:02d} {name:14s} {zx.report()!r}')


zx.insert_tape(os.path.join(tapes, 'spine-demo.tap'))
zx.type('LOAD ""\n'); zx.wait_ready(max_frames=50 * 60)
shot('boot')
zx.lib.zx_execmap(zx.z, 1, -1)                 # from here on, the spine's machine
zx.type('LOAD ""\n'); zx.wait_ready(max_frames=50 * 60, pause=True)
shot('title')
for name in ('move', 'cat', 'usr'):
    zx.keystroke('ENTER'); zx.wait_ready(max_frames=50 * 60, pause=True)
    shot(name)
zx.keystroke('ENTER'); zx.wait_ready(max_frames=50 * 60, pause=True)
shot('break-me')
zx.keystroke('BREAK'); zx.wait_ready(max_frames=50 * 10)
shot('broken')
zx.type('CONTINUE\n'); zx.wait_ready(max_frames=50 * 60)
shot('last')
for cmd, name in (('ERASE 1 TO 8999', None), ('CLS: LIST', 'erased'), ('FORMAT', None), ('CLS: LIST', 'formatted'),
                  ('CLS: RUN', 'run')):
    zx.type(cmd + '\n'); zx.wait_ready(max_frames=50 * 60)
    if name:
        shot(name)
zx.insert_tape(os.path.join(tapes, 'fiddlehead.tap'))
zx.type('LOAD ""\n'); zx.wait_ready(max_frames=50 * 120)
shot('fiddlehead')
m = ctypes.cast(zx.lib.zx_execmap_get(zx.z), ctypes.POINTER(ctypes.c_uint32))
fell = [f'{a:04X}' for lo, hi in ((0x12A2, 0x1391), (0x1B28, 0x1B9E)) for a in range(lo, hi) if m[a]][:3]
print('once the spine was up, the ROM loops never ran' if not fell else f'FELL OUT: {fell}')
