"""mkrom.py: everything SPINE works out from the ROM, into build/. SkoolKit's disassembly of the 48K ROM (rom.skool)
becomes rom.asm (skool2asm -H); pasmo assembles it at 0000 into rom0.bin and rom0.sym, which must be the real ROM
byte for byte (else nothing here can be trusted, and it stops); and routines.json lists each entry (c code, or
b/t/w/s/u data) with its span and its labels. Neither the ROM nor its disassembly is in this repository: they're
Amstrad's, and the disassembly's annotations are Logan and O'Hara's. paths.local says where yours are."""
import json
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import spinepaths as P                                              # noqa: E402

if not P.ROM_SKOOL or not os.path.exists(P.ROM_SKOOL):
    sys.exit('mkrom: no rom.skool (SkoolKit\'s ROM disassembly, from skoolkit.ca): set ROM_SKOOL in paths.local')
os.makedirs(P.BUILD, exist_ok=True)
asm = subprocess.run([P.SKOOL2ASM, '-H', P.ROM_SKOOL], capture_output=True, text=True)
if asm.returncode:
    sys.exit('mkrom: skool2asm: ' + asm.stderr)
open(P.built('rom.asm'), 'w').write(asm.stdout)
r = subprocess.run([P.PASMO, P.built('rom.asm'), P.built('rom0.bin'), P.built('rom0.sym')], capture_output=True, text=True)
if r.returncode:
    sys.exit('mkrom: pasmo: ' + r.stdout + r.stderr)
if open(P.built('rom0.bin'), 'rb').read() != open(P.ROM48, 'rb').read():
    sys.exit(f'mkrom: rom.asm assembled is not the ROM at {P.ROM48}, byte for byte')

entries, labels, pending = [], {}, None
for line in open(P.ROM_SKOOL, encoding='utf-8'):
    if line.startswith('@label='):
        pending = line.split('=', 1)[1].strip()
        continue
    m = re.match(r'^([a-z ])\$([0-9A-F]{4}) ', line)
    if not m:
        continue
    kind, a = m.group(1), int(m.group(2), 16)
    if kind != ' ':
        entries.append({'type': kind, 'start': a, 'labels': []})
    if pending:
        labels[pending] = a
        entries[-1]['labels'].append([pending, a])
        pending = None
for e, nxt in zip(entries, entries[1:] + [{'start': 0x4000}]):
    e['end'] = nxt['start']
    e['name'] = e['labels'][0][0] if e['labels'] else f"L{e['start']:04X}"
json.dump({'entries': entries, 'labels': labels}, open(P.built('routines.json'), 'w'))
# and the whole ROM assembled at C000: the copy that shrink.py measures against (the history's instrument)
open(P.built('rom_c000.asm'), 'w').write(asm.stdout.replace('  ORG $0000', '  ORG $C000', 1))
subprocess.run([P.PASMO, P.built('rom_c000.asm'), P.built('rom_c000.bin')], check=True, capture_output=True)
code = [e for e in entries if e['type'] == 'c']
print(f"mkrom: rom.asm is the ROM, byte for byte; {len(entries)} entries, {len(code)} code "
      f"({sum(e['end'] - e['start'] for e in code)} bytes), {len(labels)} labels, in {P.BUILD}")
