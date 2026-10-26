; Three to show the calling convention (needs fnusr). A SPINE module: build_spine.py ... --module src/modules/fnusr-examples.asm. See src/modules/README.md.

; Three to show it. DEF FN h(x,y)=USR FN_HYPOT: the hypotenuse, a float from floats. DEF FN r$(a$)=USR FN_REV:
; a$ backwards. DEF FN c()=USR FN_YOURS and DEF FN c$()=USR FN_YOURS: one routine, asked two ways.
FN_HYPOT:
  LD A,1                  ; x * x
  CALL FN_STK             ;
  RST $28                 ;
  DEFB $31                ; duplicate
  DEFB $04                ; multiply
  DEFB $38                ; end_calc
  LD A,2                  ; + y * y
  CALL FN_STK             ;
  RST $28                 ;
  DEFB $31                ; duplicate
  DEFB $04                ; multiply
  DEFB $0F                ; addition
  DEFB $28                ; sqr
  DEFB $38                ; end_calc
  JP FN_RET               ;
FN_REV:
  LD A,1                  ; a$: DE = its start, BC its length.
  CALL FN_ARG             ;
  INC HL                  ;
  LD E,(HL)               ;
  INC HL                  ;
  LD D,(HL)               ;
  INC HL                  ;
  LD C,(HL)               ;
  INC HL                  ;
  LD B,(HL)               ;
  PUSH DE                 ;
  PUSH BC                 ;
  RST $30                 ; BC_SPACES: room for the copy; DE = its start.
  POP BC                  ;
  POP HL                  ; HL = a$.
  PUSH DE                 ; (For FN_RETS: the copy.)
  PUSH BC                 ;
  EX DE,HL                ; DE = a$, HL = one past the copy's end.
  ADD HL,BC               ;
RV_1:
  LD A,B                  ;
  OR C                    ;
  JR Z,RV_2               ;
  DEC HL                  ; The copy, filled from its end.
  LD A,(DE)               ;
  LD (HL),A               ;
  INC DE                  ;
  DEC BC                  ;
  JR RV_1                 ;
RV_2:
  POP BC                  ;
  POP DE                  ;
  JP FN_RETS              ;
FN_YOURS:
  CALL FN_CTX             ; Asked for a number: the year.
  JR C,YR_1               ;
  LD BC,2026              ;
  RET                     ; (USR's way: BC.)
YR_1:
  LD DE,YR_TEXT           ; Asked for a string:
  LD BC,11                ;
  JP FN_RETS              ;
YR_TEXT:
  DEFM "still yours"
