"""reach.py SPINE.asm [--main]: a static check that holds for any program. Builds the ROM's control-flow graph from
rom.asm (JP, JR, DJNZ, CALL, RST and fall-through; RST 8, RET and JP (HL) end a path), finds every ROM instruction
from which the ROM's statement loop (1B28-1B9D; --main: the main loop 12A2-1390) can be reached, then checks every
place the spine hands control to the ROM: CALL/JP targets, LD of code addresses (pushed returns, JP (HL)), the
SYNTAX table's DEFWs, and the interrupt at 0038. --ld also treats
every LD rr,label of a code address inside the ROM as a possible jump there (pushed handlers). Each handoff that can reach the loop is printed with a shortest
path. Conservative: a path may be infeasible (syntax-mode only, say), so read each one."""
import collections, os, re, subprocess, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import spinepaths as P  # noqa: E402
PASMO = P.PASMO
spine_asm = sys.argv[1]
target = (0x12A2, 0x1390) if '--main' in sys.argv else (0x1B28, 0x1B9D)
for _a in sys.argv:
    if _a.startswith('--target='):                # --target=LO-HI (hex), e.g. SCANNING's 24FB-2794
        target = tuple(int(x, 16) for x in _a.split('=')[1].split('-'))

lines = open(P.built('rom.asm')).read().split('\n')
sym = {n: int(a, 16) for n, a in re.findall(r'^(\S+)\s+EQU\s+0?([0-9A-F]+)H', open(P.built('rom0.sym')).read(), re.M)}
name_at = {}
for n, a in sorted(sym.items(), key=lambda x: x[1]):
    name_at.setdefault(a, n)
tagged = [f'SPL_{i}: {l.strip()}' if re.match(r'^\s+[A-Z]', l.split(';')[0]) else l for i, l in enumerate(lines)]
with tempfile.TemporaryDirectory() as td:
    open(f'{td}/t.asm', 'w').write('\n'.join(tagged))
    subprocess.run([PASMO, f'{td}/t.asm', f'{td}/t.bin', f'{td}/t.sym'], check=True, capture_output=True)
    at = {int(i): int(a, 16) for i, a in re.findall(r'^SPL_(\d+)\s+EQU\s+0?([0-9A-F]+)H', open(f'{td}/t.sym').read(), re.M)}
rows = sorted((a, i, lines[i].split(';')[0].strip()) for i, a in at.items())   # (address, line, text), ROM order
DATA = re.compile(r'^DEF[BWMS]\b')


def value(s):
    s = s.strip()
    if s.startswith('$'):
        return int(s[1:], 16)
    return sym.get(s)


CALC = {}                                          # the calculator's operations, by name (CALCADDR's DEFWs)
_k0 = next((i for i, l in enumerate(lines) if l.startswith('CALCADDR:')), None)
for _l in (lines[_k0 + 1:_k0 + 80] if _k0 is not None else []):
    _m = re.match(r'^\s+DEFW\s+(\w+)', _l)
    if not _m:
        break
    CALC[_m.group(1)] = sym[_m.group(1)]
_ALIAS = [(r'^stk_(zero|one|half|pi_2|ten)$', 'stk_const_xx'), (r'^st_mem_\d', 'st_mem_xx'),
          (r'^get_mem_\d', 'get_mem_xx'), (r'^series_', 'series_xx')]


def op_addr(name):
    if name in CALC:
        return CALC[name]
    return next((CALC[g] for p, g in _ALIAS if re.match(p, name) and g in CALC), None)


def stream_names(comments):
    """the operations a literal stream names (fp_calc_2, whose operation is in B: all of them)"""
    out = set()
    for c in comments:
        w = re.match(r'^([a-z_0-9$]+)', c or '')
        if w:
            name = w.group(1).rstrip(':')
            out |= set(CALC.values()) if name == 'fp_calc_2' else ({op_addr(name)} - {None})
    return out


def stream_ops(j):
    cs = []
    while j < len(rows) and DATA.match(rows[j][2]):
        cs.append(lines[rows[j][1]].partition(';')[2].strip())
        j += 1
    return stream_names(cs)


