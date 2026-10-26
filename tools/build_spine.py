"""build_spine.py STATE.json OUT.asm [ORG] [--module FILE.asm ...]: the spine as itself.

Only the kept routines' source (from build/rom.asm, the ROM's disassembly) is assembled, at ORG (default F800);
every other label is EQU its real ROM address, so the kept code calls the ROM directly. If the statement loop is
kept, SYNTAX (the parameter table, whose DEFWs name the commands) comes too, first, at an address with the ROM's
low byte (xx48), and CMDCLASS is rebuilt so each class offset reaches ours or a JP to the ROM's. A state's
'prefix' {start: cut} keeps a routine only up to address cut, then JPs to the ROM there. A kept routine that fell
through into one no longer here gets an explicit JP to it; a JR (or DJNZ) that now reaches into the ROM becomes a
JP. SPINE_END marks the spine's measure; after it come SPINE_WARM (RANDOMIZE USR here keeps the program) and
SPINE_COLD (the loader's way in), then the modules, then FEATURES_END.

A module extends BASIC. Lines before ';; code' are new parameter entries, P_X_NAME, placed right after SYNTAX
(the offset for P_NAME then points at it; every ROM entry keeps its address); the rest is code. Directives, each a
line of its own:
  ;; needs NAME ...      own these routines too (by their entry's name)
  ;; whole NAME ...      own all of these, not just a prefix
  ;; report X TEXT       report X says TEXT (0-9, A-R are the ROM's; S on are new)
  ;; copyright OPERAND   the boot line, as DEFM's operand (else the ROM's own, printed from the ROM)
  ;; cold LABEL          CALLed by SPINE_COLD before NEW
  ;; patch LABEL / ;; replace TEXT, then lines, then ;; end patch: put the lines in after the spine's LABEL:, or
                         in place of the one spine line starting TEXT (spaces squeezed)
Prints the spine's size."""
import json
import os
import re
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import spinepaths as P                                              # noqa: E402

argv = sys.argv[1:]
mods = [argv[i + 1] for i, a in enumerate(argv) if a == '--module']
args = [a for i, a in enumerate(argv) if a != '--module' and (i == 0 or argv[i - 1] != '--module')]
state_path, out = args[0], args[1]
org = int(args[2], 16) if len(args) > 2 else 0xF800

# the modules
params, mcode, patches, replaces, reports, colds, needs, whole, copyright = [], [], {}, {}, {}, [], [], [], None
for path in mods:
    text = open(path).read().split('\n')
    cut = next((i for i, l in enumerate(text) if l.strip() == ';; code'), None)
    p, c = (text[:cut], text[cut + 1:]) if cut is not None else ([], text)
    keep = []
    i = 0
    while i < len(c):
        l = c[i]
        if l.startswith((';; patch ', ';; replace ')):
            j = next(k for k in range(i, len(c)) if c[k].strip() == ';; end patch')
            if l.startswith(';; patch '):
                patches[l.split()[2]] = c[i + 1:j]
            else:
                replaces[' '.join(l[len(';; replace '):].split())] = c[i + 1:j]
            i = j + 1
            continue
        d = re.match(r';; (needs|whole|report|copyright|cold) (.*)$', l)
        if d:
            kind, rest = d.groups()
            if kind == 'needs':
                needs += rest.split()
            elif kind == 'whole':
                whole += rest.split()
            elif kind == 'report':
                reports[rest[0]] = rest[2:]
            elif kind == 'copyright':
                copyright = rest
            else:
                colds.append(rest.strip())
        else:
            keep.append(l)
        i += 1
    params += [l for l in p if not l.startswith(';; ')]
    mcode += keep
mlabels = {m.group(1) for l in params + mcode for m in [re.match(r'^([A-Za-z_]\w*):', l)] if m}

R = json.load(open(P.built('routines.json')))
entries = R['entries']
byname = {e['name']: e['start'] for e in entries}
state = json.load(open(state_path))
kept = set(state['kept']) | {byname[n] for n in needs}
prefix = {int(k, 16): int(v, 16) for k, v in state.get('prefix', {}).items() if int(k, 16) not in {byname[n] for n in whole}}
kept |= {byname[n] for n in whole}
real = P.sym(P.built('rom0.sym'))
lines = open(P.built('rom.asm')).read().split('\n')
first_label = {}                                           # each label's line in rom.asm
for i, l in enumerate(lines):
    m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*):', l)
    if m:
        first_label[m.group(1)] = i
