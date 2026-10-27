; Faster GO TO, GO SUB, RETURN and NEXT. A SPINE module: build_spine.py ... --module src/modules/fastlines.asm.
; See src/modules/README.md.
;
; Every jump in a running program (GO TO, GO SUB, RETURN, RUN, and NEXT going back to its FOR) arrives at
; LINE_NEW with a line number, and the ROM's LINE_ADDR finds that line by walking the program from the top. It
; steps with NEXT_ONE, which works out for each thing whether it's a line or a variable, so the walk costs a few
; hundred T-states a line, and a loop near the end of a long program pays it on every NEXT. SP_LINEADDR gives the
; same answer by stepping lines by their lengths, since a program's lines are only ever lines. Line numbers of
; 16384 and up are left to the ROM's own walk, which carries on into the variables, so even that stays as it was.
;; replace CALL LINE_ADDR ; The starting address of the line, or the 'first
  CALL SP_LINEADDR        ; The starting address of the line, or the 'first
;; end patch

; SP_LINEADDR: HL = a line number. Returns HL = that line, or the first after it (or VARS); DE = the line before
; it (PROG if none); zero flag set if the line is there. As LINE_ADDR.
SP_LINEADDR:
  LD A,H                  ; 16384 and up: the ROM's own walk.
  CP $40                  ;
  JP NC,LINE_ADDR         ;
  LD B,H                  ; BC = the line wanted.
  LD C,L                  ;
  LD HL,(PROG)            ;
  LD D,H                  ;
  LD E,L                  ;
LA_1:
  LD A,(HL)               ; This line's number, high byte first. Below the
  CP B                    ; one wanted: on to the next.
  JR C,LA_2               ;
  RET NZ                  ; Above it (or the variables, whose first byte
  INC HL                  ; is 40h or more): here.
  LD A,(HL)               ; The same high byte: the low byte decides.
  DEC HL                  ;
  CP C                    ;
  RET NC                  ; At or past it: here (zero flag if it's the one).
LA_2:
  LD D,H                  ; DE = this line, and on: past its number and its
  LD E,L                  ; length, then the length itself.
  INC HL                  ;
  INC HL                  ;
  PUSH BC                 ;
  LD C,(HL)               ;
  INC HL                  ;
  LD B,(HL)               ;
  INC HL                  ;
  ADD HL,BC               ;
  POP BC                  ;
  JR LA_1                 ;
