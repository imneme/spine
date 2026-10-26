; FORMAT [start,step]: renumber, GO TOs too. A SPINE module: build_spine.py ... --module src/modules/format.asm. See src/modules/README.md.

P_X_FORMAT:
  DEFB $05                ; CLASS_05: FORMAT checks its own syntax (two numbers, or none)
  DEFW SP_FORMAT          ;
;; code
;; report T Line number too big

; THE 'FORMAT' COMMAND: FORMAT, or FORMAT start,step. Renumbers the program (10, 20, 30... by default), and with
; it every GO TO, GO SUB, RUN, RESTORE, LIST, LLIST and LINE followed by a plain number: GO TO 10*a can't be known,
; so it's left as it is. A number with no line of its own (GO TO 15 when there are 10 and 20) becomes the new
; number of the line it would have reached (20's), so the program does what it did. Report T if the last line
; would be past 9999; nothing is changed then.
SP_FORMAT:
  RST $18                 ; Nothing after FORMAT: 10,10.
  CP $0D                  ;
  JR Z,FM_DEF             ;
  CP ":"                  ;
  JR Z,FM_DEF             ;
  CALL CLASS_08           ; Two numbers.
  CALL CHECK_END          ; (Syntax checking stops here.)
  CALL FIND_INT2          ; The step.
  PUSH BC                 ;
  CALL FIND_INT2          ; The start.
  POP DE                  ;
  JR FM_GO                ;
FM_DEF:
  CALL CHECK_END          ;
  LD BC,10                ;
  LD DE,10                ;
FM_GO:
  LD A,D                  ; A step of 0: report B.
  OR E                    ;
  JP Z,REPORT_B           ;
  LD (FM_START),BC        ;
  LD (FM_STEP),DE         ;
  LD HL,(PROG)            ; Will the last line fit? Count them up.
  LD B,H                  ; (BC, the new number, in DE.)
  LD C,L                  ;
  LD DE,(FM_START)        ;
FM_CHK:
  CALL FM_ENDBC           ; Past the last line: they fit.
  JR NC,FM_REFS           ;
  LD HL,$270F             ; This one's new number must be 9999 at most.
  AND A                   ;
  SBC HL,DE               ;
  JR C,FM_BIG             ;
  LD H,B                  ; On to the next line, and the next number.
  LD L,C                  ;
  CALL FM_NXT             ;
  LD B,H                  ;
  LD C,L                  ;
  LD HL,(FM_STEP)         ;
  ADD HL,DE               ;
  EX DE,HL                ;
  JR NC,FM_CHK            ;
  CALL FM_ENDBC           ; (It ran past 65535: fine only if that was the
  JR NC,FM_REFS           ; last line.)
FM_BIG:
  RST $08                 ; Report T.
  DEFB $1C                ;
; Every reference first, while the lines have their old numbers.
FM_REFS:
  LD HL,(PROG)            ;
FM_R1:
  LD B,H                  ;
  LD C,L                  ;
  CALL FM_ENDBC           ; Past the last line: now the numbers.
  JR NC,FM_NUMS           ;
  LD (FM_LINE),HL         ; This line (its length may change).
  INC HL                  ; Its text.
  INC HL                  ;
  INC HL                  ;
  INC HL                  ;
FM_R2:
  LD A,(HL)               ;
  CP $0D                  ; The line's end.
  JR Z,FM_R9              ;
  CP $EA                  ; REM: the rest is the line's own.
  JR Z,FM_R9              ;
  CP $0E                  ; A number's hidden form: past it.
  JR Z,FM_R_NUM           ;
  CP $22                  ; A string: past it.
  JR Z,FM_R_STR           ;
  INC HL                  ;
  CALL FM_ISREF           ; One of the seven? Then the number after it.
  JR NZ,FM_R2             ;
  CALL FM_FIX             ;
  JR FM_R2                ;
FM_R_NUM:
  LD BC,6                 ;
  ADD HL,BC               ;
  JR FM_R2                ;
FM_R_STR:
  INC HL                  ;
  LD A,(HL)               ;
  CP $0D                  ;
  JR Z,FM_R9              ;
  CP $22                  ;
  JR NZ,FM_R_STR          ;
  INC HL                  ;
  JR FM_R2                ;
FM_R9:
  LD HL,(FM_LINE)         ; The next line.
  CALL FM_NXT             ;
  JR FM_R1                ;
; Then the line numbers themselves (and the editor's current line, E_PPC).
FM_NUMS:
  LD HL,(E_PPC)           ;
  CALL FM_NEW             ;
  LD (E_PPC),HL           ;
  LD HL,(PROG)            ;
  LD DE,(FM_START)        ;
FM_N_1:
  LD B,H                  ;
  LD C,L                  ;
  CALL FM_ENDBC           ;
  RET NC                  ; All done.
  LD (HL),D               ; The number, high byte first.
  INC HL                  ;
  LD (HL),E               ;
  DEC HL                  ;
  CALL FM_NXT             ;
  PUSH HL                 ;
  LD HL,(FM_STEP)         ;
  ADD HL,DE               ;
  EX DE,HL                ;
  POP HL                  ;
  JR FM_N_1               ;

; FM_FIX: HL is just after one of the seven keywords. If a plain number follows (and then ':' or the line's end),
; it's given its new value: the digits are rewritten (the line grows or shrinks to fit) and the hidden form too.
; Returns HL past whatever it looked at.
FM_FIX:
  LD A,(HL)               ; Spaces are allowed.
  CP " "                  ;
  JR NZ,FM_F1             ;
  INC HL                  ;
  JR FM_FIX               ;
FM_F1:
  CP "0"                  ; A digit?
  RET C                   ;
  CP "9"+1                ;
  RET NC                  ;
  LD (FM_DIG),HL          ; Where the digits start.
FM_F2:
  INC HL                  ; Where they end: the hidden form's 0E.
  LD A,(HL)               ;
  CP $0E                  ;
  JR NZ,FM_F2             ;
  LD (FM_HID),HL          ;
  LD BC,6                 ; What follows the number must end the statement.
  ADD HL,BC               ;
  LD A,(HL)               ;
  LD HL,(FM_HID)          ;
  CP $0D                  ;
  JR Z,FM_F3              ;
  CP ":"                  ;
  JR Z,FM_F3              ;
FM_FH:
  LD HL,(FM_HID)          ; Left alone: back to the 0E, so the scan steps
  RET                     ; over the hidden form.
FM_F3:
  INC HL                  ; A small whole number: 00, 00 (positive), lo,
  LD A,(HL)               ; hi, 00.
  INC HL                  ;
  OR (HL)                 ;
  JR NZ,FM_FH             ;
  INC HL                  ;
  LD E,(HL)               ;
  INC HL                  ;
  LD D,(HL)               ;
  EX DE,HL                ;
  CALL FM_NEW             ; HL = the new number.
  LD (FM_NUM),HL          ;
  CALL FM_DIGITS          ; FM_BUF = its digits; A = how many.
  LD C,A                  ; New count less old count (1 to 5 each).
  LD HL,(FM_HID)          ;
  LD DE,(FM_DIG)          ;
  AND A                   ;
  SBC HL,DE               ;
  SUB L                   ;
  JR Z,FM_F6              ;
  PUSH BC                 ;
  JR C,FM_F5              ;
  LD C,A                  ; More digits: make room at the first digit.
  LD B,0                  ;
  PUSH BC                 ;
  EX DE,HL                ;
  CALL MAKE_ROOM          ;
  POP BC                  ;
  JR FM_F5A               ;
FM_F5:
  NEG                     ; Fewer: reclaim from the first digit.
  LD C,A                  ;
  LD B,0                  ;
  PUSH BC                 ;
  EX DE,HL                ;
  CALL RECLAIM_2          ;
  POP BC                  ;
  LD A,C                  ; (The line's length goes down by C.)
  NEG                     ;
  LD C,A                  ;
  LD B,$FF                ;
FM_F5A:
  LD HL,(FM_LINE)         ; The line's length, plus or minus.
  INC HL                  ;
  INC HL                  ;
  LD E,(HL)               ;
  INC HL                  ;
  LD D,(HL)               ;
  EX DE,HL                ;
  ADD HL,BC               ;
  EX DE,HL                ;
  LD (HL),D               ;
  DEC HL                  ;
  LD (HL),E               ;
  POP BC                  ;
FM_F6:
  LD HL,FM_BUF            ; The new digits.
  LD DE,(FM_DIG)          ;
  LD B,0                  ;
  LDIR                    ;
  EX DE,HL                ; Then the hidden form: 0E, 00, 00, lo, hi, 00.
  LD (HL),$0E             ;
  INC HL                  ;
  LD (HL),B               ;
  INC HL                  ;
  LD (HL),B               ;
  INC HL                  ;
  LD DE,(FM_NUM)          ;
  LD (HL),E               ;
  INC HL                  ;
  LD (HL),D               ;
  INC HL                  ;
  LD (HL),B               ;
  INC HL                  ;
  RET                     ;

; FM_NEW: HL = an old line number. Returns HL = the new number of that line, or of the first line after it (GO TO
; goes to the first line at or after its number), or one step past the last line if there is none.
FM_NEW:
  EX DE,HL                ; DE = the old number.
  LD HL,(PROG)            ;
  LD BC,(FM_START)        ; BC = the new number of the line at HL.
FM_W1:
  PUSH BC                 ;
  LD B,H                  ;
  LD C,L                  ;
  CALL FM_ENDBC           ;
  POP BC                  ;
  JR NC,FM_W2             ;
  LD A,(HL)               ; This line's number against DE: at or after it,
  CP D                    ; and this is the one.
  JR NZ,FM_W3             ;
  INC HL                  ;
  LD A,(HL)               ;
  DEC HL                  ;
  CP E                    ;
FM_W3:
  JR NC,FM_W2             ;
  CALL FM_NXT             ;
  PUSH HL                 ;
  LD HL,(FM_STEP)         ;
  ADD HL,BC               ;
  LD B,H                  ;
  LD C,L                  ;
  POP HL                  ;
  JR FM_W1                ;
FM_W2:
  LD H,B                  ;
  LD L,C                  ;
  RET                     ;

; FM_NXT: HL = a line; returns HL = the next (its number 2 bytes, its length 2, then the text). Keeps BC and DE.
FM_NXT:
  INC HL                  ;
  INC HL                  ;
  LD A,(HL)               ;
  INC HL                  ;
  PUSH DE                 ;
  LD D,(HL)               ;
  LD E,A                  ;
  INC HL                  ;
  ADD HL,DE               ;
  POP DE                  ;
  RET                     ;

; FM_ENDBC: BC = an address in the program. Carry set if it's before VARS (a line), reset if at the end. Keeps all
; but A and F.
FM_ENDBC:
  PUSH HL                 ;
  LD HL,(VARS)            ;
  SCF                     ;
  SBC HL,BC               ; VARS - 1 - BC: no carry while BC < VARS.
  CCF                     ;
  POP HL                  ;
  RET                     ;

; FM_ISREF: Z if A is GO TO, GO SUB, RUN, RESTORE, LIST, LLIST or LINE. Keeps everything else.
FM_ISREF:
  PUSH HL                 ;
  PUSH BC                 ;
  LD HL,FM_TOKS           ;
  LD BC,7                 ;
  CPIR                    ;
  POP BC                  ;
  POP HL                  ;
  RET                     ;
FM_TOKS:
  DEFB $EC,$ED,$F7,$E5,$F0,$E1,$CA

; FM_DIGITS: HL (0 to 65535) to FM_BUF as decimal digits, no leading zeros. Returns A = how many.
FM_DIGITS:
  LD DE,FM_BUF            ;
  LD BC,10000             ;
  CALL FM_D1              ;
  LD BC,1000              ;
  CALL FM_D1              ;
  LD BC,100               ;
  CALL FM_D1              ;
  LD BC,10                ;
  CALL FM_D1              ;
  LD A,L                  ; The units, always.
  ADD A,"0"               ;
  LD (DE),A               ;
  INC DE                  ;
  EX DE,HL                ;
  LD DE,FM_BUF            ;
  AND A                   ;
  SBC HL,DE               ;
  LD A,L                  ;
  RET                     ;
FM_D1:
  LD A,"0"-1              ; How many BCs in HL?
FM_D2:
  INC A                   ;
  AND A                   ;
  SBC HL,BC               ;
  JR NC,FM_D2             ;
  ADD HL,BC               ;
  CP "0"                  ; A leading zero is left out.
  JR NZ,FM_D3             ;
  PUSH HL                 ;
  LD HL,FM_BUF            ;
  AND A                   ;
  SBC HL,DE               ;
  POP HL                  ;
  RET Z                   ;
FM_D3:
  LD (DE),A               ;
  INC DE                  ;
  RET                     ;

FM_START:
  DEFW 10                 ; The first new number,
FM_STEP:
  DEFW 10                 ; and the step.
FM_LINE:
  DEFW 0                  ; The line being looked at.
FM_DIG:
  DEFW 0                  ; Its digits, and their hidden form.
FM_HID:
  DEFW 0                  ;
FM_NUM:
  DEFW 0                  ; The new number,
FM_BUF:
  DEFS 5                  ; and its digits.
