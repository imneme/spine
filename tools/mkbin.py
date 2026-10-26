"""mkbin.py STATE.json OUT.bin: the copy with every routine STATE replaced turned into jumps into the real ROM (as
shrink.py tests it), for testing a result again"""
import json, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import spinepaths as P  # noqa: E402
code = [e for e in json.load(open(P.built('routines.json')))['entries'] if e['type'] == 'c']
b = bytearray(open(P.built('rom_c000.bin'), 'rb').read())
replaced = set(json.load(open(sys.argv[1]))['replaced'])
for e in code:
    if e['start'] in replaced:
        ls = sorted({e['start']} | {a for _, a in e['labels']})
        for at, nxt in zip(ls, ls[1:] + [e['end']]):
            if nxt - at >= 3:
                b[at:at + 3] = bytes([0xC3, at & 0xFF, at >> 8])
open(sys.argv[2], 'wb').write(b)
