"""mkudg.py: writes src/modules/udg.asm from the pictures below (# is ink), so a UDG is redrawn here, not in hex.
The suits are at their initials (C D H S); H is also the heart on the boot line."""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
G = {
    'A': ('a star', ['...#....', '...#....', '..###...', '#######.', '.#####..', '..#.#...', '.#...#..', '........']),
    'B': ('a ball', ['..####..', '.######.', '########', '########', '########', '########', '.######.', '..####..']),
    'C': ('a club', ['...##...', '..####..', '..####..', '##.##.##', '########', '##.##.##', '...##...', '..####..']),
    'D': ('a diamond', ['...##...', '..####..', '.######.', '########', '########', '.######.', '..####..', '...##...']),
    'E': ('an eighth note', ['....##..', '....###.', '....#.##', '....#...', '....#...', '..###...', '.####...', '..##....']),
    'F': ('a fiddlehead, still curled', ['.####...', '#....#..', '#.##..#.', '#.#.#.#.', '#...#.#.', '.###..#.', '......#.',
                                         '......#.']),
    'G': ('grey', ['#.#.#.#.', '.#.#.#.#'] * 4),
    'H': ('a heart', ['.##..##.', '########', '########', '########', '.######.', '..####..', '...##...', '........']),
    'I': ('a smile', ['..####..', '.#....#.', '#.#..#.#', '#......#', '#.#..#.#', '#..##..#', '.#....#.', '..####..']),
    'J': ('down (as vi)', ['...##...', '...##...', '...##...', '...##...', '##.##.##', '.######.', '..####..', '...##...']),
    'K': ('up (as vi)', ['...##...', '..####..', '.######.', '##.##.##', '...##...', '...##...', '...##...', '...##...']),
    'L': ('right (as vi)', ['........', '....#...', '....##..', '########', '########', '....##..', '....#...', '........']),
    'M': ('left', ['........', '...#....', '..##....', '########', '########', '..##....', '...#....', '........']),
    'N': ('no', ['##....##', '###..###', '.######.', '..####..', '..####..', '.######.', '###..###', '##....##']),
    'O': ('a ring', ['..####..', '.##..##.', '##....##', '#......#', '#......#', '##....##', '.##..##.', '..####..']),
    'P': ('a pointer', ['........', '...##...', '..####..', '..####..', '.######.', '.######.', '########', '........']),
    'Q': ('a square', ['........'] + ['.######.'] * 6 + ['........']),
    'R': ('a rocket', ['...##...', '..####..', '..#..#..', '..####..', '..####..', '.######.', '.#.##.#.', '...##...']),
    'S': ('a spade', ['...##...', '..####..', '.######.', '########', '########', '##.##.##', '...##...', '..####..']),
    'T': ('a tick', ['.......#', '......##', '.....##.', '#...##..', '##.##...', '.###....', '..#.....', '........']),
    'U': ('a heart, open', ['.##..##.', '#..##..#', '#......#', '#......#', '.#....#.', '..#..#..', '...##...', '........']),
}
assert sorted(G) == [chr(c) for c in range(ord('A'), ord('V'))]
assert all(len(rows) == 8 and all(len(r) == 8 and set(r) <= {'#', '.'} for r in rows) for _, rows in G.values())
HEAD = '''; UDGs, and a heart on the boot line. A SPINE module: build_spine.py ... --module src/modules/udg.asm. Written by
; tools/mkudg.py: redraw a UDG there, not here. See src/modules/README.md.
;
; At a cold start (SPINE_COLD, the loader's way in) the twenty-one UDGs, A to U, are set to these before NEW prints
; the boot line: the ROM's own "(c) 1982 Sinclair Research Ltd", from the ROM, unchanged, and then, at the far
; right of the line, "+" and a heart (UDG H, in INK 3: purple). The heart can't be in the message itself: PO_MSG
; stops at the first byte with bit 7 set, and every UDG has it. NEW typed later leaves the UDGs be: by then they're
; the program's.
;; cold SP_UDGCOPY
;; replace SET 5,(IY+$02) ; Signal 'the lower part will required
  CALL SP_HEART           ; (the spine's: "  +" and a purple heart)
  SET 5,(IY+$02)          ; Signal 'the lower part will required to be cleared'
;; end patch

SP_UDGCOPY:
  LD HL,SP_UDGS           ; A to U, into the UDG area (UDG).
  LD DE,(UDG)             ;
  LD BC,21*8              ;
  LDIR                    ;
  RET                     ;
SP_HEART:
  LD HL,SP_HEARTS         ; Two spaces, "+", INK 3, UDG H: the last four
SH_1:
  LD A,(HL)               ; columns of the boot line.
  CP $FF                  ;
  RET Z                   ;
  PUSH HL                 ;
  RST $10                 ;
  POP HL                  ;
  INC HL                  ;
  JR SH_1                 ;
SP_HEARTS:
  DEFB " "," ","+",$10,$03,$90+7,$FF

SP_UDGS:
'''
out = [HEAD.rstrip('\n')]
for k in sorted(G):
    name, rows = G[k]
    out.append(f'; {k}: {name}')
    out += [f'  DEFB %{int(r.replace("#", "1").replace(".", "0"), 2):08b}          ; {r}' for r in rows]
open(os.path.join(ROOT, 'src', 'modules', 'udg.asm'), 'w').write('\n'.join(out) + '\n')
print(f'src/modules/udg.asm: {len(G)} UDGs')
