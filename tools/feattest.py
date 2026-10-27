"""feattest.py SPINE.bin AT NEW|LABEL STEPS.txt [--golden FILE [--update]]: the new commands, which the real ROM refuses,
so there's nothing to diff against: a transcript instead. Boots the spine (CLEAR AT-1, NEW), types each step
(as difftest does: '!KEY', '=text'; {expr} is worked out from SPINE.sym's names, and the
transcript shows the {expr}, so it outlives a rebuild), and prints its report; a step starting '?' also prints the screen, every
non-blank line. With --golden, compares the transcript to FILE (--update writes it). Also says if the ROM's main
or statement loop ever ran."""
import ctypes, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import spinepaths as P  # noqa: E402
P.emulator()
import speccy
from speccy import Speccy
import re
binf, at, stepf = sys.argv[1], int(sys.argv[2], 16), sys.argv[4]
sym = {n: int(v, 16) for n, v in re.findall(r'^(\S+)\s+EQU\s+0?([0-9A-F]+)H', open(os.path.splitext(binf)[0] + '.sym').read(), re.M)}
new = sym[sys.argv[3]] if sys.argv[3] in sym else int(sys.argv[3], 16)      # a label (NEW, SPINE_COLD) or hex
golden = sys.argv[sys.argv.index('--golden') + 1] if '--golden' in sys.argv else None
zx = Speccy(); zx.wait_ready()
zx.type(f'CLEAR {at - 1}\n'); zx.wait_ready()
zx.write(at, open(binf, 'rb').read())
zx.type(f'RANDOMIZE USR {new}\n'); zx.wait_ready()
zx.lib.zx_execmap(zx.z, 1, -1)
class Out(list):                                   # printed as it goes, so a crash still shows the way there
    def append(self, x):
        super().append(x); print(x, flush=True)
    def __iadd__(self, xs):
        for x in xs: self.append(x)
        return self
out = Out()
for s in [l.rstrip('\n') for l in open(stepf) if l.strip() and not l.startswith('#')]:
    show = s.startswith('?')
    s = s[1:] if show else s
    shown = s                                      # {expr} over the .sym's names: addresses never by hand
    s = re.sub(r'\{([^}]+)\}', lambda m: str(eval(m.group(1), {}, dict(sym, BUILD=os.path.dirname(os.path.abspath(binf))))), s)
    if s.startswith('TAPE:'):                      # TAPE:path: into the deck (the next steps LOAD from it)
        zx.insert_tape(os.path.expanduser(s[5:]))
        continue
    if s.startswith('!'):
        key, _, n = s[1:].partition('*')
        for _ in range(int(n or 1)):
            zx.keystroke(key)
        zx.run(25)
    else:
        try:
            zx.type(s[1:] + '\n' if s.startswith('=') else s + '\n', raw=s.startswith('='))
        except speccy.ZXSyntaxError:
            out.append(f'{shown[:40]:40s} ? (refused: the flashing ?)')
            for _ in range(len(s) + 8):            # and cleared, as a person would: DELETE to the start
                zx.keystroke('DELETE')
            continue
    zx.wait_ready(max_frames=50 * 60)
    out.append(f'{shown[:40]:40s} {zx.report()}')
    if show:
        out += ['  | ' + l.rstrip() for l in zx.screen_text().split('\n') if l.strip()]
m = ctypes.cast(zx.lib.zx_execmap_get(zx.z), ctypes.POINTER(ctypes.c_uint32))
fell = [f'{a:04X}' for lo, hi in ((0x12A2, 0x1391), (0x1B28, 0x1B9E)) for a in range(lo, hi) if m[a]][:3]
out.append('the ROM loops never ran' if not fell else f'FELL OUT: {fell}')
text = '\n'.join(out) + '\n'
if golden and '--update' not in sys.argv:
    want = open(golden).read()
    print('GOLDEN: same' if want == text else 'GOLDEN: DIFFERS')
    sys.exit(want != text or bool(fell))
if golden:
    open(golden, 'w').write(text)
sys.exit(bool(fell))
