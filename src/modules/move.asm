; MOVE x,y: the PLOT position, no dot. A SPINE module: build_spine.py ... --module src/modules/move.asm. See src/modules/README.md.

P_X_MOVE:
  DEFB $08                ; CLASS_08: MOVE x,y
  DEFB $00                ;
  DEFW SP_MOVE            ;
;; code
; THE 'MOVE' COMMAND: MOVE x,y. Where the next DRAW starts (the PLOT position), without plotting anything. The
; Spectrum's DRAW is relative to it, and until now only PLOT (or a DRAW) could set it.
SP_MOVE:
  CALL STK_TO_BC          ; B = y, C = x; D and E their signs (+01 or +FF).
  LD A,D                  ; Neither may be negative: report B.
  OR E                    ;
  INC A                   ;
  JP Z,REPORT_B           ;
  LD A,$AF                ; Nor y above 175.
  CP B                    ;
  JP C,REPORT_B           ;
  LD (COORDS),BC          ; COORDS: x, then y.
  RET                     ;
