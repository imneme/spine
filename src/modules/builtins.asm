; Built-in functions: FN m(a,b) and FN x$(n). A SPINE module (needs expr): build_spine.py ... --module
; src/modules/builtins.asm. See src/modules/README.md.
;
; With SCANNING the spine's own (the expr module), so is FN: when no DEF FN is found for a name, instead of
; report P the spine looks among its own. A program's own DEF FN of the same name is found first, and wins.
;   FN m(a,b)   a MOD b: a - b*INT (a/b), so FN m(-7,3) is 2
;   FN x$(n)    n (0 to 65535) in hexadecimal, no leading zeros: FN x$(48879) is "BEEF"
;; replace RST $08 ; Call the error handling routine. @ SF_FND_DF
  JP SP_BUILTIN           ; (the spine's: no DEF FN, so perhaps one of its
                          ; own; else report P after all)
;; end patch

; SP_BUILTIN: from S_FN_SBRN, no DEF FN found. B = the name (upper case), C = 0 for a string FN; CH_ADD is at the
; first argument; on the stack, S_FN_SBRN's pointer to it.
SP_BUILTIN:
  POP HL                  ; The first argument, back in CH_ADD (the search
  LD (CH_ADD),HL          ; for a DEF FN may have moved it, as EACH_STMT does).
  LD A,B                  ;
  INC C                   ; A string FN?
  DEC C                   ;
  JR Z,BI_STR             ;
  CP "M"                  ; FN m(a,b).
  JR Z,BI_MOD             ;
  JR BI_P                 ;
BI_STR:
  CP "X"                  ; FN x$(n).
  JR Z,BI_HEX             ;
BI_P:
  RST $08                 ; Report P - FN without DEF, as before.
  DEFB $18                ;
BI_MOD:
  CALL BI_ARG             ; a,
  CP ","                  ;
  JR NZ,BI_Q              ;
  RST $20                 ;
  CALL BI_ARG             ; b)
  CALL BI_END             ;
  RST $28                 ; a, b (the ROM's n-mod-m is for numbers of 0 and
  DEFB $C1                ; st_mem_1: (b in mem 1)     up; this is for all;
  DEFB $02                ; delete: a
  DEFB $31                ; duplicate: a, a
  DEFB $E1                ; get_mem_1: a, a, b       mem 1, as int uses mem 0)
  DEFB $05                ; division: a, a/b
  DEFB $27                ; int: a, INT (a/b)
  DEFB $E1                ; get_mem_1: a, INT (a/b), b
  DEFB $04                ; multiply: a, b*INT (a/b)
  DEFB $03                ; subtract: a - b*INT (a/b)
  DEFB $38                ; end_calc
  RST $18                 ; On with the expression, from the character after
  JP S_CONT_2             ; the ')'.
BI_HEX:
  CALL BI_ARG             ; n)
  CALL BI_END             ;
  CALL FIND_INT2          ; BC = n (report B if it isn't 0 to 65535).
  PUSH BC                 ;
  LD BC,4                 ; Room for four digits in the workspace.
  RST $30                 ;
  POP BC                  ;
  PUSH DE                 ;
  LD L,0                  ; L: digits so far.
  LD A,B                  ; Each nibble, high first; leading zeros left out.
  CALL BI_HI              ;
  LD A,B                  ;
  CALL BI_LO              ;
  LD A,C                  ;
  CALL BI_HI              ;
  LD A,C                  ;
  CALL BI_LO              ;
  LD A,L                  ; None at all: n was 0.
  AND A                   ;
  LD A,"0"                ;
  CALL Z,BI_PUT           ;
  POP DE                  ; The string: its start, and L long.
  LD B,0                  ;
  LD C,L                  ;
  CALL STK_ST_0           ; (A string result: FLAGS says so.)
  RST $18                 ;
  JP S_CONT_2             ;
BI_HI:
  RRCA                    ; The high nibble, then as BI_LO.
  RRCA                    ;
  RRCA                    ;
  RRCA                    ;
BI_LO:
  AND $0F                 ; A leading zero: left out.
  JR NZ,BI_DIG            ;
  INC L                   ;
  DEC L                   ;
  RET Z                   ;
BI_DIG:
  ADD A,"0"               ; 0-9, A-F.
  CP "9"+1                ;
  JR C,BI_PUT             ;
  ADD A,7                 ;
BI_PUT:
  LD (DE),A               ;
  INC DE                  ;
  INC L                   ;
  RET                     ;
BI_ARG:
  CALL SCANNING           ; An argument: it must be a number (report A).
  BIT 6,(IY+$01)          ;
  JR Z,BI_A               ;
  RST $18                 ; Returns the character after it.
  RET                     ;
BI_END:
  CP ")"                  ; The last: a ')' must follow (report Q), and is
  JR NZ,BI_Q              ; stepped over.
  RST $20                 ;
  RET                     ;
BI_A:
  RST $08                 ; Report A - Invalid argument.
  DEFB $09                ;
BI_Q:
  RST $08                 ; Report Q - Parameter error.
  DEFB $19                ;
