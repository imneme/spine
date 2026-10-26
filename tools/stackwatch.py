"""stackwatch.py SPINE.bin AT ENTRY-LABEL STEP...: enter the spine by RANDOMIZE USR at a label (no NEW), then after
each typed step print every stack word from SP up to RAMTOP, named, with ERR_SP marked, and whether the ROM's
main loop (12A2-1390) ran during the step."""
import ctypes, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import spinepaths as P  # noqa: E402
P.emulator()
from speccy import Speccy
binf, at, entry, steps = sys.argv[1], int(sys.argv[2], 16), sys.argv[3], sys.argv[4:]
spine = {n: int(a, 16) for n, a in re.findall(r'^(\S+)\s+EQU\s+0?([0-9A-F]+)H', open(os.path.splitext(binf)[0] + '.sym').read(), re.M)}
rom = {int(a, 16): n for n, a in re.findall(r'^(\S+)\s+EQU\s+0?([0-9A-F]+)H', open(P.built('rom0.sym')).read(), re.M)}
ours = {a: n for n, a in spine.items() if a >= at}
def nm(w):
    t = ours if w >= at else rom if w < 0x4000 else {}
    k = max((x for x in t if x <= w), default=None)
    return f'{"*" if w >= at else ""}{t[k]}+{w - k}={w:04X}' if k is not None and w - k < 0x200 else f'{w:04X}'
zx = Speccy(); zx.wait_ready()
zx.type(f'CLEAR {at - 1}\n'); zx.wait_ready()
zx.write(at, open(binf, 'rb').read())
def word(a):
    m = zx.read(a, 2); return m[0] | m[1] << 8
def show(what):
    sp, esp, top = zx.regs()['sp'], word(0x5C3D), word(0x5CB2)
    frames = []
    for a in range(sp, top + 1, 2):
        w = word(a)
        frames.append(('>' if a == esp else '') + (f'[{a:04X}]' if a == esp else '') + nm(w))
    print(f'{what:22s} SP {sp:04X} ERR_SP {esp:04X}: ' + ' '.join(frames))
zx.lib.zx_execmap(zx.z, 1, -1)
zx.type(f'RANDOMIZE USR {spine[entry]}\n'); zx.wait_ready(); show(f'USR {entry}')
for st in steps:
    zx.lib.zx_execmap(zx.z, 0, -1); zx.lib.zx_execmap(zx.z, 1, -1)    # it only clears going from off to on
    zx.type(st + '\n'); zx.wait_ready()
    m = ctypes.cast(zx.lib.zx_execmap_get(zx.z), ctypes.POINTER(ctypes.c_uint32))
    out = [f'{a:04X}' for a in range(0x12A2, 0x1391) if m[a]][:2]
    show(st + (' [ROM loop ' + ','.join(out) + ']' if out else ''))