addr = {}                                          # rom.asm line -> its ROM address (only needed for prefixes)
if prefix:
    tagged = [f'SPL_{i}: {l.strip()}' if re.match(r'^\s+[A-Z]', l.split(';')[0]) else l for i, l in enumerate(lines)]
    with tempfile.TemporaryDirectory() as td:
        open(f'{td}/t.asm', 'w').write('\n'.join(tagged))
        subprocess.run([P.PASMO, f'{td}/t.asm', f'{td}/t.bin', f'{td}/t.sym'], check=True, capture_output=True)
        addr = {int(i): int(a, 16) for i, a in re.findall(r'^SPL_(\d+)\s+EQU\s+0?([0-9A-F]+)H', open(f'{td}/t.sym').read(), re.M)}
tails = []
loop_ours = byname['STMT_LOOP'] in kept
starts = sorted((first_label[e['labels'][0][0]], e) for e in entries if e['labels'] and e['labels'][0][0] in first_label)
chunks, defined = [], set()
for k, (i, e) in enumerate(starts):
    if e['name'] in ('CMDCLASS', 'SYNTAX') and not loop_ours:    # the tables only matter if the loop is ours
        continue
    if e['name'] == 'CMDCLASS':                    # the class table: made below, once we know which classes are ours
        chunks.append(['@CMDCLASS'])
        defined.add('CMDCLASS')
        continue
    if e['start'] not in kept and e['name'] != 'SYNTAX':    # SYNTAX: its DEFWs must reach our commands
        continue
    j = starts[k + 1][0] if k + 1 < len(starts) else len(lines)
    if e['start'] in prefix:                       # keep only up to the cut; then JP to the ROM's next instruction
        cut = prefix[e['start']]
        j = next(n for n in range(i, j) if addr.get(n, -1) >= cut)
        assert addr[j] == cut, f"{e['name']}: {cut:04X} is not an instruction (nearest {addr[j]:04X})"
    body = [l for l in lines[i:j] if not re.match(r'^\s*(ORG|END)\b', l.split(';')[0])]
    if e['start'] in prefix:
        body.append(f'  JP SPINE_TAIL_{cut:04X}            ; (the rest of {e["name"]} is the ROM\'s)')
        tails.append(f'SPINE_TAIL_{cut:04X} EQU ${cut:04X}')
        defined.update(re.match(r'^([A-Za-z_]\w*):', l).group(1) for l in body if re.match(r'^[A-Za-z_]\w*:', l))
        chunks.append(body)
        continue
    for l in body:
        m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*):', l)
        if m:
            defined.add(m.group(1))
    code = [l.split(';')[0].strip() for l in body if l.split(';')[0].strip() and not l.split(';')[0].strip().endswith(':')]
    last = code[-1] if code else ''
    nxt = starts[k + 1][1] if k + 1 < len(starts) else None
    adjacent = nxt is not None and nxt['start'] in kept and nxt['type'] == 'c'    # it falls into ours anyway
    ends = re.match(r'^(RET$|RETN$|RETI$|JP\s+\([A-Z]+\)$|JP\s+[A-Za-z_$][A-Za-z0-9_$+-]*$|JR\s+[A-Za-z_$][A-Za-z0-9_$+-]*$)', last)
    if e['type'] == 'c' and not adjacent and not ends and k + 1 < len(starts):
        body.append(f'  JP {starts[k + 1][1]["labels"][0][0]}            ; (the ROM fell through to here)')
    chunks.append(body)
