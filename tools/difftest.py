"""The test: the same keystrokes typed into the real 48K ROM and into the copy (each started by CLEAR 49151 and
then its own NEW), and after every step the whole screen and BASIC's report must be the same; and while the copy
waits for a key, the editor's caller must be the copy's MAIN-2. usage: difftest.py COPY.bin [SCRIPT.txt] (a line per step; default
a built-in set). Prints each step's verdict, and exits 1 if any differ or control escaped."""
import os, sys, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import spinepaths as P  # noqa: E402
P.emulator()
import speccy
from speccy import Speccy
STEPS = ['10 FOR I=1 TO 5: PRINT I*I;" ";: NEXT I', '20 PRINT : PRINT "SPINE OK"', 'RUN', 'PRINT 1/0', 'GO TO 99',
         'LIST', '30 IF I>3 THEN PRINT "BIG"', '40 GO SUB 100: STOP', '100 PRINT "SUB": RETURN', 'RUN',
         'CONTINUE', 'LET A$="HELLO": PRINT A$(2 TO 4)', 'DIM B(3): LET B(4)=1', 'CLEAR', 'PRINT B(1)',
         '50 DATA 1,2,3', 'RESTORE 50: READ X,Y: PRINT X+Y', 'DEF FN F(X)=X*X: PRINT FN F(7)', 'NEW', 'PRINT "AFTER NEW"']
args = [x for x in sys.argv[1:] if not x.startswith('--')]
steps = [l.rstrip('\n') for l in open(args[1])] if len(args) > 1 else STEPS
_sym = P.sym(os.path.splitext(sys.argv[1])[0] + '.sym') if os.path.exists(os.path.splitext(sys.argv[1])[0] + '.sym') else {}


def start(copy):
    at = int(os.environ.get('SPINE_AT', '%04X' % _sym.get('SPINE_START', 0xC000)), 16)   # where the build goes (its .sym
    new = int(os.environ.get('SPINE_NEW', '%04X' % _sym.get('NEW', at + 0x11B7)), 16)      # says, if there is one), its NEW
    clear = int(os.environ.get('SPINE_CLEAR', str(at - 1)))               # both machines CLEAR the same
    zx = Speccy()
    zx.wait_ready()
    zx.type(f'CLEAR {clear}\n'); zx.wait_ready()
    if copy:
        zx.write(at, copy)
    entry = int(os.environ.get('SPINE_ENTRY', '%04X' % (new - at)), 16) if copy else 0x11B7    # the way in (NEW, or
    zx.type(f'RANDOMIZE USR {(at if copy else 0) + entry}\n')                                  # another, to test)
    zx.run(100)
    return zx
copy = open(sys.argv[1], 'rb').read()
OURS, THEIRS = 0xC000 + 0x12B4, 0x12B4           # MAIN-2's CALL EDITOR returns here: the copy's, or the real ROM's


def owner(zx):
    """who holds control while BASIC waits: whose MAIN-2 called the editor, found on the stack (the PC itself may
    rightly be in the real ROM, in a leaf such as WAIT-KEY or the interrupt)"""
    sp = zx.regs()['sp']
    mem = bytes(zx.read(sp, 160))
    words = {mem[i] | mem[i + 1] << 8 for i in range(0, len(mem) - 1)}
    if any(0xC000 + 0x12A2 <= w < 0xC000 + 0x1391 for w in words):     # a frame in the copy's MAIN-EXEC
        return 'copy'
    return 'out'
real, ours = start(None), start(copy)
import ctypes
ours.lib.zx_execmap(ours.z, 1, -1)              # from here on, every address the copy's machine executes is counted
FORBID = [(0x12A2, 0x1391)] + ([(0x1B28, 0x1B9E)] if '--strict' in sys.argv else [])
FORBID += [tuple(int(x, 16) for x in a.split('=')[1].split('-')) for a in sys.argv if a.startswith('--forbid=')]   # LO-HI, hex   # the real ROM's main loop
# (and, strict, its statement loop): if either ever runs, control fell out of the copy


def fell_out(zx):
    m = ctypes.cast(zx.lib.zx_execmap_get(zx.z), ctypes.POINTER(ctypes.c_uint32))
    return [f'{a:04X}' for lo, hi in FORBID for a in range(lo, hi) if m[a]][:3]
bad = 0
for k, s in enumerate(steps):
    for zx in (real, ours):
        if s.startswith('TAPE:'):                  # TAPE:path: the tape in the deck, LOAD "", and its program runs
            zx.insert_tape(os.path.expanduser(os.path.expandvars(s[5:])))     # $AOC_ARCHIVE and the like
            zx.type('LOAD ""\n')
            zx.wait_ready(max_frames=50 * 900)
            continue
        if s.startswith('!'):                      # !KEY or !KEY*N: a key pressed (BREAK, N, ENTER, SS+A...)
            key, _, n = s[1:].partition('*')
            for _ in range(int(n or 1)):
                zx.keystroke(key)
            zx.run(25)
        elif s.startswith('='):                    # =text: typed as it is at a prompt, then ENTER
            zx.type(s[1:] + '\n', raw=True)
        else:
            try:
                zx.type(s + '\n', raw=False)
            except speccy.ZXSyntaxError:           # the flashing ?: the line stays in the editor, as it should
                pass
        zx.wait_ready(max_frames=50 * 60)
    a, b = bytes(real.read(0x4000, 6144 + 768)), bytes(ours.read(0x4000, 6144 + 768))
    ra, rb = real.report(), ours.report()
    out = fell_out(ours)
    same = a == b and ra == rb
    escaped = bool(out)
    bad += (not same) or escaped
    diff = next((i for i in range(len(a)) if a[i] != b[i]), None)
    print(f"{'ok  ' if same and not escaped else 'DIFF'} {s[:40]:40s} report {ra!r}" + ('' if ra == rb else f' / ours {rb!r}')
          + ('' if diff is None else f' screen byte {diff}') + (f' FELL OUT: the real ROM ran {out}' if escaped else ''))
if '--strict' in sys.argv:          # a program running a while: every statement must go through our loop
    ours.type('9000 FOR Z=1 TO 300: LET Q=Z*Z: NEXT Z\n'); ours.wait_ready()
    ours.type('RUN 9000\n'); ours.wait_ready(max_frames=50 * 60)
    out = fell_out(ours)
    bad += bool(out)
    print('strict: a running program stayed in our statement loop' if not out else f'strict: FELL OUT {out}')
print(f'{len(steps) - bad} of {len(steps)} steps the same, control ours')
sys.exit(1 if bad else 0)
