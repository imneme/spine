"""closure.py [STATE.json] [SPINE.asm] [--ld]: what it would cost the spine to own expression evaluation too (Melissa: "how much it'd
cost to duplicate all of SCANNING (and every way into it)"). The ROM's control-flow graph, as reach.py's, plus the
calculator: an RST $28 reaches the operations its literal stream names (SkoolKit's comments name each one; CALCADDR
says where it is), and fp_calc_2, whose operation is in B, reaches them all. Then every ROM instruction from which
SCANNING (24FB, and the S_ routines up to the operator tables at 2795) can be reached. The closure is the routines
holding any of those, with their sizes; what the spine (STATE, default src/states/full.json) already owns is
counted apart. --ld also treats each LD of a code address as a possible jump."""
import collections
import json
import os
import re
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import spinepaths as P                                              # noqa: E402

state_path = next((a for a in sys.argv[1:] if a.endswith('.json')), os.path.join(P.ROOT, 'src', 'states', 'full.json'))
TARGET = (0x24FB, 0x2795)
lines = open(P.built('rom.asm')).read().split('\n')
sym = P.sym(P.built('rom0.sym'))
tagged = [f'SPL_{i}: {l.strip()}' if re.match(r'^\s+[A-Z]', l.split(';')[0]) else l for i, l in enumerate(lines)]
with tempfile.TemporaryDirectory() as td:
    open(f'{td}/t.asm', 'w').write('\n'.join(tagged))
    subprocess.run([P.PASMO, f'{td}/t.asm', f'{td}/t.bin', f'{td}/t.sym'], check=True, capture_output=True)
    at = {int(i): int(a, 16) for i, a in re.findall(r'^SPL_(\d+)\s+EQU\s+0?([0-9A-F]+)H', open(f'{td}/t.sym').read(), re.M)}
rows = sorted((a, i, lines[i].split(';')[0].strip(), lines[i].partition(';')[2].strip()) for i, a in at.items())
size = {a: (rows[k + 1][0] - a if k + 1 < len(rows) else 1) for k, (a, _, _, _) in enumerate(rows)}
DATA = re.compile(r'^DEF[BWMS]\b')

# the calculator's operations: CALCADDR's DEFWs, by name
calc = {}
k0 = next(i for i, l in enumerate(lines) if l.startswith('CALCADDR:'))
for l in lines[k0 + 1:k0 + 80]:
    m = re.match(r'^\s+DEFW\s+(\w+)', l)
    if not m:
        break
    calc[m.group(1)] = sym[m.group(1)]
ALIASES = [(r'^stk_(zero|one|half|pi_2|ten)$', 'stk_const_xx'), (r'^st_mem_\d', 'st_mem_xx'), (r'^get_mem_\d', 'get_mem_xx'),
           (r'^series_', 'series_xx')]


def op_target(name):
    if name in calc:
        return calc[name]
    for pat, gen in ALIASES:
        if re.match(pat, name) and gen in calc:
            return calc[gen]
    return None


def value(s):
    s = s.strip()
    return int(s[1:], 16) if s.startswith('$') else sym.get(s)


