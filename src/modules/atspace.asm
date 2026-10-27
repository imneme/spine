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
;; needs CLS CL_ALL AUTO_LIST CLEAR RUN
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

SP_PRINT_OUT:
  CP $AC                  ; AT?
  JP NZ,PRINT_OUT         ;
  BIT 0,(IY+$01)          ; Straight after a space (or at a line's start):
  JP NZ,PRINT_OUT         ; none needed.
  PUSH AF                 ; A space first, through the same channel.
  LD A," "                ;
  CALL PRINT_OUT          ;
  POP AF                  ;
  JP PRINT_OUT            ;
