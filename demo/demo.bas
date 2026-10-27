1 REM SPINE demo, Fern+Melissa
2 REM (c) 1982 Sinclair Research; 2026 Fern+Melissa
10 BORDER 0: PAPER 0: INK 7: CLS
20 PRINT INK 6;"SPINE";INK 7;"  Spectrum Program"'"INterpreter, Nothing Escapes."''
30 PRINT "This is a Spectrum: the same"'"keys, editor, BASIC and LIST,"'"and nearly the same reports."
40 PRINT '"But its main loop and statement"'"loop live in RAM: 2,439 bytes,"'"{commas(TOTAL)} with the new words, and"'"they never let go."
50 PRINT '"Errors, BREAK, a full memory:"'"each comes home to the spine,"'"never to the ROM's own loop."
60 PRINT '"And four words the ROM never"'"used now mean something:"
70 PRINT INK 5;'"  MOVE  ERASE  CAT  FORMAT"
75 PRINT AT 20,5;: FOR c=144 TO 164: PRINT INK 2+c-6*INT (c/6);CHR$ c;: NEXT c
76 PRINT AT 21,7;"Fern+Melissa, 2026"
80 PRINT #0;"Press any key": PAUSE 0
200 CLS: RESTORE 290
210 FOR c=0 TO 3: READ k: INK k
220 FOR a=0 TO 2*PI STEP PI/12
230 MOVE 40+c*58,96: DRAW 26*COS a,26*SIN a
240 NEXT a: NEXT c: INK 7
250 PRINT AT 15,0; INK 6;"MOVE";INK 7;" x,y: the pen goes there,"'"and no dot. A sunburst, four"'"times over, and no PLOT at all."
260 PRINT #0;"Press any key": PAUSE 0
290 DATA 2,6,4,5
300 CLS: PRINT INK 6;"CAT";INK 7;": the variables, by name."''
310 LET score=100: LET n$="Melissa": DIM g(3,3)
320 CAT
330 PRINT '"In the order they were made: c,"'"k and a from the sunbursts, then"'"score, n$ and g()."
340 PRINT #0;"Press any key": PAUSE 0
350 CLS: PRINT INK 6;"FN";INK 7;" + ";INK 6;"USR";INK 7;": a calling convention."''
360 PRINT "Arguments, numbers or strings;"'"floats and strings back, and"'"FN m$ means string context. The"'"spine has three to show it:"
370 PRINT INK 5;'"FN h(3,4)        = ";FN h(3,4)'"FN r$(""yours"") = ";FN r$("yours")'"FN c()           = ";FN c()'"FN c$()          = ";FN c$()
380 PRINT '"(Their DEF FNs are at 9500.)"
390 PRINT #0;"Press any key": PAUSE 0
392 CLS: PRINT INK 6;"Operators";INK 7;" and ";INK 6;"functions";INK 7;","'"new, since expressions are the"'"spine's own too:"
393 PRINT INK 5;'"17%5 = ";17%5;"     -7%3 = ";-7%3'"12&10 = ";12&10;"    12|10 = ";12|10'"3 AT 2 = ";3 AT 2;"  255 AT -2 = ";255 AT -2
394 PRINT INK 5;'"FN m(17,5) = ";FN m(17,5)'"FN x$(48879) = ";FN x$(48879)
395 PRINT '"% is MOD, & and | are bitwise,"'"AT shifts; FN m and FN x$ need"'"no DEF FN. The ROM's SCANNING"'"never runs."
398 PRINT #0;"Press any key": PAUSE 0
400 CLS: PRINT INK 6;"BREAK";INK 7;" it now: CAPS SHIFT"'"and SPACE. Then type CONTINUE."
410 PAUSE 0
500 CLS: PRINT "L BREAK, still yours: it came"'"home to the spine, as every"'"error does here. That one used"'"to take the whole machine back."
510 PRINT '"Last, ";INK 6;"ERASE";INK 7;" and ";INK 6;"FORMAT";INK 7;"."'"Try these, one at a time:"
520 PRINT INK 5;'"  ERASE 1 TO 8999"'"  LIST"'"  FORMAT"'"  LIST"'"  RUN"
530 PRINT '"ERASE takes the demo away and"'"leaves the lines below it, and"'"FORMAT renumbers them, GO SUB"'"and all. To start over, rewind"'"the tape and LOAD """" again."
540 GO TO 9999
9000 REM Lines to play with
9005 FOR i=1 TO 3
9007 GO SUB 9100
9013 NEXT i
9020 STOP
9100 PRINT "round ";i: RETURN
9500 DEF FN h(x,y)=USR {FN_HYPOT}
9510 DEF FN r$(a$)=USR {FN_REV}
9520 DEF FN c()=USR {FN_YOURS}
9530 DEF FN c$()=USR {FN_YOURS}
