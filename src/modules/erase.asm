; ERASE a TO b: lines, gone. A SPINE module: build_spine.py ... --module src/modules/erase.asm. See src/modules/README.md.

P_X_ERASE:
  DEFB $06                ; CLASS_06: ERASE a TO b
  DEFB $CC                ; TO
  DEFB $06                ;
  DEFB $00                ;
  DEFW SP_ERASE           ;
;; code
;; report S Line in use

; THE 'ERASE' COMMAND: ERASE a TO b. Every line from a to b, gone, as if each had been typed as its number alone.
; The line that's running can't go (report S): everything else, before it or after, can, since RECLAIM moves the
; pointers (NXTLIN, CH_ADD, DATADD...) with the program.
SP_ERASE:
  CALL FIND_INT2          ; BC = b, the last line to go.
  PUSH BC                 ;
  CALL FIND_INT2          ; BC = a, the first.
  POP HL                  ; HL = b.
  LD DE,$270F             ; No line is above 9999: b is at most that.
  PUSH HL                 ;
  AND A                   ;
  SBC HL,DE               ;
  POP HL                  ;
  JR C,ER_1               ;
  EX DE,HL                ;
ER_1:
  PUSH HL                 ; Save b.
  LD DE,(PPC)             ; The line running now (a command typed in has
  AND A                   ; FFFE, which is never in range).
  SBC HL,DE               ; Is it after b?
  JR C,ER_2               ;
  EX DE,HL                ; Or before a?
  AND A                   ;
  SBC HL,BC               ;
  JR C,ER_2               ;
  RST $08                 ; Report S: it would erase itself.
  DEFB $1B                ;
ER_2:
  POP HL                  ; b + 1: the first line that stays.
  INC HL                  ;
  PUSH HL                 ;
  LD H,B                  ; The first line at or after a.
  LD L,C                  ;
  CALL LINE_ADDR          ;
  EX (SP),HL              ; Keep it; and the first at or after b + 1.
  CALL LINE_ADDR          ;
  POP DE                  ; DE = the first to go, HL = the first to stay.
  AND A                   ;
  SBC HL,DE               ; Nothing between them (or a was after b): done.
  RET Z                   ;
  RET C                   ;
  ADD HL,DE               ;
  JP RECLAIM_1            ; Reclaim DE to HL - 1.
