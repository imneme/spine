; UDGs, and a heart on the boot line. A SPINE module: build_spine.py ... --module src/modules/udg.asm. Written by
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
; A: a star
  DEFB %00010000          ; ...#....
  DEFB %00010000          ; ...#....
  DEFB %00111000          ; ..###...
  DEFB %11111110          ; #######.
  DEFB %01111100          ; .#####..
  DEFB %00101000          ; ..#.#...
  DEFB %01000100          ; .#...#..
  DEFB %00000000          ; ........
; B: a ball
  DEFB %00111100          ; ..####..
  DEFB %01111110          ; .######.
  DEFB %11111111          ; ########
  DEFB %11111111          ; ########
  DEFB %11111111          ; ########
  DEFB %11111111          ; ########
  DEFB %01111110          ; .######.
  DEFB %00111100          ; ..####..
; C: a club
  DEFB %00011000          ; ...##...
  DEFB %00111100          ; ..####..
  DEFB %00111100          ; ..####..
  DEFB %11011011          ; ##.##.##
  DEFB %11111111          ; ########
  DEFB %11011011          ; ##.##.##
  DEFB %00011000          ; ...##...
  DEFB %00111100          ; ..####..
; D: a diamond
  DEFB %00011000          ; ...##...
  DEFB %00111100          ; ..####..
  DEFB %01111110          ; .######.
  DEFB %11111111          ; ########
  DEFB %11111111          ; ########
  DEFB %01111110          ; .######.
  DEFB %00111100          ; ..####..
  DEFB %00011000          ; ...##...
; E: an eighth note
  DEFB %00001100          ; ....##..
  DEFB %00001110          ; ....###.
  DEFB %00001011          ; ....#.##
  DEFB %00001000          ; ....#...
  DEFB %00001000          ; ....#...
  DEFB %00111000          ; ..###...
  DEFB %01111000          ; .####...
  DEFB %00110000          ; ..##....
; F: a fiddlehead, still curled
  DEFB %01111000          ; .####...
  DEFB %10000100          ; #....#..
  DEFB %10110010          ; #.##..#.
  DEFB %10101010          ; #.#.#.#.
  DEFB %10001010          ; #...#.#.
  DEFB %01110010          ; .###..#.
  DEFB %00000010          ; ......#.
  DEFB %00000010          ; ......#.
; G: grey
  DEFB %10101010          ; #.#.#.#.
  DEFB %01010101          ; .#.#.#.#
  DEFB %10101010          ; #.#.#.#.
  DEFB %01010101          ; .#.#.#.#
  DEFB %10101010          ; #.#.#.#.
  DEFB %01010101          ; .#.#.#.#
  DEFB %10101010          ; #.#.#.#.
  DEFB %01010101          ; .#.#.#.#
; H: a heart
  DEFB %01100110          ; .##..##.
  DEFB %11111111          ; ########
  DEFB %11111111          ; ########
  DEFB %11111111          ; ########
  DEFB %01111110          ; .######.
  DEFB %00111100          ; ..####..
  DEFB %00011000          ; ...##...
  DEFB %00000000          ; ........
; I: a smile
  DEFB %00111100          ; ..####..
  DEFB %01000010          ; .#....#.
  DEFB %10100101          ; #.#..#.#
  DEFB %10000001          ; #......#
  DEFB %10100101          ; #.#..#.#
  DEFB %10011001          ; #..##..#
  DEFB %01000010          ; .#....#.
  DEFB %00111100          ; ..####..
; J: down (as vi)
  DEFB %00011000          ; ...##...
  DEFB %00011000          ; ...##...
  DEFB %00011000          ; ...##...
  DEFB %00011000          ; ...##...
  DEFB %11011011          ; ##.##.##
  DEFB %01111110          ; .######.
  DEFB %00111100          ; ..####..
  DEFB %00011000          ; ...##...
; K: up (as vi)
  DEFB %00011000          ; ...##...
  DEFB %00111100          ; ..####..
  DEFB %01111110          ; .######.
  DEFB %11011011          ; ##.##.##
  DEFB %00011000          ; ...##...
  DEFB %00011000          ; ...##...
  DEFB %00011000          ; ...##...
  DEFB %00011000          ; ...##...
; L: right (as vi)
  DEFB %00000000          ; ........
  DEFB %00001000          ; ....#...
  DEFB %00001100          ; ....##..
  DEFB %11111111          ; ########
  DEFB %11111111          ; ########
  DEFB %00001100          ; ....##..
  DEFB %00001000          ; ....#...
  DEFB %00000000          ; ........
; M: left
  DEFB %00000000          ; ........
  DEFB %00010000          ; ...#....
  DEFB %00110000          ; ..##....
  DEFB %11111111          ; ########
  DEFB %11111111          ; ########
  DEFB %00110000          ; ..##....
  DEFB %00010000          ; ...#....
  DEFB %00000000          ; ........
; N: no
  DEFB %11000011          ; ##....##
  DEFB %11100111          ; ###..###
  DEFB %01111110          ; .######.
  DEFB %00111100          ; ..####..
  DEFB %00111100          ; ..####..
  DEFB %01111110          ; .######.
  DEFB %11100111          ; ###..###
  DEFB %11000011          ; ##....##
; O: a ring
  DEFB %00111100          ; ..####..
  DEFB %01100110          ; .##..##.
  DEFB %11000011          ; ##....##
  DEFB %10000001          ; #......#
  DEFB %10000001          ; #......#
  DEFB %11000011          ; ##....##
  DEFB %01100110          ; .##..##.
  DEFB %00111100          ; ..####..
; P: a pointer
  DEFB %00000000          ; ........
  DEFB %00011000          ; ...##...
  DEFB %00111100          ; ..####..
  DEFB %00111100          ; ..####..
  DEFB %01111110          ; .######.
  DEFB %01111110          ; .######.
  DEFB %11111111          ; ########
  DEFB %00000000          ; ........
; Q: a square
  DEFB %00000000          ; ........
  DEFB %01111110          ; .######.
  DEFB %01111110          ; .######.
  DEFB %01111110          ; .######.
  DEFB %01111110          ; .######.
  DEFB %01111110          ; .######.
  DEFB %01111110          ; .######.
  DEFB %00000000          ; ........
; R: a rocket
  DEFB %00011000          ; ...##...
  DEFB %00111100          ; ..####..
  DEFB %00100100          ; ..#..#..
  DEFB %00111100          ; ..####..
  DEFB %00111100          ; ..####..
  DEFB %01111110          ; .######.
  DEFB %01011010          ; .#.##.#.
  DEFB %00011000          ; ...##...
; S: a spade
  DEFB %00011000          ; ...##...
  DEFB %00111100          ; ..####..
  DEFB %01111110          ; .######.
  DEFB %11111111          ; ########
  DEFB %11111111          ; ########
  DEFB %11011011          ; ##.##.##
  DEFB %00011000          ; ...##...
  DEFB %00111100          ; ..####..
; T: a tick
  DEFB %00000001          ; .......#
  DEFB %00000011          ; ......##
  DEFB %00000110          ; .....##.
  DEFB %10001100          ; #...##..
  DEFB %11011000          ; ##.##...
  DEFB %01110000          ; .###....
  DEFB %00100000          ; ..#.....
  DEFB %00000000          ; ........
; U: a heart, open
  DEFB %01100110          ; .##..##.
  DEFB %10011001          ; #..##..#
  DEFB %10000001          ; #......#
  DEFB %10000001          ; #......#
  DEFB %01000010          ; .#....#.
  DEFB %00100100          ; ..#..#..
  DEFB %00011000          ; ...##...
  DEFB %00000000          ; ........
