; A better USR: DEF FN as the calling convention. A SPINE module: build_spine.py ... --module src/modules/fnusr.asm. See src/modules/README.md.

; A BETTER USR (Melissa: "multiple arguments... Floats and Strings returnable. A calling convention, indicating
; numeric or string context"). The convention is BASIC's own DEF FN, which the spine owns:
;   DEF FN h(x,y)=USR addr       numeric context: any number of arguments, numbers or strings, BASIC's to check
;   DEF FN r$(a$)=USR addr       string context: new; the ROM refuses a string FN whose body is a number
; and FN h(3,4), FN r$("abc") call it. The machine code finds its arguments through DEFADD, and returns BC (as
; USR always did) with RET, or any number or string with JP FN_RET or FN_RETS. Expressions are the ROM's (SCANNING
; isn't the spine's), so this works with what's there: before a USR runs, SCANNING pushes USR's operation code
; ($10ED) on the machine stack, and afterwards it takes the result's type from bit 7 of it. FN_RET clears that bit
; in string context, and SCANNING carries on with a string.

; FN_CTX: carry set in string context (the FN being evaluated is a string FN, m$), reset for numeric (or no FN at
; all: a plain USR). Uses A and HL.
FN_CTX:
  LD HL,(DEFADD)          ; Not in an FN: numeric.
  LD A,H                  ;
  OR L                    ;
  RET Z                   ; (A = 0: no carry.)
FX_1:
  DEC HL                  ; Back to the '(' after the FN's name,
  LD A,(HL)               ;
  CP "("                  ;
  JR NZ,FX_1              ;
  DEC HL                  ; and the character before it: '$' for a string.
  LD A,(HL)               ;
  CP "$"                  ;
  SCF                     ;
  RET Z                   ;
  AND A                   ;
  RET                     ;

; FN_ARG: A = n (1 for the first argument). Returns HL = its five bytes in the DEF FN line (a number, or a
; string's: unused, start, length), and carry set if it's a string. Report Q if there's no such argument.
; Uses A, B and HL.
FN_ARG:
  LD B,A                  ;
  LD HL,(DEFADD)          ; Not in an FN: no arguments.
  LD A,H                  ;
  OR L                    ;
  JR Z,FA_Q               ;
FA_1:
  LD A,(HL)               ; A letter (spaces stepped over); ')' means no
  CP " "                  ; more.
  JR NZ,FA_2              ;
  INC HL                  ;
  JR FA_1                 ;
FA_2:
  CP ")"                  ;
  JR Z,FA_Q               ;
  INC HL                  ; '$' after it: a string.
  LD A,(HL)               ;
  CP "$"                  ;
  JR NZ,FA_3              ;
  INC HL                  ;
FA_3:
  INC HL                  ; Past the 0E: the five bytes.
  DJNZ FA_4               ;
  CP "$"                  ; This one: carry for a string.
  SCF                     ;
  RET Z                   ;
  AND A                   ;
  RET                     ;
FA_4:
  LD A,L                  ; Past the five bytes.
  ADD A,5                 ;
  LD L,A                  ;
  JR NC,FA_5              ;
  INC H                   ;
FA_5:
  LD A,(HL)               ; A ',': on to the next. A ')': there isn't one.
  INC HL                  ;
  CP ","                  ;
  JR Z,FA_1               ;
FA_Q:
  RST $08                 ; Report Q.
  DEFB $19                ;

; FN_STK: A = n. Argument n goes onto the calculator stack, ready for RST $28 (a number) or FN_RET (a string).
FN_STK:
  CALL FN_ARG             ;
  LD A,(HL)               ; Its five bytes: A, E, D, C, B for STK_STORE.
  INC HL                  ;
  LD E,(HL)               ;
  INC HL                  ;
  LD D,(HL)               ;
  INC HL                  ;
  LD C,(HL)               ;
  INC HL                  ;
  LD B,(HL)               ;
  JP STK_STORE            ;

; FN_RETS: JP here with DE = a string's start and BC its length: that string is the FN's value. (Somewhere it'll
; stay put until the statement is done: the workspace (RST $30) is the ROM's own choice.)
FN_RETS:
  CALL STK_ST_0           ;
; FN_RET: JP here (the stack as it was on entry) to return the value on top of the calculator stack: a number in
; numeric context, a string in string context.
FN_RET:
  POP AF                  ; STACK_BC isn't wanted: the value is stacked.
  LD IY,ERR_NR            ; But its ending is (the machine code may have
  CALL FN_CTX             ; used IY). Numeric: straight to it.
  JR NC,FR_3              ;
  LD HL,$0000             ; A string: find USR's operation code a few words
  ADD HL,SP               ; up the stack (just above RE_ENTRY's return and a
  LD B,6                  ; scratch word), and clear its bit 7.
FR_1:
  INC HL                  ;
  INC HL                  ;
  LD A,(HL)               ;
  CP $ED                  ;
  JR NZ,FR_2              ;
  INC HL                  ;
  LD A,(HL)               ;
  DEC HL                  ;
  CP $10                  ;
  JR NZ,FR_2              ;
  RES 7,(HL)              ;
FR_3:
  RST $28                 ; As STACK_BC ends: an empty calculation leaves
  DEFB $38                ; DE = STKEND (and HL = the last value), which the
  AND A                   ; calculator's RE_ENTRY makes STKEND again.
  RET                     ;
FR_2:
  DJNZ FR_1               ;
  JR FA_Q                 ; (Not found: not called the way it should be.)

; DEF FN's syntax check, for a string FN whose body is USR: the ROM would refuse it (a number for a string), so
; when the body starts with USR the result is called the FN's own type. Only ever runs while checking syntax.
SP_DFSCAN:
  RST $18                 ; USR first? (GET_CHAR: DEF_FN has put FLAGS in A.)
  CP $C0                  ;
  PUSH AF                 ;
  CALL SCANNING           ;
  POP AF                  ;
  RET NZ                  ;
  POP HL                  ; The way back into DEF_FN, and FLAGS as it was
  POP DE                  ; for the FN's name (in D).
  PUSH DE                 ;
  PUSH HL                 ;
  LD A,D                  ; FLAGS bit 6 becomes the name's.
  AND $40                 ;
  LD D,A                  ;
  LD A,(FLAGS)            ;
  AND $BF                 ;
  OR D                    ;
  LD (FLAGS),A            ;
  RET                     ;

;; replace CALL SCANNING ; Now consider the definition as an expression.
  CALL SP_DFSCAN          ; Now consider the definition (the spine's: a
                          ; string FN may be USR).
;; end patch
