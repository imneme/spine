; The % operator: a % b is a MOD b. A SPINE module (needs expr): build_spine.py ... --module
; src/modules/percent.asm. See src/modules/README.md.
;
; Melissa: "if we own expression evaluation, can't we add a % operator?" SCANNING finds an operator in OPERATORS
; (a character and its operation code) and its priority in PRIORITIES, indexed by the code less C3h; the code's low
; six bits are the calculator operation it runs, through our CALCULATE (the expr module's). '%' gets code C2h: a
; number from numbers, operation +02 (delete, which no operator ever asks for here, so our CALCADDR's +02 can be
; SP_MODOP; every other RST 28 goes to the ROM's calculator, whose delete is untouched), and priority 8, as * and
; /. For strings SCANNING says no by itself (2 + 8 is under 10h, as for - * / and OR). LIST shows a plain %.
;; replace LD HL,OPERATORS ; The pointer to the table. @ S_OPERTR
  LD HL,SP_OPERATORS      ; The pointer to the table (the spine's, with %).
;; end patch
;; replace LD HL,$26ED ; The pointer to the priority table @ S_OPERTR
  LD HL,SP_PRIORITIES-$C2 ; The pointer to the priority table (the spine's,
                          ; with % first).
;; end patch
;; replace DEFW delete ; +02 @ CALCADDR
  DEFW SP_MODOP           ; +02 (the spine's: %)
;; end patch

SP_OPERATORS:
  DEFB "+",$CF            ; +
  DEFB "-",$C3            ; -
  DEFB "*",$C4            ; *
  DEFB "/",$C5            ; /
  DEFB $5E,$C6            ; ↑
  DEFB "=",$CE            ; =
  DEFB ">",$CC            ; >
  DEFB "<",$CD            ; <
  DEFB $C7,$C9            ; <=
  DEFB $C8,$CA            ; >=
  DEFB $C9,$CB            ; <>
  DEFB $C5,$C7            ; OR
  DEFB $C6,$C8            ; AND
  DEFB "%",$C2            ; % (the spine's)
  DEFB $00                ; End marker.
SP_PRIORITIES:
  DEFB $08                ; % (the spine's: as * and /)
  DEFB $06                ; -
  DEFB $08                ; *
  DEFB $08                ; /
  DEFB $0A                ; ↑
  DEFB $02                ; OR
  DEFB $03                ; AND
  DEFB $05                ; <=
  DEFB $05                ; >=
  DEFB $05                ; <>
  DEFB $05                ; >
  DEFB $05                ; <
  DEFB $05                ; =
  DEFB $06                ; +

; SP_MODOP: the calculator's operation for %: a, b -> a - b*INT (a/b). Run by our CALCULATE as any binary
; operation; it works the stack with the ROM's calculator, then leaves HL and DE as an operation should (the last
; value, and STKEND, which RE_ENTRY takes from DE).
SP_MODOP:
  RST $28                 ; a, b
  DEFB $C1                ; st_mem_1: (b in mem 1; the ROM's int uses mem 0)
  DEFB $02                ; delete: a
  DEFB $31                ; duplicate: a, a
  DEFB $E1                ; get_mem_1: a, a, b
  DEFB $05                ; division: a, a/b
  DEFB $27                ; int: a, INT (a/b)
  DEFB $E1                ; get_mem_1: a, INT (a/b), b
  DEFB $04                ; multiply: a, b*INT (a/b)
  DEFB $03                ; subtract: a - b*INT (a/b)
  DEFB $38                ; end_calc
  RST $28                 ; (An empty calculation: HL = the last value, DE =
  DEFB $38                ; STKEND.)
  RET                     ;
