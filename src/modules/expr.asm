; Expressions, owned: SCANNING and every way into it. A SPINE module: build_spine.py ... --module
; src/modules/expr.asm. See src/modules/README.md.
;
; The spine owns the statement loop; with this it owns expression evaluation too, so no expression is ever
; evaluated by the ROM's SCANNING. tools/closure.py found what that takes: SCANNING and its S_ routines; the ROM
; routines from which SCANNING can be reached by a way the spine could take (PRINT's items, colour items, variables
; and subscripts, slicing, FN, LET's value, INPUT's assignment, ...); and VAL's back door. The calculator reaches
; val through its own table of addresses, so the dispatcher comes too (CALCULATE, fp_calc_2 and CALCADDR), and
; S_STK_LST, where SCANNING applies an operator, calls our CALCULATE instead of RST 28. Every other RST 28 still
; goes to the ROM's calculator, whose operations never reach SCANNING.
;; needs SCANNING S_QUOTE_S S_2_COORD SYNTAX_Z S_SCRN_S S_ATTR_S S_U_PLUS S_QUOTE S_BRACKET S_FN S_RND S_PI
;; needs S_INKEY S_SCREEN S_ATTR S_POINT S_ALPHNUM S_DECIMAL S_LETTER
;; needs S_FN_SBRN STK_VAR CO_TEMP_1 LOOK_VARS SLICING PR_ITEM_1 STK_F_ARG val PR_POSN_1 INT_EXP1 CLASS_09
;; needs IN_ASSIGN STR_ALTER VAL_FET_1 PRINT_2 FETCH_NUM CLASS_04 GET_HLxDE PRINT_CR UNSTACK_Z
;; needs CALCULATE fp_calc_2
;; data SCANFUNC offsets
;; data CALCADDR
;; replace RST $28 ; Now use the calculator. @ S_STK_LST
  CALL CALCULATE          ; Now use the calculator (the spine's, whose table
                          ; sends 'val' and 'val$' to the spine's val).
;; end patch