# SYNTAX goes first, at an address with the ROM's low byte (1A48): the ROM tells SAVE/LOAD/VERIFY/MERGE apart by
# the low byte of T_ADDR, its pointer into the parameter table, so every low byte there must be what the ROM's is
chunks.sort(key=lambda c: not any(l.startswith('SYNTAX:') for l in c))
org = org if not loop_ours else (org & 0xFF00) | 0x48 if (org & 0xFF) <= 0x48 else ((org + 0x100) & 0xFF00) | 0x48
src = []
for body in chunks:
    if body == ['@CMDCLASS']:                      # one byte forward from each entry: to our class, or to a JP stub
        cls = [f'CLASS_{n:02X}' for n in range(12)]
        src += ['CMDCLASS:'] + [f'  DEFB {c if c in defined else "CC_" + c}-$' for c in cls]
        src += [f'CC_{c}: JP {c}' for c in cls if c not in defined]
        continue
    if any(l.startswith('SYNTAX:') for l in body) and params:     # repoint the offsets, then the new entries
        mine = {n[4:] for n in mlabels if n.startswith('P_X_')}
        body = [re.sub(r'DEFB \$[0-9A-F]{2}(\s*); P_(\w+)$', lambda m: f'DEFB P_X_{m.group(2)}-${m.group(1)}; P_{m.group(2)} (the spine\'s)'
                       if m.group(2) in mine else m.group(0), l) for l in body] + params
    for l in body:
        code, _, comment = l.partition(';')
        m = re.match(r'^(\s*)(JR|DJNZ)\s+(?:(NZ|Z|NC|C),)?([A-Za-z_][A-Za-z0-9_]*)\s*$', code.rstrip())
        if m and m.group(4) not in defined:                # a relative jump that now reaches into the ROM
            cc = m.group(3)
            if m.group(2) == 'DJNZ':
                l = f'{m.group(1)}DEC B\n{m.group(1)}JP NZ,{m.group(4)}   ; (was DJNZ into the ROM)'
            else:
                l = f'{m.group(1)}JP {cc + "," if cc else ""}{m.group(4)}   ; (was JR into the ROM)'
        if copyright:
            l = l.replace('LD DE,$1538', 'LD DE,SPINE_COPYRIGHT-1')
        key = next((k for k in replaces if ' '.join(l.split()).startswith(k)), None)
        if key:
            src += replaces.pop(key)
            continue
        src.append(l)
        lab = re.match(r'^([A-Za-z_]\w*):', l)
        if lab and lab.group(1) in patches:
            src += patches.pop(lab.group(1))

# the warm entry (after SPINE_END: not part of the measure): RANDOMIZE USR here keeps the BASIC program. It
# rebuilds the bottom of the stack as RAM_SET does, so the ERR_SP slot is the main loop's own; entering MAIN_EXEC
# by USR without this leaves the ROM's MAIN_4 in that slot, and the first error RETs into the ROM for good.
# Both entries also tell the ROM that RAM ends where the spine begins (P_RAMT), so the ROM's own CLEAR refuses to
# put RAMTOP above it: "M RAMTOP no good". SPINE_COLD is the loader's way in: the modules' cold work, then NEW.
have = {m.group(1) for c in chunks for l in c for m in [re.match(r'^([A-Za-z_]\w*):', l)] if m}
after = []
if 'MAIN_EXEC' in have:
    after += ['SPINE_WARM:', '  LD HL,SPINE_START-1', '  LD (P_RAMT),HL', '  LD HL,(RAMTOP)', '  LD (HL),$3E',
              '  DEC HL', '  LD SP,HL', '  DEC HL', '  DEC HL', '  LD (ERR_SP),HL', '  JP MAIN_EXEC']
if 'NEW' in have:
    after += ['SPINE_COLD:'] + [f'  CALL {c}' for c in colds] + ['  LD HL,SPINE_START-1', '  LD (P_RAMT),HL', '  JP NEW']
if copyright:
    after += ['  DEFB $80', 'SPINE_COPYRIGHT:', f'  DEFM {copyright}']
if reports:                                        # the reports, the ROM's words unless a module says otherwise
    rom = lines[first_label['REPORTS'] + 2:first_label['COMMA_SPC']]
    texts = [re.search(r'; (.) (.*)$', l).group(2) for l in rom if l.strip().startswith('DEFM')]
    codes = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    n = max(len(texts), max(codes.index(c) for c in reports) + 1)
    texts = [reports.get(codes[i], texts[i] if i < len(texts) else '-') for i in range(n)]
    after += ['REPORTS:', '  DEFB $80'] + [f'  DEFM "{t[:-1]}","{t[-1]}"+$80 ; {codes[i]} {t}' for i, t in enumerate(texts)]
equs = [f'{name} EQU ${a:04X}' for name, a in sorted(real.items()) if name not in defined and name not in mlabels
        and not (reports and name == 'REPORTS')]
assert not patches and not replaces, f'patches with nowhere to go: {sorted(patches)} {sorted(replaces)}'
text = '\n'.join([f'  ORG ${org:04X}', 'SPINE_START:'] + src + ['SPINE_END:'] + after + mcode + ['FEATURES_END:']
                 + equs + tails) + '\n'
open(out, 'w').write(text)
print(f'ORG {org:04X}; {len(chunks)} routines, {len(mods)} modules, {sum(len(c) for c in chunks)} source lines, '
      f'{len(equs)} labels left in the ROM')
