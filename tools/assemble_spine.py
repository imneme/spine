"""assemble_spine.py SPINE.asm OUT.bin: assemble with pasmo; each relative jump pasmo finds out of range is widened
to a JP (DJNZ to DEC B and JP NZ), and it tries again, so only the jumps that must grow do."""
import re, subprocess, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import spinepaths as P  # noqa: E402
PASMO = P.PASMO
asm, out = sys.argv[1], sys.argv[2]
for attempt in range(200):
    r = subprocess.run([PASMO, asm, out, os.path.splitext(out)[0] + '.sym'], capture_output=True, text=True)
    err = [l for l in (r.stdout + r.stderr).splitlines() if l.startswith('ERROR')]
    if not err:
        sym = dict(re.findall(r'^(\S+)\s+EQU\s+0?([0-9A-F]+)H', open(os.path.splitext(out)[0] + '.sym').read(), re.M))
        org, end = int(sym['SPINE_START'], 16), int(sym['SPINE_END'], 16)
        last = org + os.path.getsize(out)                    # all of it: the spine, the warm entry, any features
        if end <= org or last > 0xFF58:
            sys.exit(f'the spine from {org:04X} runs to {end:04X}: past the UDGs (FF58) or round the top')
        print(f'assembled after widening {attempt} jumps: {end - org} bytes (all {last - org}), {org:04X}-{end - 1:04X}, NEW at {sym["NEW"]}')
        break
    m = re.search(r'Relative jump out of range\s+on line (\d+)', err[0])
    if not m:
        sys.exit(err[0])
    lines = open(asm).read().split('\n')
    n = int(m.group(1)) - 1
    code, _, comment = lines[n].partition(';')
    j = re.match(r'^(\s*)(JR|DJNZ)\s+(?:(NZ|Z|NC|C),)?(\S+)\s*$', code.rstrip())
    if not j:
        sys.exit(f'cannot widen: {lines[n]}')
    if j.group(2) == 'DJNZ':
        lines[n] = f'{j.group(1)}DEC B\n{j.group(1)}JP NZ,{j.group(4)}   ; (DJNZ, widened)'
    else:
        lines[n] = f'{j.group(1)}JP {j.group(3) + "," if j.group(3) else ""}{j.group(4)}   ; (JR, widened)'
    open(asm, 'w').write('\n'.join(lines))
