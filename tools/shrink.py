"""The shrink: replace the copy's routines with jumps into the real ROM, keeping each replacement only if difftest
still passes (screens and reports the same as the real ROM's, control ours at idle). Group testing: a block of
routines is tried at once, and split on failure, down to the single routine that must stay. State is saved after
every test (state.json), so it resumes where it stopped; shrink.log says each verdict.

A routine R is replaced by a JP at each of its labels to that label's real address; where a label sits under 3 bytes
before the next one (or R's end), its own instructions are left to run into the next stub, which is what the real
ROM does there too. usage: shrink.py [--block N] [--steps SCRIPT.txt]"""
import argparse, json, os, subprocess, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import spinepaths as P  # noqa: E402
HERE = os.path.dirname(os.path.abspath(__file__))
ap = argparse.ArgumentParser(usage=__doc__)
ap.add_argument('--block', type=int, default=16)
ap.add_argument('--steps', help='a difftest script (a line per step); default its built-in set')
ap.add_argument('--strict', action='store_true', help='every statement must pass through our loop too')
a = ap.parse_args()
R = json.load(open(P.built('routines.json')))
code = [e for e in R['entries'] if e['type'] == 'c']
BASE = open(P.built('rom_c000.bin'), 'rb').read()
OMSE_PY = P.OMSE_PY
SUF = '_strict' if a.strict else ''
STATE = f'state{SUF}.json'                       # here, where it's run
LOG = open(f'shrink{SUF}.log', 'a')


def patched(starts):
    b = bytearray(BASE)
    for e in code:
        if e['start'] not in starts:
            continue
        ls = sorted(addr for _, addr in e['labels']) or [e['start']]
        if ls[0] != e['start']:
            ls = [e['start']] + ls
        for at, nxt in zip(ls, ls[1:] + [e['end']]):
            if nxt - at >= 3:
                b[at:at + 3] = bytes([0xC3, at & 0xFF, at >> 8])       # JP the real ROM's own
    return bytes(b)


def test(starts):
    p = 'try.bin'                                  # here, where it's run
    open(p, 'wb').write(patched(starts))
    t0 = time.time()
    r = subprocess.run([OMSE_PY, os.path.join(HERE, 'difftest.py'), 'try.bin'] + ([a.steps] if a.steps else []) + (['--strict'] if a.strict else []),
                       capture_output=True, text=True)
    last = (r.stdout.strip().splitlines() or ['?'])[-1]
    return r.returncode == 0, last, time.time() - t0


st = json.load(open(STATE)) if os.path.exists(STATE) else {'replaced': [], 'kept': [], 'tried': []}
replaced, kept = set(st['replaced']), set(st['kept'])
todo = [e['start'] for e in code if e['start'] not in replaced | kept]


def save():
    json.dump({'replaced': sorted(replaced), 'kept': sorted(kept)}, open(STATE, 'w'))


def name(s):
    return next(e['name'] for e in code if e['start'] == s)


def attempt(group):
    ok, last, secs = test(replaced | set(group))
    LOG.write(f"{time.strftime('%H:%M:%S')} {'PASS' if ok else 'fail'} {len(group):3d} from {name(group[0])} "
              f"({secs:.0f} s): {last}\n")
    LOG.flush()
    if ok:
        replaced.update(group)
        save()
        return
    if len(group) == 1:
        kept.add(group[0])
        save()
        return
    half = len(group) // 2
    attempt(group[:half])
    attempt(group[half:])


for i in range(0, len(todo), a.block):
    attempt(todo[i:i + a.block])
spine = [e for e in code if e['start'] in kept]
print(f"replaced {len(replaced)} routines; the spine: {len(spine)} routines, "
      f"{sum(e['end'] - e['start'] for e in spine)} bytes")
LOG.write(f"done: spine {len(spine)} routines, {sum(e['end'] - e['start'] for e in spine)} bytes\n")
