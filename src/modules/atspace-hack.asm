; AT with a leading space, the cheap way: "hack it back". A SPINE module (an alternative to atspace):
; build_spine.py ... --module src/modules/atspace-hack.asm. See src/modules/README.md.
;
; Melissa: "Hack it back should be super easy, but has to just make sure we only hack if it's showing the ROM
; address." The ROM's CL_CHAN (in every CLS) and CL_ALL put the screen channels' output back to PRINT_OUT; this
; owns neither, and puts SP_PRINT_OUT back at the start of LIST, PRINT and the editor (MAIN_2), in each channel
; that holds the ROM's own PRINT_OUT, and only there: anything else was put there on purpose. It misses what
; happens between a clear and its next hook: the listing the editor shows after a line goes in (AUTO_LIST clears,
; then lists) still says 1AT 8.
;; patch MAIN_2
  CALL SP_HACKBACK        ; (the spine's: AT's space back in the channels)
;; end patch
;; patch LIST
  CALL SP_HACKBACK        ; (the spine's: likewise)
;; end patch
;; patch PRINT_1
  CALL SP_HACKBACK        ; (the spine's: likewise)
;; end patch

SP_HACKBACK:
  PUSH AF                 ; (Everything kept: PRINT_1 is entered with A set.)
  PUSH BC                 ;
  PUSH DE                 ;
  PUSH HL                 ;
  LD HL,(CHANS)           ; The four channels, five bytes each, output
  LD B,4                  ; address first.
HB_1:
  LD E,(HL)               ;
  INC HL                  ;
  LD D,(HL)               ;
  PUSH HL                 ; The ROM's own PRINT_OUT?
  LD HL,PRINT_OUT         ;
  AND A                   ;
  SBC HL,DE               ;
  POP HL                  ;
  JR NZ,HB_2              ;
  LD (HL),SP_PRINT_OUT/256    ; Then the spine's.
  DEC HL                  ;
  LD (HL),SP_PRINT_OUT-SP_PRINT_OUT/256*256
  INC HL                  ;
HB_2:
  LD DE,$0004             ; The next channel.
  ADD HL,DE               ;
  DJNZ HB_1               ;
  POP HL                  ;
  POP DE                  ;
  POP BC                  ;
  POP AF                  ;
  RET                     ;

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
