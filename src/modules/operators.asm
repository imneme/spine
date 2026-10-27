; New operators: a % b (MOD), a & b and a | b (bitwise AND and OR), a AT n (shift). A SPINE module (needs expr):
; build_spine.py ... --module src/modules/operators.asm. See src/modules/README.md.
;
; Melissa: "if we own expression evaluation, can't we add a % operator?", and then & and |, and AT as a shift ("3 AT
; 2 is a left shift and 255 AT -2 is a right shift by two"). SCANNING finds an operator in OPERATORS (a character
; and its operation code) and its priority by the code; the code's low six bits are the calculator operation it
; runs, through our CALCULATE (the expr module's), whose CALCADDR is ours to change: every other RST 28 goes to
; the ROM's calculator, so the operations reused here (+00 jump_true, +01 exchange, +02 delete, +32 n_mod_m, which
; no operator ever asks for) are untouched everywhere else.
;   a % b    MOD: a - b*INT (a/b), so -7 % 3 is 2       code C2h, priority 8, as * and /
;   a & b    bitwise AND, of whole numbers 0 to 65535    code C0h, priority 7, between + and *
;   a | b    bitwise OR, likewise                        code C1h, priority 6, as + and -
;   a AT n   a shifted left n bits (right, for n < 0),   code F2h, priority 8, as * and / (it multiplies or
;            in 16 bits: bits shifted out are lost        divides by a power of two)
; All bind tighter than the comparisons, so IF x&1=1 means what it says. Between strings SCANNING says no: for
; codes C0h to C7h by itself (the code + 8 is under 10h), for AT by a check added to S_TIGHTER. LIST shows % & |
; as they are, and AT as the keyword it is; a plain 48K says Nonsense in BASIC to any of them.
;; replace LD HL,OPERATORS ; The pointer to the table. @ S_OPERTR
  LD HL,SP_OPERATORS      ; The pointer to the table (the spine's, with %).
;; end patch
;; replace LD HL,$26ED ; The pointer to the priority table @ S_OPERTR
  CALL SP_PRIO            ; The pointer to the priority table (the spine's).
;; end patch
;; replace DEFW jump_true ; +00 @ CALCADDR
  DEFW SP_ANDOP           ; +00 (the spine's: &)
;; end patch
;; replace DEFW exchange ; +01 @ CALCADDR
  DEFW SP_OROP            ; +01 (the spine's: |)
;; end patch
;; replace DEFW delete ; +02 @ CALCADDR
  DEFW SP_MODOP           ; +02 (the spine's: %)
;; end patch
;; replace DEFW n_mod_m ; +32 @ CALCADDR
  DEFW SP_SHIFTOP         ; +32 (the spine's: AT)
;; end patch
;; replace JR C,S_RPORT_C_2 ; The operations -, *, /, @ S_NOT_AND
  JR C,S_RPORT_C_2        ; The operations -, *, /, ↑ and OR are not possible
  CP $32+8                ; between strings (nor, the spine's, AT).
  JR Z,S_RPORT_C_2        ;
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
  DEFB "&",$C0            ; & (the spine's)
  DEFB "|",$C1            ; | (the spine's)
  DEFB $AC,$F2            ; AT (the spine's)
  DEFB $00                ; End marker.

; SP_PRIO: S_OPERTR's priority, made HL + BC (BC = the operation's code): codes C0h to CFh from the table, AT's
; from its own byte.
SP_PRIO:
  LD HL,SP_PRIORITIES-$C0 ;
  LD A,C                  ;
  CP $F2                  ;
  RET NZ                  ;
  LD HL,SP_PRIO_AT-$F2    ;
  RET                     ;
SP_PRIO_AT:
  DEFB $08                ; AT (the spine's: as * and /)
SP_PRIORITIES:
  DEFB $07                ; & (the spine's: between + and *)
  DEFB $06                ; | (the spine's: as + and -)
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

; SP_ANDOP, SP_OROP: the calculator's operations for & and |: a, b -> a AND b, a OR b, bit by bit, as whole numbers
; 0 to 65535 (report B otherwise). STACK_BC leaves HL and DE as an operation should.
SP_ANDOP:
  CALL SP_TWO             ; DE = a, BC = b.
  LD A,B                  ;
  AND D                   ;
  LD B,A                  ;
  LD A,C                  ;
  AND E                   ;
  LD C,A                  ;
  JP STACK_BC             ;
SP_OROP:
  CALL SP_TWO             ;
  LD A,B                  ;
  OR D                    ;
  LD B,A                  ;
  LD A,C                  ;
  OR E                    ;
  LD C,A                  ;
  JP STACK_BC             ;
SP_TWO:
  CALL FIND_INT2          ; b (the last value),
  PUSH BC                 ;
  CALL FIND_INT2          ; then a.
  LD D,B                  ;
  LD E,C                  ;
  POP BC                  ;
  RET                     ;

; SP_SHIFTOP: the calculator's operation for AT: a, n -> a shifted n bits left (right if n is negative), in 16
; bits, bits shifted out lost: 3 AT 2 is 12, 255 AT -2 is 63. Exact, as shifting is; 2^n would come from the
; ROM's logarithms.
SP_SHIFTOP:
  CALL FP_TO_A            ; n: A its size, zero flag if it isn't negative.
  JP C,REPORT_B           ; (Over 255: report B.)
  PUSH AF                 ;
  CALL FIND_INT2          ; a: BC.
  POP AF                  ;
  JR NZ,SH_R              ; n < 0: right.
SH_L:
  AND A                   ;
  JP Z,STACK_BC           ;
  SLA C                   ;
  RL B                    ;
  DEC A                   ;
  JR SH_L                 ;
SH_R:
  AND A                   ;
  JP Z,STACK_BC           ;
  SRL B                   ;
  RR C                    ;
  DEC A                   ;
  JR SH_R                 ;
