; Built-in functions: FN high(n), FN low(n) and FN x$(n). A SPINE module (needs expr): build_spine.py ... --module
; src/modules/builtins.asm. See src/modules/README.md.
;
; With SCANNING the spine's own (the expr module), so is FN: when no DEF FN is found for a name, instead of
; report P the spine looks in its own table. A program's own DEF FN of the same name is found first, and wins.
; An FN's name may be longer than one letter: a letter, then letters and digits, spaces ignored, as for LET.
;   FN high(n)  the high byte of n (0 to 65535): FN high(48879) is 190
;   FN low(n)   its low byte: FN low(48879) is 239
;   FN x$(n)    n in hexadecimal, no leading zeros: FN x$(48879) is "BEEF"
; (FN m(a,b), a MOD b, has retired: a % b does it.)
;; replace RST $20 ; Get the next character. @ S_FN_SBRN
  CALL SP_FNNAME          ; (the spine's: past the whole name, which may be
                          ; longer than a letter)
;; end patch
;; replace RST $20 ; Get the next character. @ SF_RUN
  CALL SP_FNNAME          ; (the spine's: past the whole name, noting where
                          ; it starts)
;; end patch
;; replace CALL FN_SKPOVR ; Get the next character in the DEF FN. @ SF_CP_DEF
  CALL SP_DFNAME          ; (the spine's: the rest of the name must match
                          ; too)
;; end patch
;; replace RST $08 ; Call the error handling routine. @ SF_FND_DF
  JP SP_BUILTIN           ; (the spine's: no DEF FN, so perhaps one of its
                          ; own; else report P after all)
;; end patch

; SP_FNNAME: from S_FN_SBRN, with CH_ADD on the name's first letter. On past the letters and digits that follow;
; returns the character after them ('$' or '(' in a good FN). SP_FNPTR keeps where the name starts.
SP_FNNAME:
  LD HL,(CH_ADD)          ;
  LD (SP_FNPTR),HL        ;
FNN_LOOP:
  RST $20                 ;
  CALL ALPHANUM           ;
  JR C,FNN_LOOP           ;
  RET                     ;
SP_FNPTR:
  DEFW 0                  ; The FN's name, during the search for its DEF FN.

; SP_DFNAME: from SF_CP_DEF, the first letters matching; HL on the DEF FN's first letter. The rest must match as
; well (either case): FN a must not find DEF FN ab, nor the other way round. Returns as FN_SKPOVR would, with the
; character after the DEF FN's name, or with 0 (no match: not '$' or '(').
SP_DFNAME:
  PUSH BC                 ; (The FN's first letter and string status.)
  LD DE,(SP_FNPTR)        ; DE along the FN's name, HL along the DEF FN's.
DN_LOOP:
  CALL FN_SKPOVR          ; The DEF FN's next, in B;
  LD B,A                  ;
  EX DE,HL                ;
  CALL FN_SKPOVR          ; the FN's, in A.
  EX DE,HL                ;
  CALL ALPHANUM           ; The FN's name goes on: so must the DEF FN's, the
  JR NC,DN_END            ; same letter or digit.
  XOR B                   ;
  AND $DF                 ;
  JR Z,DN_LOOP            ;
DN_DIFF:
  LD B,0                  ;
DN_END:
  LD A,B                  ; The FN's name has ended: so must the DEF FN's.
  CALL ALPHANUM           ;
  JR C,DN_DIFF            ;
  POP BC                  ;
  RET                     ;

; SP_BUILTIN: from S_FN_SBRN, no DEF FN found. CH_ADD is at the first argument; on the stack, S_FN_SBRN's pointer
; to it. The name, from SP_FNPTR, is looked for in BI_TABLE.
SP_BUILTIN:
  POP HL                  ; The first argument, back in CH_ADD (the search
  LD (CH_ADD),HL          ; for a DEF FN may have moved it, as EACH_STMT does).
  LD HL,BI_TABLE          ;
BI_ENTRY:
  LD A,(HL)               ; The end of the table: report P.
  AND A                   ;
  JR Z,BI_P               ;
  LD DE,(SP_FNPTR)        ; The FN's name, from its first letter.
  DEC DE                  ;
BI_CMP:
  EX DE,HL                ; Its next character, and the table's: the same
  CALL FN_SKPOVR          ; (either case)?
  EX DE,HL                ;
  XOR (HL)                ;
  AND $DF                 ;
  JR NZ,BI_NEXT           ;
  LD A,(HL)               ; Matched as far as the '(': this is it.
  INC HL                  ;
  CP "("                  ;
  JR NZ,BI_CMP            ;
  LD A,(HL)               ; Its routine.
  INC HL                  ;
  LD H,(HL)               ;
  LD L,A                  ;
  JP (HL)                 ;
BI_NEXT:
  LD A,(HL)               ; Not this one: on past its '(' and address.
  INC HL                  ;
  CP "("                  ;
  JR NZ,BI_NEXT           ;
  INC HL                  ;
  INC HL                  ;
  JR BI_ENTRY             ;
BI_P:
  RST $08                 ; Report P - FN without DEF, as before.
  DEFB $18                ;
; BI_TABLE: the spine's own FNs: each name, as far as its '(', then its routine. The routine starts with CH_ADD at
; the first argument, and ends with the result on the calculator stack and RST $18, JP S_CONT_2.
BI_TABLE:
  DEFM "high("            ;
  DEFW BI_HIGH            ;
  DEFM "low("             ;
  DEFW BI_LOW             ;
  DEFM "x$("              ;
  DEFW BI_HEX             ;
  DEFB 0                  ;
BI_HIGH:
  CALL BI_ONE             ; n)
  LD A,B                  ;
  JR BI_BYTE              ;
BI_LOW:
  CALL BI_ONE             ; n)
  LD A,C                  ;
BI_BYTE:
  CALL STACK_A            ;
  RST $18                 ;
  JP S_CONT_2             ;
BI_ONE:
  CALL BI_ARG             ; One argument, n): BC = n (report B if it isn't 0
  CALL BI_END             ; to 65535).
  JP FIND_INT2            ;
BI_HEX:
  CALL BI_ONE             ; n)
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
