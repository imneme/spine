; The spine minds itself: LOAD CODE and POKE into it get report U. A SPINE module: build_spine.py ... --module src/modules/guard.asm. See src/modules/README.md.

P_X_POKE:
  DEFB $08                ; CLASS_08: POKE a,v, as the ROM's
  DEFB $00                ;
  DEFW SP_POKE            ; but SP_POKE minds the spine.
;; code
;; report U Spine in the way
;; needs VR_CONTRL
;; whole SAVE_ETC

; THE SPINE MINDS ITSELF (Melissa: "Does the code protect itself against, say, a bad CLEAR or a bad LOAD CODE?").
; CLEAR: SPINE_COLD and SPINE_WARM set P_RAMT just below the spine, and the ROM's own CLEAR then refuses to put
; RAMTOP above it: M RAMTOP no good, for nothing here. LOAD CODE and POKE: report U, if they would write into it.
; (PEEK is left alone: it's evaluated deep in the ROM's calculator, and reading never hurt anything.)

; SP_HITS: HL = a start, DE = a length. Carry set if that block overlaps the spine (SPINE_START to FEATURES_END -
; 1). Keeps BC, DE and HL.
SP_HITS:
  PUSH HL                 ;
  PUSH DE                 ;
  PUSH BC                 ;
  LD A,D                  ; An empty block hits nothing.
  OR E                    ;
  JR Z,SP_H_NO            ;
  LD BC,FEATURES_END      ; Starting at or past the spine's end: clear.
  PUSH HL                 ;
  AND A                   ;
  SBC HL,BC               ;
  POP HL                  ;
  JR NC,SP_H_NO           ;
  ADD HL,DE               ; One past its end; running round past FFFF hits.
  JR C,SP_H_YES           ;
  LD BC,SPINE_START+1     ; Ending at or before the spine's start: clear.
  AND A                   ;
  SBC HL,BC               ;
  JR C,SP_H_NO            ;
SP_H_YES:
  SCF                     ;
  JR SP_H_END             ;
SP_H_NO:
  AND A                   ;
SP_H_END:
  POP BC                  ;
  POP DE                  ;
  POP HL                  ;
  RET                     ;

; THE 'POKE' COMMAND, minding the spine.
SP_POKE:
  CALL TWO_PARAM          ; A = the value, BC = the address, as the ROM's.
  PUSH AF                 ;
  LD H,B                  ; One byte at BC.
  LD L,C                  ;
  LD DE,$0001             ;
  CALL SP_HITS            ;
  JR C,SP_U               ;
  POP AF                  ;
  LD (BC),A               ; The POKE.
  RET                     ;
SP_U:
  RST $08                 ; Report U.
  DEFB $1C+1              ;

; SP_LDCHK: called from VR_CONT_2 (the patch below) with HL = where a CODE block will go and DE = its length.
; LOAD into the spine: report U. VERIFY only reads: fine. Keeps everything else.
SP_LDCHK:
  LD A,(T_ADDR)           ; VERIFY (T-ADDR-lo +02).
  CP $02                  ;
  RET Z                   ;
  CALL SP_HITS            ;
  RET NC                  ;
  JR SP_U                 ;

;; patch VR_CONT_2
  CALL SP_LDCHK           ; (the spine's: not over the spine)
;; end patch
