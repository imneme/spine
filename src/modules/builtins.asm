; Built-in functions, and DEF FN ... AT for new ones in machine code. A SPINE module (needs expr):
; build_spine.py ... --module src/modules/builtins.asm. See src/modules/README.md.
;
; With SCANNING the spine's own (the expr module), so is FN. An FN's name may be longer than one letter: a letter,
; then letters and digits, spaces ignored, as for LET (DEF FN area(w,h)=w*h). A DEF FN may give, instead of
; '=' and an expression, AT and an address: DEF FN squeal(k,t) AT 56789. Its FN calls the machine code there with
; the arguments (checked against the parameters: as many, numbers for numbers, strings for strings, else report
; Q) on the calculator stack, the first deepest; the code leaves one result there in their place (a string for a
; name ending '$') and returns. As with USR, it must keep IY and HL'.
; When no DEF FN is found for a name, instead of report P the spine looks in its own table, BI_TABLE, whose
; entries are such declarations too. A program's own DEF FN of the same name is found first, and wins.
;   FN high(n)  the high byte of n (0 to 65535): FN high(48879) is 190
;   FN low(n)   its low byte: FN low(48879) is 239
;   FN x$(n)    n in hexadecimal, no leading zeros: FN x$(48879) is "BEEF"
; (FN m(a,b), a MOD b, has retired: a % b does it.)
;; needs DEF_FN
;; replace RST $20 ; Fetch the next character. @ DEF_FN_1
  CALL SP_FNNAME          ; (the spine's: past the whole name, which may be
                          ; longer than a letter)
;; end patch
;; replace CP "=" ; It must be an '='. @ DEF_FN_6
  CP $AC                  ; (the spine's: or AT, and an address)
  JP Z,SP_DFAT_SYN        ;
  CP "="                  ; It must be an '='.
;; end patch
;; replace AND A ; If HL is now pointing to a '$', move on to the '('. @ SF_VALUES
  CALL SP_DFAT            ; (the spine's: a DEF FN ... AT goes its own way)
  AND A                   ; If HL is now pointing to a '$', move on to the '('.
;; end patch
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

; SP_BUILTIN: from S_FN_SBRN, no DEF FN found. B = the name's first letter and C = 0 for a string FN; CH_ADD is
; at the first argument; on the stack, S_FN_SBRN's pointer to it. The name, from SP_FNPTR, is looked for in
; BI_TABLE.
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
  CP "("                  ;
  INC HL                  ;
  JR NZ,BI_CMP            ;
  DEC HL                  ;
  LD B,0                  ; (B = 0: from the table)
  JR SP_ATFN              ;
BI_NEXT:
  LD A,(HL)               ; Not this one: on past its ')' and address.
  INC HL                  ;
  CP ")"                  ;
  JR NZ,BI_NEXT           ;
  INC HL                  ;
  INC HL                  ;
  JR BI_ENTRY             ;
BI_P:
  RST $08                 ; Report P - FN without DEF, as before.
  DEFB $18                ;

; SP_DFAT_SYN: from DEF_FN, checking syntax, at the AT that takes the place of '=': a number, the address, must
; follow, and end the statement.
SP_DFAT_SYN:
  RST $20                 ;
  CALL CLASS_06           ; (EXPT_1NUM: a number.)
  CALL CHECK_END          ;

; SP_DFAT: from SF_VALUES, with the DEF FN found; HL on its '$' or '('. Unless its ')' is followed by AT, back
; to the ROM's way; else S_FN_SBRN's pointers come off the stack and SP_ATFN calls the code.
SP_DFAT:
  PUSH HL                 ;
  PUSH AF                 ;
DA_LOOP:
  CALL AA_NEXT            ; As far as the ')',
  CP ")"                  ;
  JR NZ,DA_LOOP           ;
  CALL AA_NEXT            ; and what follows it.
  CP $AC                  ;
  JR Z,DA_AT              ;
  POP AF                  ;
  POP HL                  ;
  RET                     ;
DA_AT:
  POP AF                  ;
  POP HL                  ;
  POP DE                  ; (This return address,
  POP DE                  ; the pointer to the DEF FN,
  POP DE                  ; and to the FN's first argument: into CH_ADD.)
  LD (CH_ADD),DE          ;
  AND A                   ; A '$': on to the '('.
  CALL Z,FN_SKPOVR        ;

; SP_ATFN: HL on the '(' of a declaration, a DEF FN ... AT (B not 0) or a BI_TABLE entry (B = 0), C = 0 for a
; string FN, and CH_ADD on the FN's first argument. The arguments go onto the calculator stack, and the code
; at the address is called; it leaves the result there.
SP_ATFN:
  PUSH BC                 ;
  CALL SP_ATARGS          ; HL is left on the declaration's ')'.
  POP BC                  ;
  PUSH BC                 ;
  INC B                   ; From the table: the address follows the ')'.
  DEC B                   ;
  JR NZ,AF_PROG           ;
  INC HL                  ;
  LD C,(HL)               ;
  INC HL                  ;
  LD B,(HL)               ;
  JR AF_CALL              ;
AF_PROG:
  CALL FN_SKPOVR          ; From a DEF FN: past the AT, the address is
  LD DE,(CH_ADD)          ; evaluated there, the FN's place kept meanwhile.
  PUSH DE                 ;
  LD (CH_ADD),HL          ;
  RST $20                 ;
  CALL CLASS_06           ; (EXPT_1NUM: a number.)
  CALL FIND_INT2          ;
  POP HL                  ;
  LD (CH_ADD),HL          ;
AF_CALL:
  LD HL,(CH_ADD)          ; (CH_ADD kept for the code.)
  PUSH HL                 ;
  CALL SP_JPBC            ; The code.
  POP HL                  ;
  LD (CH_ADD),HL          ;
  POP BC                  ; The result: a number, unless the name ends '$'.
  LD HL,FLAGS             ;
  RES 6,(HL)              ;
  INC C                   ;
  DEC C                   ;
  JR Z,AF_STR             ;
  SET 6,(HL)              ;
AF_STR:
  RST $20                 ; Past the FN's ')'.
  JP S_CONT_2             ;
SP_JPBC:
  PUSH BC                 ;
  RET                     ;

; SP_ATARGS: the FN's arguments (CH_ADD on the first), each checked against a parameter of the declaration (HL on
; its '('): as many, numbers for numbers, strings for strings, else report Q. They are left on the calculator
; stack, the first deepest; HL is left on the declaration's ')', CH_ADD on the FN's.
SP_ATARGS:
  CALL AA_NEXT            ; The first parameter, or ')': none.
  CP ")"                  ;
  JR NZ,AA_PARAM          ;
  EX DE,HL                ; Then the FN must have none either.
  RST $18                 ;
  EX DE,HL                ;
  CP ")"                  ;
  RET Z                   ;
