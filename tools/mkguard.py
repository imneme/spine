"""mkguard.py SPINE.sym: guard.tap (beside the .sym), CODE blocks aimed below, into, across and just past the spine (and one into it,
for LOAD ""CODE 40000 to send elsewhere). Addresses from the .sym, so it follows a rebuild."""
import os, re, struct, sys
sym = {n: int(v, 16) for n, v in re.findall(r'^(\S+)\s+EQU\s+0?([0-9A-F]+)H', open(sys.argv[1]).read(), re.M)}
S, E = sym['SPINE_START'], sym['FEATURES_END']


def block(flag, data):
    body = bytes([flag]) + data
    x = 0
    for c in body:
        x ^= c
    return struct.pack('<H', len(body) + 1) + body + bytes([x])


def code(name, at, n):
    return block(0, bytes([3]) + name.ljust(10).encode() + struct.pack('<HHH', n, at, 32768)) + block(0xFF, bytes(range(n)))


blocks = [('below', 50000, 10), ('into', (S + E) // 2, 10), ('across', S - 4, 10), ('past', E, 10),
          ('elsewhere', (S + E) // 2, 10)]
open(os.path.join(os.path.dirname(sys.argv[1]), 'guard.tap'), 'wb').write(b''.join(code(*b) for b in blocks))