succ = collections.defaultdict(set)
for k, (a, i, t, comment) in enumerate(rows):
    if DATA.match(t):
        continue
    nxt = rows[k + 1][0] if k + 1 < len(rows) and not DATA.match(rows[k + 1][2]) else None
    op, _, args = t.partition(' ')
    args = args.replace(' ', '')
    cond = re.match(r'^(NZ|Z|NC|C|PO|PE|P|M),(.*)$', args)
    tgt = value(cond.group(2) if cond else args) if op in ('JP', 'JR', 'CALL', 'DJNZ') else None
    if op == 'JP' and args in ('(HL)', '(IX)', '(IY)'):
        continue
    if op in ('JP', 'JR'):
        succ[a] |= {tgt} | ({nxt} if cond else set())
    elif op in ('CALL', 'DJNZ'):
        succ[a] |= {tgt, nxt}
    elif op == 'RET':
        succ[a] |= {nxt} if args else set()
    elif op in ('RETN', 'RETI'):
        pass
    elif op == 'RST':
        n = value(args)
        if n == 0x08:
            succ[a] |= {n}
        elif n == 0x28:                            # the calculator: the operations its stream names
            j = k + 1
            ops = set()
            while j < len(rows) and DATA.match(rows[j][2]):
                word = re.match(r'^([a-z_0-9$]+)', rows[j][3] or '')
                if word:
                    name = word.group(1).rstrip(':')
                    if name == 'fp_calc_2':
                        ops |= set(calc.values())
                    elif op_target(name):
                        ops.add(op_target(name))
                j += 1
            after = rows[j][0] if j < len(rows) else None
            succ[a] |= ops | {after}
        else:
            succ[a] |= {n, nxt}
    else:
        succ[a] |= {nxt}
        ld = re.match(r'^(BC|DE|HL|IX|IY|SP),([A-Za-z_]\w*)$', args) if op == 'LD' and '--ld' in sys.argv else None
        if ld and ld.group(2) in sym and sym[ld.group(2)] < 0x4000:
            succ[a].add(sym[ld.group(2)])
for a in succ:
    succ[a].discard(None)

pred = collections.defaultdict(set)
for a, ss in succ.items():
    for b in ss:
        pred[b].add(a)
reach = {a for a, _, _, _ in rows if TARGET[0] <= a < TARGET[1]}
todo = list(reach)
while todo:
    b = todo.pop()
    for a in pred[b]:
        if a not in reach:
            reach.add(a)
            todo.append(a)

# only the ways in that matter: code the spine can hand control to (SPINE.asm, default build/bare.asm) and what that
# reaches. START (RST 0) reaches SCANNING through the ROM's own loops, which the spine never enters, and so on.
spine_asm = next((a for a in sys.argv[1:] if a.endswith('.asm')), P.built('bare.asm'))
src = open(spine_asm).read().split('\n')
defined = {m.group(1) for l in src for m in [re.match(r'^([A-Za-z_]\w*):', l)] if m}
hand = set()
for l in src:
    m = re.match(r'^(?:[A-Za-z_]\w*:\s*)?(JP|JR|CALL|DJNZ|LD|DEFW|RST)\s+(.*)$', l.split(';')[0].strip())
    if not m:
        continue
    for w in re.findall(r'[A-Za-z_]\w*', m.group(2)):
        if w not in defined and w in sym and sym[w] < 0x4000 and (m.group(1) != 'LD' or sym[w] in succ):
            hand.add(sym[w])
    if m.group(1) == 'RST':
        hand.add(value(m.group(2)))
hand.add(0x0038)
hand |= {a for a, _, _, _ in rows if TARGET[0] <= a < TARGET[1]}    # SCANNING itself is all owned: everything in it
F, todo = set(hand), list(hand)                                     # is a way in (its JP (HL) table hides S_FN's edges)
while todo:
    x = todo.pop()
    for y in succ.get(x, ()):
        if y not in F:
            F.add(y)
            todo.append(y)
reach &= F | {a for a, _, _, _ in rows if TARGET[0] <= a < TARGET[1]}
R = json.load(open(P.built('routines.json')))
code = sorted((e for e in R['entries'] if e['type'] == 'c'), key=lambda e: e['start'])
state = json.load(open(state_path))
owned = set(state['kept'])
inside = [e for e in code if any(e['start'] <= a < e['end'] for a in reach)]
tot = sum(e['end'] - e['start'] for e in inside)
new = [e for e in inside if e['start'] not in owned]
tot_new = sum(e['end'] - e['start'] for e in new)
lower = sum(size[a] for a in reach)
print(f'{len(reach)} ROM instructions can reach SCANNING ({lower} bytes of instructions);')
print(f'the routines holding them: {len(inside)}, {tot} bytes; the spine owns {len(inside) - len(new)} of them already, '
      f'so {len(new)} more, {tot_new} bytes')
for e in sorted(new, key=lambda e: -(e['end'] - e['start'])):
    print(f"  {e['start']:04X} {e['end'] - e['start']:5d} {e['name']}")
