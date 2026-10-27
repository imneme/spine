; AT with a leading space, as STEP has: "1 AT 8", not "1AT 8". A SPINE module: build_spine.py ... --module
; src/modules/atspace.asm. See src/modules/README.md.
;
; Melissa: "make AT print with a leading space like STEP... You can of course type a space... like an *animal*."
; The ROM's token printer gives a leading space only to tokens from the 32nd on (OR, STEP...); AT, the 8th, is a
; function, as it only ever came after PRINT or ';' before the operators module gave it a second job. Printing goes
; out through each channel's output routine, which NEW copies from CHANINFO, and which CL_CHAN (the ROM's "house
; keeping", in every CLS) and CL_ALL put back to PRINT_OUT. So the spine owns CL_CHAN and every way into it (closure.py
; --target=0D94-0DAF: CLS, CL_ALL, AUTO_LIST, CLEAR, RUN, 282 bytes), and both it and CHANINFO name SP_PRINT_OUT,
; which puts the space in first, by STEP's rule (FLAGS bit 0: not straight after a space), then hands everything
; to the ROM's PRINT_OUT.
;; needs CLS CL_ALL AUTO_LIST CLEAR RUN PO_TV_2
;; data CHANINFO
;; replace DEFW PRINT_OUT ; Keyboard. @ CHANINFO
  DEFW SP_PRINT_OUT       ; Keyboard (the spine's: AT gets its space).
;; end patch
;; replace DEFW PRINT_OUT ; Screen. @ CHANINFO
  DEFW SP_PRINT_OUT       ; Screen (likewise).
;; end patch
;; replace DEFW PRINT_OUT ; Printer. @ CHANINFO
  DEFW SP_PRINT_OUT       ; Printer (likewise).
;; end patch
;; replace LD DE,PRINT_OUT ; (CURCHL)) is PRINT_OUT. @ CL_ALL
  LD DE,SP_PRINT_OUT      ; (CURCHL)) is the spine's.
;; end patch
;; replace LD DE,PRINT_OUT ; and make the output address PRINT_OUT and the input @ CL_CHAN
  LD DE,SP_PRINT_OUT      ; and make the output address (the spine's) and the
                          ; input
;; end patch

;; replace LD DE,PRINT_OUT ; Restore the original address for PRINT_OUT. @ PO_CONT
  LD DE,SP_PRINT_OUT      ; Restore the spine's, not the ROM's PRINT_OUT.
;; end patch

; SP_PRINT_OUT: the channels' output. A control code with operands (INK to OVER 10h-15h, AT and TAB 16h-17h) goes
; to the spine's own PO_1_OPER and PO_2_OPER: they point the channel at PO_CONT to collect the operands, and the
; spine's PO_CONT puts SP_PRINT_OUT back afterwards, where the ROM's put its own PRINT_OUT back (found single-
; stepping channel K: the boot line's INK 3, for the heart, was undoing it at every cold start).
SP_PRINT_OUT:
  CP $AC                  ; AT?
  JR Z,SPO_AT             ;
  CP $10                  ; Codes with operands: to the spine's own.
  JP C,PRINT_OUT          ;
  CP $16                  ;
  JP C,PO_1_OPER          ;
  CP $18                  ;
  JP C,PO_2_OPER          ;
  JP PRINT_OUT            ;
SPO_AT:
  BIT 0,(IY+$01)          ; Straight after a space (or at a line's start):
  JP NZ,PRINT_OUT         ; none needed.
  PUSH AF                 ; A space first, through the same channel.
  LD A," "                ;
  CALL PRINT_OUT          ;
  POP AF                  ;
  JP PRINT_OUT            ;
