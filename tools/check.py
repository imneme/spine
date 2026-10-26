"""check.py [--quick]: every test SPINE has, in order, and what passed (./spine check runs this).

  builds     bare (the spine alone), loose, batteries (every module), and batteries with the ROM's report texts and
             no UDGs (so it can be put beside the real ROM)
  static     reach.py: no place the spine hands the ROM control can reach the ROM's own loops
  real ROM   difftest.py: the same keys into the real ROM and into a build; screens and reports must be the same,
             and the ROM's loops must never run (--quick skips this, the slow part). With AOC_ARCHIVE in
             paths.local, Melissa's own tapes too (they aren't in this repository)
  modules    feattest.py: the new words, the guards and the calling convention, against their transcripts
  tapes      the batteries tape made and played through, as someone loading it would, against its transcript
"""
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import spinepaths as P                                              # noqa: E402

ROOT, T = P.ROOT, os.path.join(P.ROOT, 'tools')
quick = '--quick' in sys.argv
results = []


def stage(name, ok, note=''):
    results.append((name, ok))
    print(f"{'ok  ' if ok else 'FAIL'} {name}{': ' + note if note else ''}", flush=True)


def py(*cmd, emu=False, env=None):
    r = subprocess.run([P.OMSE_PY if emu else sys.executable, *cmd], cwd=ROOT, capture_output=True, text=True,
                       env=dict(os.environ, **(env or {})))
    return r.returncode, r.stdout + r.stderr


def spine(*args):
    return py(os.path.join(ROOT, 'spine'), *args)


t0 = time.time()
code, out = py(os.path.join(T, 'mkrom.py'))
stage('rom: the disassembly is the ROM, byte for byte', code == 0, out.strip().split('\n')[-1])
if code:
    sys.exit(1)
BUILDS = [('bare', ['--bare', '--org', 'F300']), ('loose', ['--bare', '--loose', '--org', 'F800']),
          ('batteries', []), ('romwords', ['--without', 'stillyours,udg'])]
for name, args in BUILDS:
    code, out = spine('build', '-o', name, *args)
    stage(f'build {name}', code == 0, out.strip().split('\n')[-1])
for name, flags in [('bare', []), ('loose', ['--main']), ('batteries', []), ('batteries', ['--main', '--ld']),
                    ('romwords', [])]:
    code, out = py(os.path.join(T, 'reach.py'), P.built(name + '.asm'), *flags)
    stage(f'static {name} {" ".join(flags)}'.strip(), code == 0 and ' 0 of them can reach it' in out, out.split('\n')[0])

if not quick:
    tests = os.path.join(ROOT, 'tests')
    runs = [('bare', 'steps_all', 1), ('bare', 'steps_syntax', 1), ('bare', 'steps_room', 1),
            ('loose', 'steps_all', 0), ('loose', 'steps_room', 0),
            ('romwords', 'steps_all', 1), ('romwords', 'steps_syntax', 1), ('romwords', 'steps_room', 1)]
    archive = P._get('AOC_ARCHIVE', '')
    if archive and os.path.isdir(archive):
        runs += [('bare', 'local/' + t, 1) for t in ('sand', 'crt', 'day3', 'day7', 'day9')]
        runs += [('romwords', 'local/' + t, 1) for t in ('crt', 'day3', 'day9')]
    else:
        print('     (no AOC_ARCHIVE: Melissa\'s tapes skipped)')
    for name, steps, strict in runs:
        code, out = py(os.path.join(T, 'difftest.py'), P.built(name + '.bin'), os.path.join(tests, steps + '.txt'),
                       *(['--strict'] if strict else []), emu=True, env={'AOC_ARCHIVE': archive})
        diffs = sum(l.startswith('DIFF') for l in out.split('\n'))
        stage(f'real ROM {name} {steps}', code == 0 and diffs == 0, out.strip().split('\n')[-1])

code, out = py(os.path.join(T, 'mkguard.py'), P.built('batteries.sym'))
for t in ('feat', 'guard', 'usr'):
    code, out = py(os.path.join(T, 'feattest.py'), P.built('batteries.bin'), 'E848', 'SPINE_COLD',
                   os.path.join(ROOT, 'tests', f'steps_{t}.txt'), '--golden', os.path.join(ROOT, 'tests', f'golden_{t}.txt'),
                   emu=True)
    stage(f'modules {t}', code == 0, ' '.join(out.strip().split('\n')[-2:]))

tapes = P.built('tapes')
code, out = spine('tape', '-o', tapes)
stage('tapes made', code == 0, out.strip().split('\n')[-1])
code, out = py(os.path.join(T, 'playtape.py'), tapes, P.built('shots'), emu=True)
golden = os.path.join(ROOT, 'tests', 'golden_play.txt')
same = os.path.exists(golden) and open(golden).read() == out
stage('tapes played', code == 0 and 'never ran' in out and same,
      out.strip().split('\n')[-1] + ('' if same else ' (differs from tests/golden_play.txt)'))

bad = [n for n, ok in results if not ok]
print(f"{len(results) - len(bad)} of {len(results)} passed, {time.time() - t0:.0f} s" + (': ' + ', '.join(bad) if bad else ''))
sys.exit(bool(bad))
