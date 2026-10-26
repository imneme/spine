; CAT: the variables, by name. A SPINE module: build_spine.py ... --module src/modules/cat.asm. See src/modules/README.md.

P_X_CAT:
  DEFB $00                ; CLASS_00: CAT, nothing after it
  DEFW SP_CAT             ;
;; code
; THE 'CAT' COMMAND: CAT. A catalogue of the variables, by name: a number, a$ a string, a() an array, a$() an
; array of strings. (The microdrives' CAT listed files; this machine's only files are its variables.)
SP_CAT:
  LD A,$02                ; The upper screen.
  CALL CHAN_OPEN          ;
  LD HL,(VARS)            ;
CT_NEXT:
  LD A,(HL)               ; The end-marker?
  CP $80                  ;
  JR Z,CT_END             ;
  PUSH HL                 ;
  LD C,A                  ; C: the kind, in bits 5 to 7.
  AND $1F                 ; The first letter.
  ADD A,$60               ;
  CALL CT_PR              ;
  LD A,C                  ; A long name (101): the rest of it, up to the
  AND $E0                 ; letter with bit 7 set.
  CP $A0                  ;
  JR NZ,CT_KIND           ;
CT_LONG:
  INC HL                  ;
  LD A,(HL)               ;
  PUSH AF                 ;
  AND $7F                 ;
  CALL CT_PR              ;
  POP AF                  ;
  BIT 7,A                 ;
  JR Z,CT_LONG            ;
CT_KIND:
  LD A,C                  ; Strings (010) and string arrays (110) get '$';
  AND $E0                 ;
  CP $40                  ;
  JR Z,CT_DOL             ;
  CP $C0                  ;
  JR NZ,CT_ARR            ;
CT_DOL:
  LD A,"$"                ;
  CALL CT_PR              ;
CT_ARR:
  LD A,C                  ; arrays (100, 110) get '()'.
  AND $A0                 ;
  CP $80                  ;
  JR NZ,CT_SP             ;
  LD A,"("                ;
  CALL CT_PR              ;
  LD A,")"                ;
  CALL CT_PR              ;
CT_SP:
  LD A," "                ;
  CALL CT_PR              ;
  POP HL                  ; On to the next variable.
  CALL NEXT_ONE           ;
  EX DE,HL                ;
  JR CT_NEXT              ;
CT_END:
  LD A,$0D                ; And a new line to finish.
CT_PR:
  PUSH HL                 ; Print A, keeping HL and BC.
  PUSH BC                 ;
  RST $10                 ;
  POP BC                  ;
  POP HL                  ;
  RET                     ;
