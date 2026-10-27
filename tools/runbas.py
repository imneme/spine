"""runbas.py SPINE.bin PROGRAM.bas SHOT.png [AT]: boot the spine (AT, default its .sym's SPINE_START; NEW read from SPINE.sym, never
typed by hand), type the program in, RUN it, print the report and whether the ROM's loops ran, save a screenshot."""
import ctypes, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import spinepaths as P  # noqa: E402
P.emulator()
from speccy import Speccy
binf, prog, shot = sys.argv[1], sys.argv[2], sys.argv[3]
at = int(sys.argv[4], 16) if len(sys.argv) > 4 else None   # (default: where the build says, SPINE_START)
sym = {n: int(a, 16) for n, a in re.findall(r'^(\S+)\s+EQU\s+0?([0-9A-F]+)H', open(os.path.splitext(binf)[0] + '.sym').read(), re.M)}
at = at if at is not None else sym['SPINE_START']
zx = Speccy(); zx.wait_ready()
zx.type(f'CLEAR {at - 1}\n'); zx.wait_ready()
zx.write(at, open(binf, 'rb').read())
zx.type(f'RANDOMIZE USR {sym["NEW"]}\n'); zx.wait_ready()
zx.lib.zx_execmap(zx.z, 1, -1)
for l in open(prog):
    if l.strip():
        zx.type(l.rstrip('\n') + '\n'); zx.wait_ready()
zx.type('RUN\n'); zx.wait_ready(max_frames=50 * 300)
print('report:', zx.report())
zx.run(5)                                          # a few frames: the report fully drawn
zx.shot(shot)
m = ctypes.cast(zx.lib.zx_execmap_get(zx.z), ctypes.POINTER(ctypes.c_uint32))
print('ROM loops ran:', [f'{a:04X}' for lo, hi in ((0x12A2, 0x1391), (0x1B28, 0x1B9E)) for a in range(lo, hi) if m[a]][:3] or 'never')
