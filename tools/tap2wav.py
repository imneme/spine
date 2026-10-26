"""tap2wav.py IN.tap OUT.wav: a tape as sound, for a real 48K's EAR socket, in the ROM's own timings (T-states at
3.5 MHz): pilot pulses of 2168 (8063 before a header, 3223 before data), sync 667 and 735, a 0 bit two pulses of
855 and a 1 bit two of 1710, a second of quiet after each block. 44.1 kHz, 8-bit mono. Then it decodes its own
sound back into blocks and checks them byte for byte against the tape (a round trip, not a real Spectrum)."""
import struct, sys, wave
RATE, CLOCK = 44100, 3500000
inp, outp = sys.argv[1], sys.argv[2]
tap = open(inp, 'rb').read()
blocks, i = [], 0
while i < len(tap):
    n = struct.unpack('<H', tap[i:i + 2])[0]
    blocks.append(tap[i + 2:i + 2 + n])
    i += 2 + n
pulses = []                                        # (T-states) per half-wave; None: a second of quiet
for b in blocks:
    pulses += [2168] * (8063 if b[0] < 128 else 3223) + [667, 735]
    for byte in b:
        for k in range(7, -1, -1):
            pulses += [1710, 1710] if byte >> k & 1 else [855, 855]
    pulses.append(None)
samples, level, t = bytearray(), 0, 0.0           # t: where we are, in samples (fractions kept)
for p in pulses:
    if p is None:
        n = int(t + RATE) - len(samples)
        samples += bytes([128]) * n
        t += RATE
        continue
    t += p * RATE / CLOCK
    n = int(t) - len(samples)
    samples += bytes([0xC0 if level else 0x40]) * n
    level ^= 1
w = wave.open(outp, 'wb')
w.setnchannels(1); w.setsampwidth(1); w.setframerate(RATE); w.writeframes(bytes(samples))
w.close()

# the round trip: edges -> half-wave lengths -> pilot, sync, bits -> blocks
edges = [k for k in range(1, len(samples)) if samples[k] != samples[k - 1]]
got, cur, k = [], None, 0
halves = [(edges[j + 1] - edges[j]) * CLOCK / RATE for j in range(len(edges) - 1)]
starts = [edges[j] for j in range(len(edges) - 1)]
j = 0
while j < len(halves):
    if 1900 < halves[j] < 2500 and j + 2 < len(halves) and halves[j + 1] < 1000 and halves[j] > 1900:
        # the end of a pilot: the next two are the sync pulses (short)
        j += 1
        if not (500 < halves[j] < 900 and 500 < halves[j + 1] < 900):
            continue
        j += 2
        data, byte, nb = bytearray(), 0, 0
        while j + 1 < len(halves) and halves[j] < 2100 and starts[j + 1] - starts[j] < RATE // 10:
            bit = 1 if halves[j] + halves[j + 1] > 2 * 1282 else 0
            byte, nb = byte << 1 | bit, nb + 1
            if nb == 8:
                data.append(byte); byte, nb = 0, 0
            j += 2
        got.append(bytes(data))
    else:
        j += 1
ok = got == blocks
print(f'{outp}: {len(samples) / RATE:.1f} s, {len(blocks)} blocks; read back: '
      + ('all identical' if ok else f'DIFFERENT ({len(got)} blocks read)'))
sys.exit(not ok)