succ = collections.defaultdict(set)
for k, (a, i, t) in enumerate(rows):
    if DATA.match(t):
        continue
    nxt = rows[k + 1][0] if k + 1 < len(rows) and not DATA.match(rows[k + 1][2]) else None
    op, _, args = t.partition(' ')
    args = args.replace(' ', '')
    cond = re.match(r'^(NZ|Z|NC|C|PO|PE|P|M),(.*)$', args)
    tgt = value(cond.group(2) if cond else args) if op in ('JP', 'JR', 'CALL', 'DJNZ') else None
    if op == 'JP' and args in ('(HL)', '(IX)', '(IY)'):
        continue                                   # computed: a dead end here (noted, not followed)
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
            succ[a] |= {n}                         # an error: ERROR_1, which RETs to ERR_SP (ours); no fall-through
        elif n == 0x28:                            # the calculator: literals follow; it comes back after them,
            after = next((r[0] for r in rows[k + 1:] if not DATA.match(r[2])), None)   # having run the operations
            succ[a] |= {n, after} | stream_ops(k + 1)                                      # they name
        else:
            succ[a] |= {n, nxt}
    else:
        succ[a] |= {nxt}
        ld = re.match(r'^(BC|DE|HL|IX|IY|SP),([A-Za-z_]\w*)$', args) if op == 'LD' and '--ld' in sys.argv else None
        if ld and ld.group(2) in sym and sym[ld.group(2)] < 0x4000:
            succ[a].add(sym[ld.group(2)])          # --ld: a code address loaded may be pushed and RET to, or JP (HL)
for a in succ:
    succ[a].discard(None)

pred = collections.defaultdict(set)
for a, ss in succ.items():
    for b in ss:
        pred[b].add(a)
reach = set(a for a, _, _ in rows if target[0] <= a <= target[1])
todo = list(reach)
while todo:
    b = todo.pop()
    for a in pred[b]:
        if a not in reach:
            reach.add(a)
            todo.append(a)


def path(a):                                       # a shortest path from a into the target, as routine names
    prev, q = {a: None}, collections.deque([a])
    while q:
        x = q.popleft()
        if target[0] <= x <= target[1]:
            out = []
            while x is not None:
                out.append(x)
                x = prev[x]
            names = []
            for y in reversed(out):
                n = name_at.get(max(z for z in name_at if z <= y))
                if not names or names[-1] != n:
                    names.append(n)
            return ' > '.join(names)
        for y in succ.get(x, ()):
            if y in reach and y not in prev:
                prev[y] = x
                q.append(y)


spine = open(spine_asm).read().split('\n')
defined = {m.group(1) for l in spine for m in [re.match(r'^([A-Za-z_]\w*):', l)] if m}
hand = collections.defaultdict(set)                # ROM address -> how the spine hands it control
for l in spine:
    code = l.split(';')[0].strip()
    m = re.match(r'^(?:[A-Za-z_]\w*:\s*)?(JP|JR|CALL|DJNZ|LD|DEFW|RST)\s+(.*)$', code)
    if not m:
        continue
    op, args = m.group(1), m.group(2).replace(' ', '')
    for w in re.findall(r'[A-Za-z_]\w*', args):
        if w in defined or w not in sym or sym[w] >= 0x4000 or w in ('NZ', 'Z', 'NC', 'C', 'PO', 'PE', 'P', 'M'):
            continue
        a = sym[w]
        if op == 'LD' and a not in succ:          # LD of a data address: not a handoff
            continue
        hand[a].add(f'{op} {w}')
    if op == 'RST':
        hand[value(args)].add(f'RST {args}')
        if value(args) == 0x28:                    # and the operations its stream names
            k = spine.index(l)
            cs = []
            for l2 in spine[k + 1:]:
                if not re.match(r'^\s+DEFB', l2):
                    break
                cs.append(l2.partition(';')[2].strip())
            for a2 in stream_names(cs):
                hand[a2].add('RST $28 stream')
hand[0x0038].add('the interrupt')
bad = [(a, sorted(h)) for a, h in sorted(hand.items()) if a in reach]
print(f'{len(reach)} ROM instructions can reach {target[0]:04X}-{target[1]:04X}; the spine hands control to the ROM at '
      f'{len(hand)} places; {len(bad)} of them can reach it:')
for a, h in bad:
    print(f'  {a:04X} {", ".join(h)}:  {path(a)}')
