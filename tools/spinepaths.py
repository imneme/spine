"""Where SPINE's tools, inputs and generated files are. paths.local (untracked; KEY=value lines, ~ allowed) says
where this machine keeps them, and the environment can override any key. Generated files (the ROM's disassembly
and what's worked out from it) go in build/, or SPINE_BUILD."""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_local = {}
if os.path.exists(os.path.join(ROOT, 'paths.local')):
    for line in open(os.path.join(ROOT, 'paths.local')):
        line = line.split('#', 1)[0].strip()
        if '=' in line:
            k, v = line.split('=', 1)
            _local[k.strip()] = v.strip()


def _get(key, default):
    return os.path.expanduser(os.environ.get(key) or _local.get(key) or default)


BUILD = _get('SPINE_BUILD', os.path.join(ROOT, 'build'))
PASMO = _get('PASMO', 'pasmo')                                     # the assembler
SKOOL2ASM = _get('SKOOL2ASM', 'skool2asm.py')                      # SkoolKit
ROM_SKOOL = _get('ROM_SKOOL', '')                                  # SkoolKit's Spectrum ROM disassembly, rom.skool
OMSE_AI = _get('OMSE_AI', '~/omse-ai')                             # the emulator (and its Python)
OMSE_PY = _get('OMSE_PY', os.path.join(OMSE_AI, '.venv', 'bin', 'python'))
ROM48 = _get('ROM48', os.path.join(OMSE_AI, 'roms', '48.rom'))      # the real 48K ROM, to check the disassembly


def built(name):
    """A file worked out from the ROM: rom.asm, rom0.bin, rom0.sym, routines.json."""
    return os.path.join(BUILD, name)


def sym(path):
    """A pasmo symbol table: name -> address."""
    return {n: int(a, 16) for n, a in re.findall(r'^(\S+)\s+EQU\s+0?([0-9A-F]+)H', open(path).read(), re.M)}


def emulator():
    """Make omse-ai's speccy module importable (the emulator tools run under OMSE_PY)."""
    import sys
    if OMSE_AI not in sys.path:
        sys.path.insert(0, OMSE_AI)