AA_Q:
  RST $08                 ; Report Q - Parameter error.
  DEFB $19                ;
AA_PARAM:
  CALL AA_NEXT            ; After the parameter's letter, a '$' for a string,
  CP "$"                  ;
  PUSH AF                 ;
  CALL Z,AA_NEXT          ; then a ',' or ')'.
  PUSH HL                 ;
  CALL SCANNING           ; The FN's argument, onto the calculator stack.
  POP DE                  ; (The declaration in DE: RST $18 and $20 use HL.)
  POP AF                  ; Of the parameter's kind?
  JR Z,AA_STR             ;
  BIT 6,(IY+$01)          ;
  JR Z,AA_Q               ;
  JR AA_SEP               ;
AA_STR:
  BIT 6,(IY+$01)          ;
  JR NZ,AA_Q              ;
AA_SEP:
  RST $18                 ; The FN's ',' or ')' and the declaration's must
  EX DE,HL                ; be the same.
  CP (HL)                 ;
  JR NZ,AA_Q              ;
  CP ")"                  ;
  RET Z                   ;
  EX DE,HL                ; A ',': on to the next of each.
  RST $20                 ;
  EX DE,HL                ;
  CALL AA_NEXT            ;
  JR AA_PARAM             ;
AA_NEXT:
  INC HL                  ; The declaration's next character, past spaces and
  LD A,(HL)               ; the hidden numbers a DEF FN keeps its parameters'
  CP $0E                  ; values in.
  JR Z,AA_NUM             ;
  CP $21                  ;
  JR C,AA_NEXT            ;
  RET                     ;
AA_NUM:
  INC HL                  ;
  INC HL                  ;
  INC HL                  ;
  INC HL                  ;
  INC HL                  ;
  JR AA_NEXT              ;

; BI_TABLE: the spine's own FNs, each a declaration as a DEF FN ... AT gives it (as far as its ')'), then the
; code's address. The code follows SP_ATFN's way: the arguments on the calculator stack, the result left there.
BI_TABLE:
  DEFM "high(n)"          ;
  DEFW BI_HIGH            ;
  DEFM "low(n)"           ;
  DEFW BI_LOW             ;
  DEFM "x$(n)"            ;
  DEFW BI_HEX             ;
  DEFB 0                  ;
BI_HIGH:
  CALL FIND_INT2          ; n, 0 to 65535 (else report B): its high byte.
  LD A,B                  ;
  JP STACK_A              ;
BI_LOW:
  CALL FIND_INT2          ; Its low byte.
  LD A,C                  ;
  JP STACK_A              ;
BI_HEX:
  CALL FIND_INT2          ; n, 0 to 65535 (else report B).
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
  JP STK_ST_0             ;
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
